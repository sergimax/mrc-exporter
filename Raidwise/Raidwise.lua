local ADDON_NAME = ...

Raidwise = Raidwise or {}
local Addon = Raidwise

Addon.version = "1.22.0"
-- Filled from ## X-LastUpdated in Raidwise.toc on load.
Addon.lastUpdated = ""

-- Fallback if Locale.lua does not load. Locale.lua replaces Addon.T.
local FallbackChat = {
	CHAT_LOADED = "loaded (v%s). Type /raidwise to open.",
	CHAT_UNKNOWN = "Unknown command. Use /raidwise, /raidwise close, or /raidwise gearcheck [summary|items|enchants|gems|ok|test].",
}

local function FormatText(text, ...)
	local count = select("#", ...)
	if count <= 0 then
		return text
	end
	local ok, formatted = pcall(string.format, text, ...)
	if ok then
		return formatted
	end
	return text
end

function Addon:T(key, ...)
	return FormatText(FallbackChat[key] or tostring(key or ""), ...)
end

local defaults = {
	enabled = true,
	theme = "dark",
	includeGearNames = true,
	startupTab = "cooldowns",
	reportChannel = "auto",
	reportForm = "short",
	characters = {},
	history = {},
	tooltip = {
		hidePersonal = false,
		hidePersonalTags = false,
		hideCommunity = false,
		hideCommunityTags = false,
	},
	gearCheckSaved = {
		nextId = 0,
		reports = {},
	},
}

-- Recursively copy a value (tables become independent copies).
local function DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		dst[k] = DeepCopy(v)
	end
	return dst
end

-- Create or migrate SavedVariables, then bind Addon.db.
local function EnsureDB()
	if type(RaidwiseDB) ~= "table" then
		if type(MrcExporterDB) == "table" then
			RaidwiseDB = DeepCopy(MrcExporterDB)
		else
			RaidwiseDB = DeepCopy(defaults)
		end
	end
	for k, v in pairs(defaults) do
		if RaidwiseDB[k] == nil then
			RaidwiseDB[k] = DeepCopy(v)
		end
	end
	Addon.db = RaidwiseDB
	if Addon.ApplyTheme then
		Addon:ApplyTheme()
	end
	if Addon.PruneExpiredGearCheckReports then
		Addon:PruneExpiredGearCheckReports()
	end
end

-- Print a prefixed message to the default chat frame.
function Addon:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[Rw]|r " .. tostring(msg))
end

-- Report chat channel (Settings). Auto = RAID in a raid, PARTY in a party.
Addon.REPORT_CHANNEL_CHOICES = {
	{ id = "auto", labelKey = "SETTINGS_REPORT_CHANNEL_AUTO" },
	{ id = "self", labelKey = "SETTINGS_REPORT_CHANNEL_SELF" },
	{ id = "party", labelKey = "SETTINGS_REPORT_CHANNEL_PARTY" },
	{ id = "raid", labelKey = "SETTINGS_REPORT_CHANNEL_RAID" },
	{ id = "raidwarning", labelKey = "SETTINGS_REPORT_CHANNEL_RAID_WARNING" },
	{ id = "guild", labelKey = "SETTINGS_REPORT_CHANNEL_GUILD" },
	{ id = "officer", labelKey = "SETTINGS_REPORT_CHANNEL_OFFICER" },
	{ id = "say", labelKey = "SETTINGS_REPORT_CHANNEL_SAY" },
}

local REPORT_CHANNEL_IDS = {
	auto = true,
	self = true,
	party = true,
	raid = true,
	raidwarning = true,
	guild = true,
	officer = true,
	say = true,
}

local lastUnavailableWarnAt = 0

local function IsInRaidGroup()
	return ((GetNumRaidMembers and GetNumRaidMembers()) or 0) > 0
end

local function IsInPartyGroup()
	return ((GetNumPartyMembers and GetNumPartyMembers()) or 0) > 0
end

local function CanUseOfficerChat()
	if not (IsInGuild and IsInGuild()) then
		return false
	end
	-- WotLK: officer chat requires officer rights; CanEditOfficerNote is the usual proxy.
	if type(CanEditOfficerNote) == "function" then
		return CanEditOfficerNote() and true or false
	end
	return true
end

function Addon:GetReportChannel()
	local channelId = self.db and self.db.reportChannel
	if type(channelId) == "string" and REPORT_CHANNEL_IDS[channelId] then
		return channelId
	end
	return "auto"
end

function Addon:SetReportChannel(channelId)
	if not self.db or not REPORT_CHANNEL_IDS[channelId] then
		return
	end
	self.db.reportChannel = channelId
	if self.RefreshHeaderReportChannels then
		self:RefreshHeaderReportChannels()
	end
end

