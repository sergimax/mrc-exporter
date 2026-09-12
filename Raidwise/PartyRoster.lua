-- Party / raid member snapshots for roster views (GearScore, ilvl, guild, spec via inspect).

local Addon = Raidwise

local INSPECT_SLOTS = {
	"HeadSlot",
	"NeckSlot",
	"ShoulderSlot",
	"BackSlot",
	"ChestSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"Finger0Slot",
	"Finger1Slot",
	"Trinket0Slot",
	"Trinket1Slot",
	"MainHandSlot",
	"SecondaryHandSlot",
	"RangedSlot",
}

local inspectQueue = {}
local inspectPending = nil
local specCache = {}
local ilvlCache = {}
local scanTooltip

local function EnsureScanTooltip()
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", "RaidwisePartyScanTooltip", nil, "GameTooltipTemplate")
		scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	return scanTooltip
end

local function ItemLevelFromTooltipText(text)
	if not text or text == "" then
		return nil
	end
	if ITEM_LEVEL then
		local pattern = ITEM_LEVEL:gsub("%%d", "(%%d+)")
		local level = text:match(pattern)
		if level then
			return tonumber(level)
		end
	end
	return nil
end

local function ItemLevelFromTooltip(tooltip, tooltipName)
	for lineIndex = 2, tooltip:NumLines() do
		local left = _G[tooltipName .. "TextLeft" .. lineIndex]
		if left then
			local level = ItemLevelFromTooltipText(left:GetText())
			if level and level > 0 then
				return level
			end
		end
	end
	return nil
end

