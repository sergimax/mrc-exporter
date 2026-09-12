-- Details-style shell: plain panels, left menu, tabbed content pages.

local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

local SHELL_LAYOUT_VERSION = 15

-- Visual groups for the left menu (ids stay stable for a future module split).
local MENU_GROUPS = {
	{ id = "personal", labelKey = "MENU_GROUP_PERSONAL" },
	{ id = "raiding", labelKey = "MENU_GROUP_RAIDING" },
	{ id = "other", labelKey = "MENU_GROUP_OTHER" },
}

-- WotLK Interface\Icons paths (one per left-menu category).
local PAGES = {
	{ id = "cooldowns", key = "Cooldowns", labelKey = "TAB_COOLDOWNS", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", group = "personal" },
	{ id = "export", key = "Export", labelKey = "TAB_EXPORT", icon = "Interface\\Icons\\INV_Misc_Note_01", group = "personal" },
	{ id = "raid", key = "Raid", labelKey = "TAB_RAID", icon = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider", group = "raiding" },
	{ id = "composition", key = "Composition", labelKey = "TAB_COMPOSITION", icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings", group = "raiding" },
	{ id = "geartarget", key = "GearCheckTarget", labelKey = "TAB_GEAR_CHECK_TARGET", icon = "Interface\\Icons\\INV_Misc_Spyglass_03", group = "raiding" },
	{ id = "history", key = "History", labelKey = "TAB_HISTORY", icon = "Interface\\Icons\\INV_Misc_Book_11", group = "raiding" },
	{ id = "settings", key = "Settings", labelKey = "TAB_SETTINGS", icon = "Interface\\Icons\\INV_Misc_Gear_01", group = "other" },
	{ id = "info", key = "Info", labelKey = "TAB_INFO", icon = "Interface\\Icons\\INV_Misc_QuestionMark", group = "other" },
}

Addon.MenuGroups = MENU_GROUPS
Addon.MenuPages = PAGES

local function PageInfoById(tabId)
	for index = 1, #PAGES do
		if PAGES[index].id == tabId then
			return PAGES[index]
		end
	end
	return nil
end

local function MenuGroupById(groupId)
	for index = 1, #MENU_GROUPS do
		if MENU_GROUPS[index].id == groupId then
			return MENU_GROUPS[index]
		end
	end
	return nil
end

-- Info is reference-only; not a valid /raidwise startup page.
local function IsAllowedStartupTab(tabId)
	return type(tabId) == "string" and tabId ~= "info" and PageInfoById(tabId) ~= nil
end

function Addon:GetStartupTab()
	local tabId = self.db and self.db.startupTab
	if tabId == "gearraid" or tabId == "party" then
		tabId = "raid"
		if self.db then
			self.db.startupTab = tabId
		end
	end
	if IsAllowedStartupTab(tabId) then
		return tabId
	end
	if self.db and (self.db.startupTab == "info" or self.db.startupTab == "gearraid" or self.db.startupTab == "party") then
		self.db.startupTab = "cooldowns"
	end
	return "cooldowns"
end

function Addon:SetStartupTab(tabId)
	if not self.db or not IsAllowedStartupTab(tabId) then
		return
	end
	self.db.startupTab = tabId
end

function Addon:IsAllowedStartupTab(tabId)
	return IsAllowedStartupTab(tabId)
end

local HEADER_CHAT_CHOICES = {
	{ id = "self", label = "Slf", chatType = "SYSTEM", key = "SELF" },
	{ id = "say", label = "Say", chatType = "SAY", key = "SAY" },
	{ id = "party", label = "Prt", chatType = "PARTY", key = "PARTY" },
	{ id = "raid", label = "Rd", chatType = "RAID", key = "RAID" },
	{ id = "raidwarning", label = "Rdw", chatType = "RAID_WARNING", key = "RAID_WARNING" },
	{ id = "guild", label = "Gld", chatType = "GUILD", key = "GUILD" },
	{ id = "officer", label = "Gof", chatType = "OFFICER", key = "OFFICER" },
	{ id = "auto", label = "Aut", key = "AUTO" },
}

function Addon:RefreshHeaderReportChannels()
	local frame = self.mainFrame
	if not frame or not frame.reportChannelRadios then return end
	local selected = self:GetReportChannel()
	for _, radio in ipairs(frame.reportChannelRadios) do
		radio:SetChecked(radio.channelId == selected)
		local color = ChatTypeInfo and radio.chatType and ChatTypeInfo[radio.chatType]
		if color then
			radio.label:SetTextColor(color.r, color.g, color.b)
		else
			W.SetFontColor(radio.label, UI.TEXT_BODY)
		end
	end
end

local function CreateHeaderReportChannels(frame, titleBar, close)
	local host = CreateFrame("Frame", nil, titleBar)
	host:SetSize(406, 18)
	host:SetPoint("RIGHT", close, "LEFT", -24, 0)
	frame.reportChannelHost = host
	frame.reportChannelRadios = {}
	for index, choice in ipairs(HEADER_CHAT_CHOICES) do
		local button = CreateFrame("Button", nil, host)
		button:SetSize(42, 18)
		button:SetPoint("LEFT", (index - 1) * 52, 0)
		local label = W.CreateFontString(button, nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", 0, 0)
		label:SetWidth(24)
		label:SetJustifyH("RIGHT")
		label:SetText(choice.label)
		local radio = CreateFrame("CheckButton", nil, button, "UIRadioButtonTemplate")
		radio:SetSize(14, 14)
		radio:SetPoint("LEFT", label, "RIGHT", 2, 0)
		radio.channelId = choice.id
		radio.chatType = choice.chatType
		radio.label = label
		local function SelectChannel()
			Addon:SetReportChannel(radio.channelId)
		end
		local function ShowTooltip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(W.T("SETTINGS_REPORT_CHANNEL"))
			GameTooltip:AddLine(W.T("SETTINGS_REPORT_CHANNEL_" .. choice.key), 1, 1, 1, true)
			GameTooltip:Show()
		end
		button:SetScript("OnClick", SelectChannel)
		radio:SetScript("OnClick", SelectChannel)
		button:SetScript("OnEnter", ShowTooltip)
		radio:SetScript("OnEnter", ShowTooltip)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		radio:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.reportChannelRadios[index] = radio
	end
	host:SetScript("OnShow", function() Addon:RefreshHeaderReportChannels() end)
end

function Addon:RefreshHeaderReportForm()
	local frame = self.mainFrame
	if not frame or not frame.reportFormRadios then return end
	local selected = self:GetReportForm()
	for _, radio in ipairs(frame.reportFormRadios) do
		local checked = radio.formId == selected
		radio:SetChecked(checked)
		W.SetFontColor(radio.label, checked and UI.GOLD or UI.TEXT_IDLE)
	end
end

local function CreateHeaderReportForm(frame, titleBar)
	local host = CreateFrame("Frame", nil, titleBar)
	host:SetSize(132, 18)
	host:SetPoint("RIGHT", frame.reportChannelHost, "LEFT", -16, 0)
	frame.reportFormHost = host
	frame.reportFormRadios = {}
	for index, formId in ipairs({ "short", "full" }) do
		local button = CreateFrame("Button", nil, host)
		button:SetSize(62, 18)
		button:SetPoint("LEFT", (index - 1) * 70, 0)
		local label = W.CreateFontString(button, nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", 0, 0)
		label:SetWidth(44)
		label:SetJustifyH("RIGHT")
		label:SetText(formId == "short" and "Short" or "Full")
		local radio = CreateFrame("CheckButton", nil, button, "UIRadioButtonTemplate")
		radio:SetSize(14, 14)
		radio:SetPoint("LEFT", label, "RIGHT", 2, 0)
		radio.formId = formId
		radio.label = label
		local function SelectForm()
			Addon:SetReportForm(radio.formId)
		end
		local function ShowTooltip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(W.T("SETTINGS_REPORT_FORM"))
			GameTooltip:AddLine(W.T("SETTINGS_REPORT_FORM_" .. string.upper(radio.formId)), 1, 1, 1, true)
			GameTooltip:AddLine(W.T("SETTINGS_REPORT_FORM_HINT"), 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end
		button:SetScript("OnClick", SelectForm)
		radio:SetScript("OnClick", SelectForm)
		button:SetScript("OnEnter", ShowTooltip)
		radio:SetScript("OnEnter", ShowTooltip)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		radio:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.reportFormRadios[index] = radio
	end
	host:SetScript("OnShow", function() Addon:RefreshHeaderReportForm() end)
end

local function UpdateShellHeader(frame, tabId)
	if not frame then
		return
	end
	Addon:RefreshHeaderReportChannels()
	Addon:RefreshHeaderReportForm()
	local pageInfo = PageInfoById(tabId)
	local registration = pageInfo and Addon.Pages and Addon.Pages[pageInfo.key]
	local capabilities = registration and registration.capabilities or {}
	local usesReportChat = capabilities.reportChat == true
	local usesReportForm = capabilities.reportForm == true
	if frame.reportChannelHost then
		if usesReportChat then frame.reportChannelHost:Show() else frame.reportChannelHost:Hide() end
	end
	if frame.reportFormHost then
		if usesReportForm then frame.reportFormHost:Show() else frame.reportFormHost:Hide() end
	end
	if frame.titleText then
		if pageInfo then
			frame.titleText:SetText(W.T(pageInfo.labelKey))
		else
			frame.titleText:SetText("Raidwise")
		end
	end
	if frame.titleText then
		frame.titleText:SetWidth(math.min(230, frame.titleText:GetStringWidth() or 230))
	end
	if not frame.pageLayoutVersionText then
		return
	end
	local version
	local page = frame.pages and frame.pages[tabId]
	if page and page.layoutVersion then
		version = page.layoutVersion
	elseif pageInfo and Addon.Pages and Addon.Pages[pageInfo.key] then
		version = Addon.Pages[pageInfo.key].LAYOUT_VERSION
	end
	if version then
		frame.pageLayoutVersionText:SetText("v" .. tostring(version))
		frame.pageLayoutVersionText:Show()
	else
		frame.pageLayoutVersionText:Hide()
	end
end

local function PageLayoutStale(frame)
	if not frame or not frame.pages then
		return true
	end
	for index = 1, #PAGES do
		local pageInfo = PAGES[index]
		local pageModule = Addon.Pages and Addon.Pages[pageInfo.key]
		local page = frame.pages[pageInfo.id]
		if not pageModule or not page then
			return true
		end
		if page.layoutVersion ~= pageModule.LAYOUT_VERSION then
			return true
		end
	end
	return false
end

local function ShellNeedsRebuild(frame)
	if not frame then
		return true
	end
	if frame.layoutVersion ~= SHELL_LAYOUT_VERSION then
		return true
	end
	return PageLayoutStale(frame)
end

local function TearDownMainFrame(frame)
	if not frame then
		return
	end
	frame:Hide()
	W.DetachFrameChildren(frame)
	frame:SetParent(nil)
end

local function EnsureSpecialFrame(name, flagOwner)
	if flagOwner and flagOwner.rwInSpecialFrames then
		return
	end
	local found = false
	for index = 1, #UISpecialFrames do
		if UISpecialFrames[index] == name then
			found = true
			break
		end
	end
	if not found then
		tinsert(UISpecialFrames, name)
	end
	if flagOwner then
		flagOwner.rwInSpecialFrames = true
	end
end

function Addon:SelectTab(tabId)
	local frame = self.mainFrame
	if not frame then
		return
	end

	frame.selectedTab = tabId
	for id, page in pairs(frame.pages) do
		if id == tabId then
			page:Show()
		else
			page:Hide()
		end
	end
	for _, button in ipairs(frame.menuButtons) do
		W.SetMenuButtonState(button, button.tabId == tabId, false)
	end
	UpdateShellHeader(frame, tabId)

	local pageInfo = PageInfoById(tabId)
	local module = pageInfo and Addon.Pages[pageInfo.key]
	if module and module.Refresh then module.Refresh(frame.pages[tabId], true) end

end

local function CreateTitleBar(frame)
	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", -1, -1)
	titleBar:SetHeight(UI.TITLE_H)
	W.ApplyPlainPanel(titleBar, UI.TITLE_BG)
	W.AttachDragHandle(titleBar, frame)

	local close = CreateFrame("Button", nil, titleBar)
	close:SetSize(UI.CLOSE_SIZE, UI.CLOSE_SIZE)
	close:SetPoint("RIGHT", -3, 0)
	local closeText = W.CreateFontString(close, nil, "OVERLAY", "GameFontNormalSmall")
	closeText:SetPoint("CENTER", 1, 1)
	closeText:SetText("X")
	W.SetFontColor(closeText, UI.GOLD)
	close:SetScript("OnEnter", function()
		W.SetFontColor(closeText, UI.TEXT_ALERT)
	end)
	close:SetScript("OnLeave", function()
		W.SetFontColor(closeText, UI.GOLD)
	end)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local title = W.CreateFontString(titleBar, nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 8, 0)
	title:SetWidth(230)
	title:SetJustifyH("LEFT")
	title:SetText("Raidwise")
	W.SetFontColor(title, UI.GOLD)

	local pageLayoutVersionText = W.CreateFontString(titleBar, nil, "OVERLAY", "GameFontNormalSmall")
	pageLayoutVersionText:SetPoint("LEFT", title, "RIGHT", 8, 0)
	pageLayoutVersionText:SetJustifyH("LEFT")
	pageLayoutVersionText:SetText("")
	W.SetFontColor(pageLayoutVersionText, UI.TEXT_DISABLED)

	CreateHeaderReportChannels(frame, titleBar, close)
	CreateHeaderReportForm(frame, titleBar)

	frame.titleBar = titleBar
	frame.titleText = title
	frame.pageLayoutVersionText = pageLayoutVersionText
	return titleBar
end

local MENU_HEADER_GAP = 8

local function UpdateMenuHeaderLayout(frame)
	if not frame or not frame.menuTitleBar or not frame.menuNameLabel or not frame.menuVersionLabel then
		return
	end
	local titleBar = frame.menuTitleBar
	local nameLabel = frame.menuNameLabel
	local versionLabel = frame.menuVersionLabel
	local nameWidth = nameLabel:GetStringWidth() or 0
	local versionWidth = versionLabel:GetStringWidth() or 0
	local totalWidth = nameWidth + MENU_HEADER_GAP + versionWidth
	nameLabel:ClearAllPoints()
	versionLabel:ClearAllPoints()
	nameLabel:SetPoint("LEFT", titleBar, "CENTER", -totalWidth / 2, 0)
	versionLabel:SetPoint("LEFT", nameLabel, "RIGHT", MENU_HEADER_GAP, 0)
end

local function UpdateMenuHeader(frame)
	if not frame then
		return
	end
	if frame.menuVersionLabel then
		frame.menuVersionLabel:SetText("v" .. tostring(Addon.version))
		W.SetFontColor(frame.menuVersionLabel, UI.TEXT_DISABLED)
	end
	UpdateMenuHeaderLayout(frame)
end

local function CreateMenuGroupHeading(parent, labelKey, yOffset)
	local heading = W.CreateFontString(parent, nil, "OVERLAY", "GameFontNormalSmall")
	heading:SetPoint("TOPLEFT", 10, yOffset)
	heading:SetPoint("TOPRIGHT", -10, yOffset)
	heading:SetHeight(UI.MENU_GROUP_HEADING_H)
	heading:SetJustifyH("LEFT")
	heading:SetJustifyV("MIDDLE")
	heading:SetText(W.T(labelKey))
	W.SetFontColor(heading, UI.GOLD_DIM)
	heading.labelKey = labelKey
	return heading
end

local function CreateMenuSeparator(parent, yOffset)
	local sep = CreateFrame("Frame", nil, parent)
	sep:SetHeight(UI.MENU_SEP_H)
	sep:SetPoint("LEFT", 10, 0)
	sep:SetPoint("RIGHT", -10, 0)
	sep:SetPoint("TOP", 0, yOffset)
	W.ApplyPlainPanel(sep, { UI.GOLD_DIM[1], UI.GOLD_DIM[2], UI.GOLD_DIM[3], 0.45 })
	return sep
end

local function CreateMenuButton(parent, tabId, label, yOffset, iconPath)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(UI.MENU_WIDTH - 12, UI.MENU_BTN_H)
	button:SetPoint("TOP", 0, yOffset)
	W.ApplyPlainPanel(button, UI.BTN_IDLE)
	button.tabId = tabId

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(UI.MENU_ICON, UI.MENU_ICON)
	icon:SetPoint("LEFT", 6, 0)
	if iconPath and iconPath ~= "" then
		icon:SetTexture(iconPath)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	button.icon = icon

	local text = W.CreateFontString(button, nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	text:SetPoint("RIGHT", -6, 0)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	W.SetFontColor(text, UI.TEXT_IDLE)
	button.label = text

	button:SetScript("OnEnter", function(self)
		W.SetMenuButtonState(self, Addon.mainFrame and Addon.mainFrame.selectedTab == tabId, true)
	end)
	button:SetScript("OnLeave", function(self)
		W.SetMenuButtonState(self, Addon.mainFrame and Addon.mainFrame.selectedTab == tabId, false)
	end)
	button:SetScript("OnClick", function()
		Addon:SelectTab(tabId)
	end)

	return button
end

-- REFACTOR candidate: shell rebuild — menu, status bar, all pages, layout-version checks.
function Addon:CreateMainFrame()
	if self.mainFrame and not ShellNeedsRebuild(self.mainFrame) then
		return self.mainFrame
	end

	local previousTab = self.mainFrame and self.mainFrame.selectedTab

	if self.mainFrame then
		TearDownMainFrame(self.mainFrame)
		self.mainFrame = nil
	end

	-- Named frames are reused by CreateFrame; clear leftover children first.
	local frame = CreateFrame("Frame", "RaidwiseFrame", UIParent)
	W.DetachFrameChildren(frame)
	frame:SetSize(UI.CONTENT_WIDTH, UI.CONTENT_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetClampRectInsets(-UI.MENU_WIDTH, 0, 0, 0)
	frame:Hide()
	W.ApplyPlainPanel(frame)
	frame.layoutVersion = SHELL_LAYOUT_VERSION
	EnsureSpecialFrame("RaidwiseFrame", frame)

	CreateTitleBar(frame)

	local menu = CreateFrame("Frame", "RaidwiseMenu", frame)
	W.DetachFrameChildren(menu)
	menu:SetWidth(UI.MENU_WIDTH)
	menu:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	menu:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	W.ApplyPlainPanel(menu)
	menu:EnableMouse(true)

	local menuTitleBar = CreateFrame("Frame", nil, menu)
	menuTitleBar:SetPoint("TOPLEFT", 1, -1)
	menuTitleBar:SetPoint("TOPRIGHT", -1, -1)
	menuTitleBar:SetHeight(UI.TITLE_H)
	W.ApplyPlainPanel(menuTitleBar, UI.TITLE_BG)
	W.AttachDragHandle(menuTitleBar, frame)

	local menuNameLabel = W.CreateFontString(menuTitleBar, nil, "OVERLAY", "GameFontNormal")
	menuNameLabel:SetText("Raidwise")
	W.SetFontColor(menuNameLabel, UI.GOLD)

	local menuVersionLabel = W.CreateFontString(menuTitleBar, nil, "OVERLAY", "GameFontNormalSmall")
	menuVersionLabel:SetText("v" .. tostring(Addon.version))
	W.SetFontColor(menuVersionLabel, UI.TEXT_DISABLED)
	frame.menuTitleBar = menuTitleBar
	frame.menuNameLabel = menuNameLabel
	frame.menuVersionLabel = menuVersionLabel
	UpdateMenuHeaderLayout(frame)

	frame.menuButtons = {}
	frame.menuGroupHeadings = {}
	local menuY = -(UI.TITLE_H + 8)
	local lastGroup = nil
	for index = 1, #PAGES do
		local pageInfo = PAGES[index]
		if pageInfo.group ~= lastGroup then
			if lastGroup then
				menuY = menuY - UI.MENU_GROUP_GAP
				CreateMenuSeparator(menu, menuY)
				menuY = menuY - UI.MENU_SEP_H - UI.MENU_GROUP_GAP
			end
			local groupInfo = MenuGroupById(pageInfo.group)
			if groupInfo then
				local heading = CreateMenuGroupHeading(menu, groupInfo.labelKey, menuY)
				frame.menuGroupHeadings[#frame.menuGroupHeadings + 1] = heading
				menuY = menuY - UI.MENU_GROUP_HEADING_H - UI.MENU_GROUP_HEADING_GAP
			end
			lastGroup = pageInfo.group
		end
		local button = CreateMenuButton(menu, pageInfo.id, W.T(pageInfo.labelKey), menuY, pageInfo.icon)
		frame.menuButtons[#frame.menuButtons + 1] = button
		menuY = menuY - UI.MENU_BTN_H - UI.MENU_BTN_GAP
	end

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", UI.PAD, -(UI.TITLE_H + UI.PAD))
	content:SetPoint("BOTTOMRIGHT", -UI.PAD, UI.PAD)

	frame.pages = {}
	for index = 1, #PAGES do
		local pageInfo = PAGES[index]
		local pageModule = Addon.Pages and Addon.Pages[pageInfo.key]
		if pageModule and pageModule.Create then
			local page = pageModule.Create(content)
			frame.pages[pageInfo.id] = page
			page:Hide()
			if pageInfo.id == "export" then
				frame.exportBox = page.exportBox
				frame.statusLabel = page.statusLabel
				frame.selectBtn = page.selectBtn
			elseif pageInfo.id == "info" then
				frame.repoBox = page.repoBox
				frame.repoHint = page.repoHint
			end
		end
	end

	self.mainFrame = frame
	self:SelectTab(previousTab or self:GetStartupTab())
	return frame
end

-- Pages own their controls; the shell dispatches lifecycle methods.
function Addon:RefreshLocalizedUI()
	local frame = self.mainFrame
	if not frame then
		return
	end

	if frame.menuVersionLabel then
		UpdateMenuHeader(frame)
	end
	if frame.menuGroupHeadings then
		for index = 1, #frame.menuGroupHeadings do
			local heading = frame.menuGroupHeadings[index]
			if heading and heading.labelKey then
				heading:SetText(W.T(heading.labelKey))
			end
		end
	end
	for index = 1, #PAGES do
		local button = frame.menuButtons[index]
		if button and PAGES[index] then
			button.label:SetText(W.T(PAGES[index].labelKey))
			W.SetMenuButtonState(button, button.tabId == frame.selectedTab, false)
		end
	end
	UpdateShellHeader(frame, frame.selectedTab)

	for _, pageInfo in ipairs(PAGES) do
		local page = frame.pages[pageInfo.id]
		local module = Addon.Pages[pageInfo.key]
		if page and module then
			if module.ApplyLocale then module.ApplyLocale(page) end
			if module.Refresh and module.Refresh ~= module.ApplyLocale then module.Refresh(page) end
		end
	end

	if self.raidDetailFrame and self.raidDetailFrame:IsShown() and self.raidDetailFrame.profileMember then
		self:ShowRaidCharacterWindow(self.raidDetailFrame.profileMember)
	end
end

function Addon:ShowMainFrame()
	local frame = self:CreateMainFrame()
	-- Prefer configured startup tab each time the window is opened.
	self:SelectTab(self:GetStartupTab())
	frame:Show()
	frame:Raise()
end

function Addon:HideMainFrame()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end

-- DELETE candidate: no callers; slash handler uses ShowMainFrame / HideMainFrame directly.
function Addon:ToggleMainFrame()
	if self.mainFrame and self.mainFrame:IsShown() then
		self:HideMainFrame()
	else
		self:ShowMainFrame()
	end
end