-- SendChatMessage chatType, or nil for the local default chat frame.
-- Second return is "self" or "unavailable" when chatType is nil.
function Addon:ResolveReportChatType()
	local channelId = self:GetReportChannel()
	if channelId == "self" then
		return nil, "self"
	end
	if channelId == "say" then
		return "SAY"
	end
	if channelId == "party" then
		if IsInRaidGroup() or IsInPartyGroup() then
			return "PARTY"
		end
		return nil, "unavailable"
	end
	if channelId == "raid" then
		if IsInRaidGroup() then
			return "RAID"
		end
		return nil, "unavailable"
	end
	if channelId == "raidwarning" then
		local isLead = IsRaidLeader and IsRaidLeader()
		local isAssist = IsRaidOfficer and IsRaidOfficer()
		if IsInRaidGroup() and (isLead or isAssist) then
			return "RAID_WARNING"
		end
		return nil, "unavailable"
	end
	if channelId == "guild" then
		if IsInGuild and IsInGuild() then
			return "GUILD"
		end
		return nil, "unavailable"
	end
	if channelId == "officer" then
		if CanUseOfficerChat() then
			return "OFFICER"
		end
		return nil, "unavailable"
	end
	-- auto
	if IsInRaidGroup() then
		return "RAID"
	end
	if IsInPartyGroup() then
		return "PARTY"
	end
	return nil, "unavailable"
end

function Addon:SendReportChat(message)
	if type(message) ~= "string" or message == "" then
		return
	end
	local chatType, reason = self:ResolveReportChatType()
	if chatType then
		SendChatMessage(self:PrepareReportMessage(message), chatType)
		return
	end
	if reason == "unavailable" then
		local now = (GetTime and GetTime()) or 0
		if (now - lastUnavailableWarnAt) >= 2 then
			lastUnavailableWarnAt = now
			self:Print(self:T("REPORT_CHAT_UNAVAILABLE"))
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(message)
end

-- Gear Check chat report form (Settings): short (default) or full.
Addon.REPORT_FORM_CHOICES = {
	{ id = "short", labelKey = "SETTINGS_REPORT_FORM_SHORT" },
	{ id = "full", labelKey = "SETTINGS_REPORT_FORM_FULL" },
}

local REPORT_FORM_IDS = {
	short = true,
	full = true,
}

function Addon:GetReportForm()
	local formId = self.db and self.db.reportForm
	if type(formId) == "string" and REPORT_FORM_IDS[formId] then
		return formId
	end
	return "short"
end

function Addon:SetReportForm(formId)
	if not self.db or not REPORT_FORM_IDS[formId] then
		return
	end
	self.db.reportForm = formId
	if self.RefreshHeaderReportForm then
		self:RefreshHeaderReportForm()
	end
end

-- Run once when this addon finishes loading.
function Addon:OnInitialize()
	EnsureDB()
	if self.InitializeHistoryStore then self:InitializeHistoryStore() end
	if self.CreateMinimapButton then
		self:CreateMinimapButton()
	end
	self.lastUpdated = GetAddOnMetadata(ADDON_NAME, "X-LastUpdated") or ""
	if not self.db.locale or (self.db.locale ~= "enUS" and self.db.locale ~= "ruRU") then
		self.db.locale = self.DetectClientLocale and self:DetectClientLocale() or "enUS"
	end
	if self.SetLocale then
		self:SetLocale(self.db.locale, true)
	end
	if self.CreateMainFrame then
		local ok, err = pcall(self.CreateMainFrame, self)
		if not ok then
			self:Print("UI failed to load: " .. tostring(err))
		end
	end
	if not self.RatingTagGroups then
		self:Print("Player rating module failed to load. Update PlayerHistory.lua and /reload.")
	end
	self:Print(self:T("CHAT_LOADED", self.version))
end

-- Run when the player is fully in the world (gear, talents, etc.).
function Addon:OnPlayerLogin()
	self:SaveCurrentCharacterLockouts()
	RequestRaidInfo()
end

-- Fires on login and /reload; PLAYER_LOGIN does not fire after /reload.
function Addon:OnPlayerEnteringWorld()
	self:SaveCurrentCharacterLockouts()
	RequestRaidInfo()
	if self.RecordCurrentGroupHistory then
		self:RecordCurrentGroupHistory(false)
	end
end

-- Refresh saved instance cache when the server answers RequestRaidInfo.
function Addon:OnUpdateInstanceInfo()
	self:SaveCurrentCharacterLockouts()

	if self.pendingLockoutExport then
		self.pendingLockoutExport = nil
		if self.FlushExportToWindow then
			self:FlushExportToWindow()
		end
	end

	if self.RefreshCooldownTable then
		local frame = self.mainFrame
		if self.pendingLockoutTable or (frame and frame:IsShown() and frame.selectedTab == "cooldowns") then
			self.pendingLockoutTable = nil
			self:RefreshCooldownTable()
		end
	end