-- Party is player + up to 4 others (5 total). Raid members belong on Raid roster.
local function PartyUnitIds()
	local units = { "player" }
	local partyCount = math.min(GetNumPartyMembers() or 0, 4)
	for index = 1, partyCount do
		units[#units + 1] = "party" .. index
	end
	return units
end

local function InspectUnitIds()
	local raidCount = (GetNumRaidMembers and GetNumRaidMembers()) or 0
	if raidCount > 0 then
		local units = {}
		for index = 1, raidCount do
			units[#units + 1] = "raid" .. index
		end
		return units
	end
	return PartyUnitIds()
end

local function SafeCanInspect(unit)
	if type(CanInspect) ~= "function" or not CanInspect(unit) then
		return false
	end
	if type(CheckInteractDistance) == "function" and not CheckInteractDistance(unit, 4) then
		return false
	end
	return true
end

local function ItemLevelFromLink(itemLink)
	if not itemLink then
		return nil
	end

	local ok, itemLevel = pcall(function()
		local _, _, _, level = GetItemInfo(itemLink)
		return tonumber(level)
	end)
	if ok and itemLevel and itemLevel > 0 then
		return itemLevel
	end

	local itemId = tonumber(itemLink:match("item:(%d+)"))
	if itemId then
		ok, itemLevel = pcall(function()
			local _, _, _, level = GetItemInfo(itemId)
			return tonumber(level)
		end)
		if ok and itemLevel and itemLevel > 0 then
			return itemLevel
		end
	end

	local tooltipOk, itemLevel = pcall(function()
		local tooltip = EnsureScanTooltip()
		tooltip:ClearLines()
		tooltip:SetHyperlink(itemLink)
		return ItemLevelFromTooltip(tooltip, tooltip:GetName())
	end)
	if tooltipOk then
		return itemLevel
	end
	return nil
end

local function ItemLevelFromUnitSlot(unit, slotId)
	local itemLink = GetInventoryItemLink(unit, slotId)
	if itemLink then
		local itemLevel = ItemLevelFromLink(itemLink)
		if itemLevel then
			return itemLevel
		end
	end

	local ok, itemLevel = pcall(function()
		local tooltip = EnsureScanTooltip()
		tooltip:ClearLines()
		tooltip:SetInventoryItem(unit, slotId)
		return ItemLevelFromTooltip(tooltip, tooltip:GetName())
	end)
	if ok then
		return itemLevel
	end
	return nil
end

local function CanScanUnitItemLevels(unit)
	if not unit or not UnitExists(unit) then
		return false
	end
	if UnitIsUnit(unit, "player") then
		return true
	end
	return inspectPending == unit
end

-- REFACTOR candidate: inspect-gated scan across INSPECT_SLOTS when inspect allowed.
local function AverageItemLevelForUnit(unit)
	local guid = UnitGUID(unit)
	if CanScanUnitItemLevels(unit) then
		local total = 0
		local count = 0

		for index = 1, #INSPECT_SLOTS do
			local slotId = GetInventorySlotInfo(INSPECT_SLOTS[index])
			if slotId then
				local itemLevel = ItemLevelFromUnitSlot(unit, slotId)
				if itemLevel then
					total = total + itemLevel
					count = count + 1
				end
			end
		end

		if count > 0 then
			local average = math.floor(total / count + 0.5)
			if guid then
				ilvlCache[guid] = average
			end
			return average
		end
	end

	if guid and ilvlCache[guid] then
		return ilvlCache[guid]
	end
	return nil
end

local function GearScoreForUnit(unit, refresh)
	if not UnitExists(unit) then
		return nil
	end

	if UnitIsUnit(unit, "player") and Addon.CollectCurrentGearScore then
		if refresh then
			return Addon:CollectCurrentGearScore()
		end
		local score = Addon:CollectCurrentGearScore()
		if score then
			return score
		end
	end

	local name, realm = UnitName(unit)
	if not name then
		return nil
	end

	if refresh and type(GearScore_GetScore) == "function" then
		pcall(GearScore_GetScore, name, unit)
	end

	realm = realm or GetRealmName()
	local players = GS_Data and realm and GS_Data[realm] and GS_Data[realm].Players
	local record = players and players[name]
	if record and record.GearScore ~= nil then
		return tonumber(record.GearScore)
	end

	return nil
end

-- REFACTOR candidate: talent tab iteration with dual-spec API quirks.
local function PrimarySpecFromInspectUnit(unit)
	if not unit or not UnitExists(unit) then
		return "", ""
	end

	local isInspect = not UnitIsUnit("player", unit)
	local talentGroup = 1
	if type(GetActiveTalentGroup) == "function" then
		talentGroup = GetActiveTalentGroup(isInspect) or 1
	end

	local bestName = ""
	local bestIcon = ""
	local bestTab = 0
	local bestPoints = -1
	local tabCount = 3
	if type(GetNumTalentTabs) == "function" then
		tabCount = GetNumTalentTabs(isInspect) or 3
	end

	for tab = 1, tabCount do
		local name, icon, pointsSpent = GetTalentTabInfo(tab, isInspect, nil, talentGroup)
		pointsSpent = tonumber(pointsSpent) or 0
		if pointsSpent > bestPoints then
			bestPoints = pointsSpent
			bestName = name or ""
			bestIcon = icon or ""
			bestTab = tab
		end
	end

	return bestName, bestIcon, bestTab
end

local function CachedSpecForGuid(guid)
	local cached = guid and specCache[guid]
	if type(cached) == "table" then
		if cached.icon ~= "" or (cached.name and cached.name ~= "") or (cached.tab and cached.tab > 0) then
			return cached.name or "", cached.icon or "", cached.tab or 0
		end
	end
	if type(cached) == "string" and cached ~= "" then
		return cached, "", 0
	end
	return nil
end

local function StoreSpecCache(guid, specName, specIcon, specTab)
	if not guid then
		return
	end
	specName = specName or ""
	specIcon = specIcon or ""
	specTab = tonumber(specTab) or 0
	if specName == "" and specIcon == "" and specTab == 0 then
		return
	end
	specCache[guid] = {
		name = specName,
		icon = specIcon,
		tab = specTab,
	}
end

local function SpecForUnit(unit)
	if UnitIsUnit(unit, "player") then
		if Addon.CollectPrimarySpec then
			local specName, specIcon, specTab = Addon:CollectPrimarySpec()
			if specName and specName ~= "" then
				return specName, specIcon or "", specTab or 0
			end
		end
		return "", "", 0
	end

	local guid = UnitGUID(unit)
	local cachedName, cachedIcon, cachedTab = CachedSpecForGuid(guid)
	if cachedName ~= nil then
		return cachedName, cachedIcon, cachedTab or 0
	end

	if inspectPending == unit then
		local specName, specIcon, specTab = PrimarySpecFromInspectUnit(unit)
		if specName ~= "" or specIcon ~= "" or (specTab and specTab > 0) then
			StoreSpecCache(guid, specName, specIcon, specTab)
			return specName, specIcon, specTab
		end
	end

	return "", "", 0
end

local function GuildInfoForUnit(unit)
	if not UnitExists(unit) then
		return nil, nil
	end

	local guildName, guildRankName
	if UnitIsUnit(unit, "player") then
		if (not IsInGuild or IsInGuild()) and type(GetGuildInfo) == "function" then
			guildName, guildRankName = GetGuildInfo("player")
			if not guildName or guildName == "" then
				guildName, guildRankName = GetGuildInfo()
			end
		end
	else
		local ok
		ok, guildName, guildRankName = pcall(GetGuildInfo, unit)
		if not ok then
			guildName, guildRankName = nil, nil
		end
	end

	if guildName == "" then
		guildName = nil
	end
	if guildRankName == "" then
		guildRankName = nil
	end
	return guildName, guildRankName
end

local function MinimalPartyMember(unit)
	local name, realm = UnitName(unit)
	local localizedClass, classToken = UnitClass(unit)
	local member = {
		unit = unit,
		guid = UnitGUID(unit) or "",
		name = name or "?",
		realm = realm or "",
		class = classToken or "",
		classLabel = localizedClass or "",
		spec = "",
		specIcon = "",
		specTab = 0,
		role = "unknown",
		raidBuffs = {},
		gearScore = nil,
		averageIlvl = nil,
		guildName = nil,
		guildRank = nil,
	}
	if Addon.MergeRatingIntoMember then
		Addon:MergeRatingIntoMember(member)
	end
	return member
end

local function CollectMember(unit, refreshGearScore)
	local self = Addon
	local name, realm = UnitName(unit)
	local localizedClass, classToken = UnitClass(unit)
	local guildName, guildRankName = GuildInfoForUnit(unit)
	local specName, specIcon, specTab = SpecForUnit(unit)
	local _, raceToken = UnitRace(unit)
	local faction = UnitFactionGroup and UnitFactionGroup(unit) or ""
	local gender = UnitSex and UnitSex(unit) or nil
	local raidBuffs = {}
	if self.RaidBuffsForMember then
		raidBuffs = self:RaidBuffsForMember(classToken, specTab, raceToken, faction)
	end

	local member = {
		unit = unit,
		guid = UnitGUID(unit) or "",
		name = name or "?",
		realm = realm or "",
		class = classToken or "",
		classLabel = localizedClass or "",
		spec = specName,
		specIcon = specIcon or "",
		specTab = specTab or 0,
		race = raceToken or "",
		faction = faction,
		gender = gender,
		raidBuffs = raidBuffs,
		gearScore = GearScoreForUnit(unit, refreshGearScore),
		averageIlvl = AverageItemLevelForUnit(unit),
		guildName = guildName,
		guildRank = guildRankName,
	}
	return member
end

function Addon:CollectPartyMember(unit, refreshGearScore)
	local member = CollectMember(unit, refreshGearScore)
	if self.MergeRatingIntoMember then self:MergeRatingIntoMember(member) end
	return member
end

function Addon:BuildPartyRoster(refreshGearScore)
	local roster = {}
	for _, unit in ipairs(PartyUnitIds()) do
		if UnitExists(unit) then
			local ok, member = pcall(self.CollectPartyMember, self, unit, refreshGearScore)
			if ok and type(member) == "table" then
				roster[#roster + 1] = member
			else
				roster[#roster + 1] = MinimalPartyMember(unit)
			end
		end
	end

	if #roster == 0 and UnitExists("player") then
		local ok, member = pcall(self.CollectPartyMember, self, "player", refreshGearScore)
		if ok and type(member) == "table" then
			roster[1] = member
		else
			roster[1] = MinimalPartyMember("player")
		end
	end

	return roster
end

function Addon:AverageRosterStats(members)
	local gsTotal, gsCount, ilvlTotal, ilvlCount = 0, 0, 0, 0
	if type(members) ~= "table" then
		return nil, nil
	end

	for index = 1, #members do
		local member = members[index]
		if member then
			if member.gearScore then
				gsTotal = gsTotal + member.gearScore
				gsCount = gsCount + 1
			end
			if member.averageIlvl then
				ilvlTotal = ilvlTotal + member.averageIlvl
				ilvlCount = ilvlCount + 1
			end
		end
	end

	local averageGs = nil
	if gsCount > 0 then
		averageGs = math.floor(gsTotal / gsCount + 0.5)
	end
	local averageIlvl = nil
	if ilvlCount > 0 then
		averageIlvl = math.floor(ilvlTotal / ilvlCount + 0.5)
	end
	return averageGs, averageIlvl
end

local function EmptyRaidGroups()
	local groups = {}
	for groupIndex = 1, 8 do
		groups[groupIndex] = {}
	end
	return groups
end

local function AppendRaidMember(groups, groupIndex, member)
	groupIndex = tonumber(groupIndex) or 1
	if groupIndex < 1 or groupIndex > 8 then
		return
	end
	local slots = groups[groupIndex]
	if #slots >= 5 then
		return
	end
	slots[#slots + 1] = member
end

function Addon:CollectRaidMember(unit, refreshGearScore, raidIndex)
	local member = CollectMember(unit, refreshGearScore)
	local isMainTank = false
	if raidIndex and type(GetRaidRosterInfo) == "function" then
		local _, _, _, _, _, _, _, _, _, raidRole = GetRaidRosterInfo(raidIndex)
		isMainTank = raidRole == "MAINTANK"
	end
	member.role = self.RoleForRaidMember and self:RoleForRaidMember(member.class, member.specTab, isMainTank) or "unknown"
	if self.MergeRatingIntoMember then self:MergeRatingIntoMember(member) end
	return member
end

function Addon:BuildRaidGroups(refreshGearScore)
	local groups = EmptyRaidGroups()
	local raidCount = (GetNumRaidMembers and GetNumRaidMembers()) or 0

	if raidCount > 0 then
		for index = 1, raidCount do
			local unit = "raid" .. index
			if UnitExists(unit) then
				local _, _, subgroup = GetRaidRosterInfo(index)
				local ok, member = pcall(self.CollectRaidMember, self, unit, refreshGearScore, index)
				if not ok or type(member) ~= "table" then
					member = MinimalPartyMember(unit)
				end
				AppendRaidMember(groups, subgroup, member)
			end
		end
		return groups
	end

	for _, unit in ipairs(PartyUnitIds()) do
		if UnitExists(unit) then
			local ok, member = pcall(self.CollectRaidMember, self, unit, refreshGearScore)
			if not ok or type(member) ~= "table" then
				member = MinimalPartyMember(unit)
			end
			AppendRaidMember(groups, 1, member)
		end
	end

	return groups
end

function Addon:ClearPartyInspectForGearCheck()
	self:CompleteInspectRequest("roster")
	inspectPending = nil
	for index = #inspectQueue, 1, -1 do
		inspectQueue[index] = nil
	end
end

function Addon:GetCachedSpecForUnit(unit)
	if not unit or not UnitExists(unit) then
		return "", "", 0
	end
	if UnitIsUnit(unit, "player") then
		if self.CollectPrimarySpec then
			local specName, specIcon, specTab = self:CollectPrimarySpec()
			return specName or "", specIcon or "", specTab or 0
		end
		return "", "", 0
	end
	local cachedName, cachedIcon, cachedTab = CachedSpecForGuid(UnitGUID(unit))
	if cachedName ~= nil then
		return cachedName, cachedIcon, cachedTab or 0
	end
	return "", "", 0
end

function Addon:ClearCachedSpecForUnit(unit)
	if not unit or UnitIsUnit(unit, "player") then
		return
	end
	local guid = UnitGUID(unit)
	if guid then
		specCache[guid] = nil
	end
end

function Addon:StoreSpecCacheForUnit(unit, specName, specIcon, specTab)
	if not unit or UnitIsUnit(unit, "player") then
		return
	end
	StoreSpecCache(UnitGUID(unit), specName, specIcon, specTab)
end

function Addon:QueuePartyInspects()
	if self.IsGearCheckScanBusy and self:IsGearCheckScanBusy() then
		return
	end
	for index = #inspectQueue, 1, -1 do
		inspectQueue[index] = nil
	end

	for _, unit in ipairs(InspectUnitIds()) do
		if not UnitIsUnit(unit, "player") and UnitExists(unit) and UnitIsVisible(unit) and SafeCanInspect(unit) then
			inspectQueue[#inspectQueue + 1] = { unit = unit, guid = UnitGUID(unit) }
		end
	end

	self:ProcessNextPartyInspect()
end

function Addon:ProcessNextPartyInspect()
	if self.IsGearCheckScanBusy and self:IsGearCheckScanBusy() then
		return
	end
	if inspectPending or #inspectQueue == 0 then
		return
	end

	local entry = table.remove(inspectQueue, 1)
	local unit = entry.unit
	if UnitExists(unit) and UnitGUID(unit) == entry.guid and SafeCanInspect(unit) then
		inspectPending = unit
		if not self:StartInspectRequest("roster", unit, {
			onReady = function() self:OnInspectTalentReady() end,
			onStop = function()
				inspectPending = nil
				self:ProcessNextPartyInspect()
			end,
		}) then
			inspectPending = nil
			self:ProcessNextPartyInspect()
		end
		return
	end

	self:ProcessNextPartyInspect()
end

function Addon:OnInspectTalentReady()
	local unit = inspectPending
	if not unit then return end
	if unit and UnitExists(unit) then
		local specName, specIcon, specTab = PrimarySpecFromInspectUnit(unit)
		if specName ~= "" or specIcon ~= "" or (specTab and specTab > 0) then
			StoreSpecCache(UnitGUID(unit), specName, specIcon, specTab)
		end
		AverageItemLevelForUnit(unit)
	end

	self:CompleteInspectRequest("roster")
	inspectPending = nil

	self:ScheduleRosterRefresh(false)

	self:ProcessNextPartyInspect()
end

function Addon:RefreshPartyData(refreshGearScore)
	if refreshGearScore == nil then
		refreshGearScore = true
	end
	self:ScheduleRosterRefresh(refreshGearScore)
	self:QueuePartyInspects()
end