end


function Addon:OnGuildInfoUpdated()
	local frame = self.mainFrame
	if not frame then
		return
	end
	if frame.selectedTab == "raid" and self.RefreshRaidRosterView then
		self:ScheduleRosterRefresh(false)
	elseif frame.selectedTab == "composition" and self.RefreshCompositionView then
		self:ScheduleRosterRefresh(false)
	end
end

function Addon:OnGroupRosterUpdated()
	local frame = self.mainFrame
	if frame and frame:IsShown() and (frame.selectedTab == "raid" or frame.selectedTab == "composition") then
		self:RefreshPartyData(false)
		return
	end
	if self.RecordCurrentGroupHistory then
		self:ScheduleRosterRefresh(false)
	end
end

-- Slash commands: /raidwise and /rw
SLASH_RAIDWISE1 = "/raidwise"
SLASH_RAIDWISE2 = "/rw"

-- /raidwise [close|gearcheck …] — open, close, scan, self-test, or chat reports.
SlashCmdList["RAIDWISE"] = function(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$") or ""
	msg = msg:lower():gsub("%s+", " ")

	if msg == "" then
		Addon:ShowMainFrame()
		return
	end

	if msg == "close" then
		Addon:HideMainFrame()
		return
	end

	if msg == "gearcheck test" or msg == "gear test" then
		if not Addon.GearCheckRulesSelfTest then
			Addon:Print(Addon:T("GEAR_CHECK_STATUS_FAIL"))
			return
		end
		local ok, results, passed, total = pcall(function()
			return Addon:GearCheckRulesSelfTest()
		end)
		if not ok then
			Addon:Print(Addon:T("GEAR_CHECK_STATUS_FAIL"))
			Addon:Print(tostring(results))
			return
		end
		Addon:Print(Addon:T("CHAT_GEARCHECK_TEST_SUMMARY", passed, total))
		for index = 1, #results do
			local row = results[index]
			local mark = row.ok and "PASS" or "FAIL"
			Addon:Print(string.format("  [%s] %s", mark, row.name))
		end
		return
	end

	local reportMode = msg:match("^gearcheck%s+(%S+)$") or msg:match("^gear%s+(%S+)$")
	if reportMode == "summary" or reportMode == "report"
		or reportMode == "items" or reportMode == "enchants" or reportMode == "gems"
		or reportMode == "ok"
	then
		if reportMode == "report" then
			reportMode = "summary"
		end
		if Addon.RunGearCheckChatReport then
			Addon:RunGearCheckChatReport(reportMode, true)
		else
			Addon:Print(Addon:T("GEAR_CHECK_STATUS_FAIL"))
		end
		return
	end

	if msg == "gearcheck raid dump" or msg == "gear raid dump" then
		if Addon.ShowGearCheckRaidDump then
			Addon:ShowGearCheckRaidDump()
		else
			Addon:Print(Addon:T("GEAR_CHECK_STATUS_FAIL"))
		end
		return
	end

	if msg == "gearcheck" or msg == "gear" then
		if Addon.OpenGearCheckTarget then
			Addon:OpenGearCheckTarget(true)
		else
			Addon:Print(Addon:T("GEAR_CHECK_STATUS_FAIL"))
		end
		return
	end

	Addon:Print(Addon:T("CHAT_UNKNOWN"))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")

local raidConsumableElapsed = 0

-- Dispatch ADDON_LOADED and PLAYER_LOGIN to addon lifecycle hooks.
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		Addon:OnInitialize()
	elseif event == "PLAYER_LOGIN" then
		Addon:OnPlayerLogin()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Addon:OnPlayerEnteringWorld()
	elseif event == "UPDATE_INSTANCE_INFO" then
		Addon:OnUpdateInstanceInfo()
	elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
		Addon:OnGuildInfoUpdated()
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		Addon:OnGroupRosterUpdated()
	elseif event == "UNIT_AURA" then
		local mainFrame = Addon.mainFrame
		if mainFrame and mainFrame:IsShown() and mainFrame.selectedTab == "raid" then
			Addon.raidConsumableDirty = true
		end
	end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
	if not Addon.raidConsumableDirty then
		raidConsumableElapsed = 0
		return
	end
	raidConsumableElapsed = raidConsumableElapsed + elapsed
	if raidConsumableElapsed < 0.2 then
		return
	end
	raidConsumableElapsed = 0
	Addon.raidConsumableDirty = false
	if Addon.RefreshRaidConsumableIcons then
		Addon:RefreshRaidConsumableIcons()
	end
end)
