-- Character profile window (standalone): opinion, tags, notes, history.

local Addon = Raidwise
local W = Addon.Widgets

local function T(key, ...)
	return W.T(key, ...)
end

-- Profile-local sizes (keep in sync with docs/UI-Sizes.md Character profile).
-- Colors come from Addon.UITheme (Classic).
local Theme = Addon.UITheme
local UI = {
	PAD = 10,
	TITLE_H = 20,
	CLOSE_SIZE = 16,
	CHECK_SIZE = 24,
	ACTION_BTN_H = 28,
	ACTION_BTN_GAP = 8,
	PROFILE_ICON = 24,
	RAID_DETAIL_W = 460,
	RAID_DETAIL_H = 560,
	PROFILE_TAB_H = 26,
	GOLD = Theme.GOLD,
	TEXT_IDLE = Theme.TEXT_IDLE,
	TITLE_BG = Theme.TITLE_BG,
	BTN_IDLE = Theme.BTN_IDLE,
	TEXT_HOVER = Theme.TEXT_HOVER,
	TEXT_DISABLED = Theme.TEXT_DISABLED,
	BORDER = Theme.BORDER,
	BORDER_W = Theme.BORDER_W,
}

local PROFILE_LAYOUT_VERSION = 31
local PROFILE_EVENT_ROW_ICON = 14

local function GetRatingTagGroups()
	if Addon.RatingTagGroups then
		return Addon:RatingTagGroups()
	end
	return {}
end

local OPINION_LABEL_KEYS = {
	positive = "RATING_OPINION_POSITIVE",
	neutral = "RATING_OPINION_NEUTRAL",
	negative = "RATING_OPINION_NEGATIVE",
}

local function OpinionButtonLabel(opinionId)
	if Addon.RatingOpinionLabel then
		return Addon:RatingOpinionLabel(opinionId)
	end
	local labelKey = OPINION_LABEL_KEYS[opinionId]
	if labelKey then
		return T(labelKey)
	end
	return tostring(opinionId or "")
end

local function RatingUIReady()
	return Addon.RatingTagGroups ~= nil and Addon.GetPersonalRating ~= nil
end

-- Summary + radios + tags heading only (no "Personal note" title).
local PROFILE_OPINION_HEADER_H = 72
local PROFILE_OPINION_RADIO_SIZE = 16
local PROFILE_OPINION_ROW_H = 22

local function ProfileFrameNeedsRebuild(frame)
	if not frame or frame.layoutVersion ~= PROFILE_LAYOUT_VERSION then
		return true
	end
	if not RatingUIReady() then
		return false
	end
	local groups = GetRatingTagGroups()
	if #groups == 0 then
		return false
	end
	if not frame.tagGroups then
		return true
	end
	return #frame.tagGroups ~= #groups
end

local function CreateProfileNotesBox(parent, width, height)
	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(width, height)
	host:SetBackdrop(W.COPY_BACKDROP)
	W.SetBackdropColor(host, Theme.INPUT_BG)

	local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -24, 6)

	local scrollBar = scroll.ScrollBar or _G["UIPanelScrollFrameTemplateScrollBar"]
	if scrollBar and scrollBar.GetParent and scrollBar:GetParent() == scroll then
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", host, "TOPRIGHT", -20, -16)
		scrollBar:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", -20, 16)
	end

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetFontObject(ChatFontNormal)
	W.SetFontColor(box, Theme.TEXT_BODY)
	box:SetAutoFocus(false)
	box:SetWidth(width - 36)
	box:SetHeight(height - 12)
	box:SetTextInsets(0, 0, 3, 3)
	scroll:SetScrollChild(box)

	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnCursorChanged", function(self, _, y, _, cursorHeight)
		y = -y
		local offset = scroll:GetVerticalScroll()
		if y < offset then
			scroll:SetVerticalScroll(y)
		else
			y = y + (cursorHeight or W.ChatFontLineHeight()) - scroll:GetHeight()
			if y > offset then
				scroll:SetVerticalScroll(y)
			end
		end
	end)
	host.box = box
	host.scroll = scroll
	return host, box
end

local function ProfileFieldValue(value)
	if value == nil or value == "" then
		return "-"
	end
	return tostring(value)
end

local function ProfileFactionText(faction)
	if not faction or faction == "" then
		return "-"
	end
	if faction == "Alliance" and FACTION_ALLIANCE then
		return FACTION_ALLIANCE
	end
	if faction == "Horde" and FACTION_HORDE then
		return FACTION_HORDE
	end
	return faction
end


local RACE_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"
local RACE_ICON_TCOORDS = {
	["HUMAN_MALE"] = { 0, 0.125, 0, 0.25 },
	["DWARF_MALE"] = { 0.125, 0.25, 0, 0.25 },
	["GNOME_MALE"] = { 0.25, 0.375, 0, 0.25 },
	["NIGHTELF_MALE"] = { 0.375, 0.5, 0, 0.25 },
	["TAUREN_MALE"] = { 0, 0.125, 0.25, 0.5 },
	["SCOURGE_MALE"] = { 0.125, 0.25, 0.25, 0.5 },
	["TROLL_MALE"] = { 0.25, 0.375, 0.25, 0.5 },
	["ORC_MALE"] = { 0.375, 0.5, 0.25, 0.5 },
	["HUMAN_FEMALE"] = { 0, 0.125, 0.5, 0.75 },
	["DWARF_FEMALE"] = { 0.125, 0.25, 0.5, 0.75 },
	["GNOME_FEMALE"] = { 0.25, 0.375, 0.5, 0.75 },
	["NIGHTELF_FEMALE"] = { 0.375, 0.5, 0.5, 0.75 },
	["TAUREN_FEMALE"] = { 0, 0.125, 0.75, 1.0 },
	["SCOURGE_FEMALE"] = { 0.125, 0.25, 0.75, 1.0 },
	["TROLL_FEMALE"] = { 0.25, 0.375, 0.75, 1.0 },
	["ORC_FEMALE"] = { 0.375, 0.5, 0.75, 1.0 },
	["BLOODELF_MALE"] = { 0.5, 0.625, 0.25, 0.5 },
	["BLOODELF_FEMALE"] = { 0.5, 0.625, 0.75, 1.0 },
	["DRAENEI_MALE"] = { 0.5, 0.625, 0, 0.25 },
	["DRAENEI_FEMALE"] = { 0.5, 0.625, 0.5, 0.75 },
}

local function ProfileRaceLabel(raceToken)
	if not raceToken or raceToken == "" then
		return "-"
	end
	local localized = _G[raceToken]
	if type(localized) == "string" and localized ~= "" then
		return localized
	end
	return raceToken
end

local function SetProfileRaceIcon(texture, raceToken, gender)
	if not texture then
		return false
	end
	if not raceToken or raceToken == "" then
		texture:Hide()
		return false
	end
	local genderKey = (gender == 3) and "FEMALE" or "MALE"
	local raceKey = strupper(raceToken) .. "_" .. genderKey
	local coords = RACE_ICON_TCOORDS[raceKey]
	if not coords then
		texture:Hide()
		return false
	end
	texture:SetTexture(RACE_ICON_TEXTURE)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	texture:Show()
	return true
end

local PROFILE_TABS = {
	{ id = "history", labelKey = "PROFILE_TAB_HISTORY" },
	{ id = "opinion", labelKey = "PROFILE_TAB_OPINION" },
	{ id = "facts", labelKey = "PROFILE_TAB_FACTS" },
	{ id = "events", labelKey = "PROFILE_TAB_EVENTS" },
	{ id = "notes", labelKey = "PROFILE_TAB_NOTES" },
}

local UpdateProfileEventsPanel
local RefreshProfileFactCheckboxes
local UpdateProfileCommitButton

UpdateProfileCommitButton = function(frame, tabId)
	if not frame then
		return
	end
	tabId = tabId or frame.selectedProfileTab or "history"
	local showCommit = tabId == "opinion" or tabId == "facts" or tabId == "events"
	local editable = frame.profileMember and frame.profileMember.guid and frame.profileMember.guid ~= ""
	if frame.ratingUpdateBtn then
		if showCommit then
			frame.ratingUpdateBtn:Show()
			if editable then
				frame.ratingUpdateBtn:Enable()
			else
				frame.ratingUpdateBtn:Disable()
			end
		else
			frame.ratingUpdateBtn:Hide()
		end
	end
	if frame.tabHost and frame.tabBar and frame.body then
		frame.tabHost:ClearAllPoints()
		frame.tabHost:SetPoint("TOPLEFT", frame.tabBar, "BOTTOMLEFT", 0, -8)
		if showCommit then
			frame.tabHost:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, UI.ACTION_BTN_H + 8)
		else
			frame.tabHost:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
		end
	end
end

function Addon:SelectProfileTab(tabId)
	local frame = self.raidDetailFrame
	if not frame or not frame.profilePanels then
		return
	end
	frame.selectedProfileTab = tabId
	for id, panel in pairs(frame.profilePanels) do
		if id == tabId then
			panel:Show()
		else
			panel:Hide()
		end
	end
	if frame.profileTabButtons then
		for _, button in ipairs(frame.profileTabButtons) do
			W.SetMenuButtonState(button, button.tabId == tabId, false)
		end
	end
	-- Save and Update commits Note/Facts/Events drafts only; Memo has its own Save/Reset.
	UpdateProfileCommitButton(frame, tabId)
	if tabId == "history" and frame.profileMember then
		Addon:RefreshProfileHistoryPanel(frame, frame.profileMember, PROFILE_EVENT_ROW_ICON)
	end
	if tabId == "events" and frame.profileMember then
		UpdateProfileEventsPanel(frame, frame.profileMember)
	end
	if tabId == "facts" and frame.profileMember then
		RefreshProfileFactCheckboxes(frame, frame.profileMember, frame.profileMember.guid and frame.profileMember.guid ~= "")
	end
end

local function CreateProfileTabButton(parent, tabId, label, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, UI.PROFILE_TAB_H)
	W.ApplyPlainPanel(button, UI.BTN_IDLE)
	button.tabId = tabId

	local text = W.CreateFontString(button, nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", 6, 0)
	text:SetPoint("RIGHT", -6, 0)
	text:SetJustifyH("CENTER")
	text:SetText(label)
	button.label = text

	button:SetScript("OnEnter", function(self)
		W.SetMenuButtonState(self, Addon.raidDetailFrame and Addon.raidDetailFrame.selectedProfileTab == tabId, true)
	end)
	button:SetScript("OnLeave", function(self)
		W.SetMenuButtonState(self, Addon.raidDetailFrame and Addon.raidDetailFrame.selectedProfileTab == tabId, false)
	end)
	button:SetScript("OnClick", function()
		Addon:SelectProfileTab(tabId)
	end)
	W.SetMenuButtonState(button, false, false)
	return button
end

local CopyEventList = Addon.ProfileDraft.CopyEvents
local SortEventsNewestFirst = Addon.ProfileDraft.SortEvents

local function GetDraftState(frame)
	if not frame.profileDraft then frame.profileDraft = Addon:CreateProfileDraft(frame.profileMember) end
	return frame.profileDraft
end

local function InitProfileDraft(frame, member)
	if frame then frame.profileDraft = Addon:CreateProfileDraft(member) end
end

local function GetProfileDraft(frame)
	if not frame then
		return "neutral", {}, {}
	end
	return GetDraftState(frame).draftOpinion or "neutral", GetDraftState(frame).draftTags or {}, GetDraftState(frame).draftFacts or {}
end

local function GetProfileDraftEvents(frame)
	if not frame or type(GetDraftState(frame).draftEvents) ~= "table" then
		return {}
	end
	return GetDraftState(frame).draftEvents
end

-- AceConfigDialog / Details radio pattern: exclusive SetChecked on the whole group.
local function RefreshOpinionRadios(frame, selectedOpinion)
	if not frame or not frame.opinionButtons then
		return
	end
	selectedOpinion = selectedOpinion or "neutral"
	for _, radio in ipairs(frame.opinionButtons) do
		local checked = radio.opinionId == selectedOpinion
		radio.isUpdating = true
		radio:SetChecked(checked)
		-- Some clients leave CheckedTexture visible after SetChecked(false); force it.
		local checkedTexture = radio.GetCheckedTexture and radio:GetCheckedTexture()
		if checkedTexture then
			if checked then
				checkedTexture:Show()
			else
				checkedTexture:Hide()
			end
		end
		if radio.label then
			radio.label:SetText(OpinionButtonLabel(radio.opinionId))
			if radio:IsEnabled() then
				W.SetFontColor(radio.label, checked and UI.GOLD or UI.TEXT_IDLE)
			else
				W.SetFontColor(radio.label, UI.TEXT_DISABLED)
			end
		end
		radio.isUpdating = false
	end
end

-- Paint Personal note + Summary from the chosen opinion immediately (same click as radios).
local function PaintOpinionLabels(frame, opinionId, tags, targets)
	if not frame then
		return
	end
	opinionId = opinionId or "neutral"
	tags = tags or {}
	targets = targets or "all"
	local paintHeader = targets == "all" or targets == "header"
	local paintEditor = targets == "all" or targets == "editor"

	local label = OpinionButtonLabel(opinionId)
	local color = UI.TEXT_IDLE
	if Addon.RatingOpinionColor then
		color = Addon:RatingOpinionColor(opinionId)
	end
	if paintHeader and frame.opinionText then
		frame.opinionText:SetText(T("RATING_PROFILE_OPINION", label))
		W.SetFontColor(frame.opinionText, color)
	end
	if paintHeader and frame.tagText then
		local tagSummary = ""
		if Addon.RatingTagColoredSummary then
			tagSummary = Addon:RatingTagColoredSummary(tags, 3) or ""
		end
		if tagSummary ~= "" then
			frame.tagText:SetText(tagSummary)
			W.SetFontColor(frame.tagText, UI.TEXT_IDLE)
		else
			frame.tagText:SetText(T("RATING_TAGS_NONE"))
			W.SetFontColor(frame.tagText, UI.TEXT_DISABLED)
		end
	end
	if paintEditor and frame.ratingSummary then
		local opinionText = label
		if Addon.RatingWrapColor then
			opinionText = Addon:RatingWrapColor(label, color)
		end
		local tagPart = T("RATING_TAGS_NONE")
		if Addon.RatingTagColoredSummary then
			local colored = Addon:RatingTagColoredSummary(tags, 3)
			if colored and colored ~= "" then
				tagPart = colored
			end
		end
		frame.ratingSummary:SetText(T("RATING_PROFILE_SUMMARY", opinionText, tagPart))
	end
end

local function PaintSavedHeaderLabels(frame, member)
	if not frame or not member or not Addon.GetPersonalRating then
		return
	end
	local personal = Addon:GetPersonalRating(member)
	PaintOpinionLabels(frame, personal.opinion, personal.tags, "header")
	if frame.factText then
		local factSummary = ""
		if Addon.FactColoredSummary then
			factSummary = Addon:FactColoredSummary(personal.facts, 3) or ""
		end
		if factSummary ~= "" then
			frame.factText:SetText(T("RATING_PROFILE_FACTS", factSummary))
			W.SetFontColor(frame.factText, UI.TEXT_IDLE)
		else
			frame.factText:SetText(T("RATING_PROFILE_FACTS", T("RATING_FACTS_NONE")))
			W.SetFontColor(frame.factText, UI.TEXT_DISABLED)
		end
	end
end

local function PaintDraftEditorLabels(frame)
	if not frame then
		return
	end
	local opinion, tags = GetProfileDraft(frame)
	PaintOpinionLabels(frame, opinion, tags, "editor")
end

local function ApplyOpinionChoice(opinionId)
	if not opinionId then
		return
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	local frame = Addon.raidDetailFrame
	if not frame then
		return
	end
	GetDraftState(frame).draftOpinion = opinionId
	-- Draft only; CommitProfileRating (Save) persists. Header stays on saved values.
	RefreshOpinionRadios(frame, opinionId)
	PaintDraftEditorLabels(frame)
end

local function CreateOpinionRadio(parent, opinionId, columnWidth)
	local host = CreateFrame("Frame", nil, parent)
	host:SetSize(columnWidth, PROFILE_OPINION_ROW_H)

	-- UIRadioButtonTemplate: engine owns checked texture (DBM / Blizzard options style).
	local radio = CreateFrame("CheckButton", nil, host, "UIRadioButtonTemplate")
	radio:SetSize(PROFILE_OPINION_RADIO_SIZE, PROFILE_OPINION_RADIO_SIZE)
	radio:SetPoint("LEFT", 0, 0)
	radio.opinionId = opinionId

	local label = W.CreateFontString(host, nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", radio, "RIGHT", 4, 0)
	label:SetPoint("RIGHT", host, "RIGHT", 0, 0)
	label:SetJustifyH("LEFT")
	label:SetText(OpinionButtonLabel(opinionId))
	W.SetFontColor(label, UI.TEXT_IDLE)
	radio.label = label
	radio.host = host

	-- Label-only hit target. Do NOT cover the radio or call :Click() — that toggles
	-- one control without clearing siblings on some 3.3.5 clients.
	local hit = CreateFrame("Button", nil, host)
	hit:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
	hit:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, -2)
	hit:SetScript("OnClick", function()
		if radio:IsEnabled() then
			ApplyOpinionChoice(radio.opinionId)
		end
	end)
	radio.hit = hit

	radio:SetScript("OnClick", function(self)
		if self.isUpdating then
			return
		end
		-- Engine already toggled this button; re-apply exclusive group state.
		ApplyOpinionChoice(self.opinionId)
	end)

	return radio
end

local PROFILE_TAG_ROW_H = 22
local PROFILE_TAG_GROUP_HEADING_H = 18
local PROFILE_TAG_GROUP_GAP = 8
local PROFILE_TAG_COL_GAP = 12
local PROFILE_EVENT_PICKER_H = 140
local PROFILE_EVENT_TYPE_BTN_H = 20
local PROFILE_EVENT_TYPE_ROW_H = 22
local PROFILE_EVENT_GROUP_ICON = 16

local ratingViewRefreshScheduled

local function ScheduleRatingViewRefresh()
	if ratingViewRefreshScheduled then
		return
	end
	ratingViewRefreshScheduled = CreateFrame("Frame")
	ratingViewRefreshScheduled:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		ratingViewRefreshScheduled = nil
		Addon:RefreshRatingViews()
	end)
end

local function CountSelectedTagsInGroup(tags, group)
	if type(tags) ~= "table" or type(group) ~= "table" or type(group.tags) ~= "table" then
		return 0
	end
	local selected = {}
	for index = 1, #tags do
		selected[tags[index]] = true
	end
	local count = 0
	for index = 1, #group.tags do
		if selected[group.tags[index].id] then
			count = count + 1
		end
	end
	return count
end

local function TagCheckboxLabel(tagId)
	if Addon.RatingTagLabel then
		return Addon:RatingTagLabel(tagId)
	end
	return tostring(tagId)
end

local function TagCheckboxColor(tagId)
	local tag = Addon.RatingTagById and Addon:RatingTagById(tagId)
	if tag and Addon.RatingMetaColor then
		return Addon:RatingMetaColor(tag.meta)
	end
	return UI.TEXT_IDLE
end

local function SetProfileTagCheckboxState(checkbox, checked, enabled)
	if not checkbox then
		return
	end
	checkbox.isUpdating = true
	checkbox:SetChecked(checked and true or false)
	if enabled then
		checkbox:Enable()
		checkbox:SetAlpha(1)
		if checkbox.label then
			W.SetFontColor(checkbox.label, checkbox.labelColor or UI.TEXT_IDLE)
		end
		if checkbox.hit then
			checkbox.hit:Enable()
		end
	else
		checkbox:Disable()
		checkbox:SetAlpha(0.55)
		if checkbox.label then
			W.SetFontColor(checkbox.label, UI.TEXT_DISABLED)
		end
		if checkbox.hit then
			checkbox.hit:Disable()
		end
	end
	checkbox.isUpdating = false
end

local function RefreshProfileTagCheckboxes(frame, member, editable)
	if not frame or not frame.tagGroups then
		return
	end

	local selected = {}
	local _, draftTags = GetProfileDraft(frame)
	for index = 1, #draftTags do
		selected[draftTags[index]] = true
	end

	for _, entry in ipairs(frame.tagGroups) do
		if entry.label then
			entry.label:SetText(T(entry.group.labelKey))
		end
		local groupCount = CountSelectedTagsInGroup(draftTags, entry.group)
		for _, checkbox in ipairs(entry.checkboxes) do
			local tagId = checkbox.tagId
			local isSelected = selected[tagId] and true or false
			local canUse = editable and (isSelected or groupCount < 3)
			SetProfileTagCheckboxState(checkbox, isSelected, canUse)
		end
	end
end

RefreshProfileFactCheckboxes = function(frame, member, editable)
	if not frame or not frame.factCheckboxes then
		return
	end
	local selected = {}
	local _, _, draftFacts = GetProfileDraft(frame)
	for index = 1, #draftFacts do
		selected[draftFacts[index]] = true
	end
	local maxFacts = (Addon.MaxPersonalFacts and Addon:MaxPersonalFacts()) or 4
	local selectedCount = #draftFacts
	if frame.factsHint then
		frame.factsHint:SetText(T("RATING_FACTS_HINT", maxFacts))
	end
	if frame.factsHeading then
		frame.factsHeading:SetText(T("RATING_FACTS_TITLE"))
	end
	for _, checkbox in ipairs(frame.factCheckboxes) do
		local factId = checkbox.factId
		local isSelected = selected[factId] and true or false
		local canUse = editable and (isSelected or selectedCount < maxFacts)
		if checkbox.label and Addon.FactLabel then
			checkbox.label:SetText(Addon:FactLabel(factId))
		end
		SetProfileTagCheckboxState(checkbox, isSelected, canUse)
	end
end

local function FormatEventContextSuffix(event)
	if type(event) ~= "table" or type(event.context) ~= "table" then
		return ""
	end
	local context = event.context
	local place = context.instanceName
	if not place or place == "" then
		place = context.zoneName
	end
	if not place or place == "" then
		return ""
	end
	local suffix = place
	if context.difficulty and context.difficulty ~= "" then
		suffix = suffix .. " (" .. tostring(context.difficulty) .. ")"
	end
	return " — " .. suffix
end

-- REFACTOR candidate: destroys/recreates event rows each refresh; split row factory from localization.
UpdateProfileEventsPanel = function(frame, member)
	if not frame or not frame.eventsListContent then
		return
	end
	local events = SortEventsNewestFirst(GetProfileDraftEvents(frame))
	if frame.eventsHeading then
		frame.eventsHeading:SetText(T("PROFILE_TAB_EVENTS"))
	end
	if frame.eventsAddBtn and frame.eventsAddBtn.label then
		frame.eventsAddBtn.label:SetText(T("PROFILE_EVENTS_ADD"))
	end
	if frame.eventsPickLabel then
		frame.eventsPickLabel:SetText(T("PROFILE_EVENTS_PICK_TYPE"))
	end
	if frame.eventTypeGroupLabels then
		for _, heading in ipairs(frame.eventTypeGroupLabels) do
			if heading.labelKey then
				heading:SetText(T(heading.labelKey))
			end
		end
	end
	if frame.eventTypeButtons then
		for _, button in ipairs(frame.eventTypeButtons) do
			if button.label and button.eventTypeId and Addon.EventTypeLabel then
				button.label:SetText(Addon:EventTypeLabel(button.eventTypeId))
			end
			W.SetMenuButtonState(button, frame.selectedEventType == button.eventTypeId, false)
		end
	end

	if frame.eventRows then
		for _, row in ipairs(frame.eventRows) do
			row:Hide()
			row:SetParent(nil)
		end
	end
	frame.eventRows = {}
	frame.eventRemoveButtons = {}

	local rowHeight = 20
	local contentWidth = (frame.eventsListContent:GetWidth() or 400)
	local y = 0
	if #events == 0 then
		local row = CreateFrame("Frame", nil, frame.eventsListContent)
		row:SetSize(contentWidth, rowHeight)
		row:SetPoint("TOPLEFT", frame.eventsListContent, "TOPLEFT", 0, 0)
		local empty = W.CreateFontString(row, nil, "OVERLAY", "GameFontHighlight")
		empty:SetPoint("LEFT", 0, 0)
		empty:SetPoint("RIGHT", 0, 0)
		empty:SetJustifyH("LEFT")
		empty:SetText(T("PROFILE_EVENTS_EMPTY"))
		row.label = empty
		frame.eventRows[1] = row
		y = rowHeight
	else
		for index = 1, #events do
			local event = events[index]
			local when = Addon.FormatHistoryTime and Addon:FormatHistoryTime(event.eventAt) or "?"
			local label = Addon.EventTypeDisplayLabel and Addon:EventTypeDisplayLabel(event.type)
				or (Addon.EventTypeLabel and Addon:EventTypeLabel(event.type) or tostring(event.type))
			local line = when .. " — " .. label .. FormatEventContextSuffix(event)

			local row = CreateFrame("Frame", nil, frame.eventsListContent)
			row:SetSize(contentWidth, rowHeight)
			row:SetPoint("TOPLEFT", frame.eventsListContent, "TOPLEFT", 0, -y)

			local icon = row:CreateTexture(nil, "ARTWORK")
			icon:SetSize(PROFILE_EVENT_ROW_ICON, PROFILE_EVENT_ROW_ICON)
			icon:SetPoint("LEFT", 0, 0)
			local groupIcon = Addon.EventTypeGroupIcon and Addon:EventTypeGroupIcon(event.type)
			if groupIcon then
				W.SetSpellIconTexture(icon, groupIcon)
			end
			row.icon = icon

			local text = W.CreateFontString(row, nil, "OVERLAY", "GameFontHighlightSmall")
			text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
			text:SetPoint("RIGHT", row, "RIGHT", -76, 0)
			text:SetJustifyH("LEFT")
			text:SetJustifyV("MIDDLE")
			text:SetText(line)
			row.label = text

			local button = W.CreatePlainButton(row, 70, 18, T("PROFILE_EVENT_REMOVE"))
			button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
			button.eventId = event.id
			button:SetScript("OnClick", function(self)
				Addon:RemoveProfileEvent(self.eventId)
			end)
			row.removeBtn = button
			frame.eventRemoveButtons[#frame.eventRemoveButtons + 1] = button
			frame.eventRows[#frame.eventRows + 1] = row
			y = y + rowHeight
		end
	end
	frame.eventsListContent:SetHeight(math.max(y, 1))
end

-- Keep an open Character profile in sync when history auto-records an event
-- (so Save and Update does not drop it from the Events draft).
function Addon:SyncOpenProfileHistoryEvent(entry, event)
	local frame = self.raidDetailFrame
	if not frame or not frame:IsShown() or type(entry) ~= "table" or type(event) ~= "table" then
		return
	end
	local member = frame.profileMember
	if not member or member.guid ~= entry.guid then
		return
	end
	member.meetCount = entry.meetCount
	member.changes = entry.changes
	member.events = entry.events
	if type(GetDraftState(frame).draftEvents) == "table" then
		local already = false
		for index = 1, #GetDraftState(frame).draftEvents do
			if GetDraftState(frame).draftEvents[index].id == event.id then
				already = true
				break
			end
		end
		if not already then
			table.insert(GetDraftState(frame).draftEvents, 1, event)
		end
	end
	Addon:RefreshProfileHistoryPanel(frame, member, PROFILE_EVENT_ROW_ICON)
	UpdateProfileEventsPanel(frame, member)
end

-- REFACTOR candidate: near-duplicate of CreateProfileTagCheckbox; extract shared draft-checkbox factory.
local function CreateProfileFactCheckbox(parent, fact, columnWidth)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(UI.CHECK_SIZE, UI.CHECK_SIZE)
	local checkName = check:GetName()
	local templateText = checkName and _G[checkName .. "Text"]
	if templateText then
		templateText:SetText("")
		templateText:Hide()
	end
	check.factId = fact.id

	local label = W.CreateFontString(parent, nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetWidth(columnWidth - UI.CHECK_SIZE - 4)
	label:SetJustifyH("LEFT")
	label:SetText(Addon.FactLabel and Addon:FactLabel(fact.id) or fact.id)
	check.labelColor = (Addon.RatingMetaColor and Addon:RatingMetaColor("fact")) or UI.TEXT_IDLE
	W.SetFontColor(label, check.labelColor)
	check.label = label

	local hit = CreateFrame("Button", nil, parent)
	hit:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
	hit:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, 0)
	hit:SetScript("OnClick", function()
		if check:IsEnabled() then
			check:Click()
		end
	end)
	check.hit = hit

	check:SetScript("OnClick", function(self)
		if self.isUpdating then
			return
		end
		local wantChecked = self:GetChecked()
		local _, _, draftFacts = GetProfileDraft(Addon.raidDetailFrame)
		if wantChecked then
			local maxFacts = (Addon.MaxPersonalFacts and Addon:MaxPersonalFacts()) or 4
			if #draftFacts >= maxFacts then
				self:SetChecked(false)
				Addon:Print(Addon:T("RATING_FACTS_LIMIT", maxFacts))
				return
			end
		end
		Addon:ToggleProfileFact(self.factId)
	end)

	return check
end

-- REFACTOR candidate: near-duplicate of CreateProfileFactCheckbox; extract shared draft-checkbox factory.
local function CreateProfileTagCheckbox(parent, tag, group, columnWidth)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(UI.CHECK_SIZE, UI.CHECK_SIZE)
	local checkName = check:GetName()
	local templateText = checkName and _G[checkName .. "Text"]
	if templateText then
		templateText:SetText("")
		templateText:Hide()
	end
	check.tagId = tag.id
	check.groupId = group.id

	local label = W.CreateFontString(parent, nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetWidth(columnWidth - UI.CHECK_SIZE - 4)
	label:SetJustifyH("LEFT")
	label:SetText(TagCheckboxLabel(tag.id))
	check.labelColor = TagCheckboxColor(tag.id)
	W.SetFontColor(label, check.labelColor)
	check.label = label

	local hit = CreateFrame("Button", nil, parent)
	hit:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
	hit:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, 0)
	hit:SetScript("OnClick", function()
		if check:IsEnabled() then
			check:Click()
		end
	end)
	check.hit = hit

	check:SetScript("OnClick", function(self)
		if self.isUpdating then
			return
		end
		local wantChecked = self:GetChecked()
		local profileFrame = Addon.raidDetailFrame
		local _, draftTags = GetProfileDraft(profileFrame)
		if wantChecked then
			if CountSelectedTagsInGroup(draftTags, group) >= 3 then
				self:SetChecked(false)
				Addon:Print(Addon:T("RATING_GROUP_LIMIT"))
				return
			end
		end
		Addon:ToggleProfileTag(self.tagId)
	end)

	return check
end

local function ProfileTagGroupHeight(tagCount)
	local rows = math.ceil(tagCount / 2)
	return PROFILE_TAG_GROUP_HEADING_H + (rows * PROFILE_TAG_ROW_H) + PROFILE_TAG_GROUP_GAP
end

local function UpdateProfileOpinionControls(frame, member)
	if not frame or not member then
		return
	end
	local opinion, tags = GetProfileDraft(frame)
	PaintSavedHeaderLabels(frame, member)
	PaintOpinionLabels(frame, opinion, tags, "editor")
	RefreshOpinionRadios(frame, opinion)
end

local function UpdateProfileEditor(frame, member)
	if not frame or not member then
		return
	end
	UpdateProfileOpinionControls(frame, member)
	if frame.tagGroups then
		local editable = member.guid and member.guid ~= ""
		RefreshProfileTagCheckboxes(frame, member, editable)
	end
	if frame.factCheckboxes then
		local editable = member.guid and member.guid ~= ""
		RefreshProfileFactCheckboxes(frame, member, editable)
	end
	UpdateProfileEventsPanel(frame, member)
	if frame.communityHeading then
		frame.communityHeading:SetText(T("RATING_COMMUNITY_TITLE"))
	end
	if frame.communityText then
		frame.communityText:SetText(T("RATING_COMMUNITY_MOCK"))
	end
	Addon:RefreshProfileHistoryPanel(frame, member, PROFILE_EVENT_ROW_ICON)
end

function Addon:RefreshRatingViews()
	local frame = self.mainFrame
	if frame and frame:IsShown() then
		if frame.selectedTab == "raid" and self.RefreshRaidRosterView then
			self:RefreshRaidRosterView(false)
		elseif frame.selectedTab == "history" and self.RefreshHistoryView then
			self:RefreshHistoryView()
		end
	end
end

-- REFACTOR candidate: options.opinionOnly / tagsOnly / deferViewRefresh are never passed (unreachable branches).
function Addon:SaveProfilePersonalRating(opinion, tagIds, factIds, options)
	local frame = self.raidDetailFrame
	local member = frame and frame.profileMember
	if not member or not member.guid or member.guid == "" or not self.SavePersonalRatingForGuid then
		return
	end
	local entry = self:SavePersonalRatingForGuid(member.guid, member, opinion, tagIds, factIds)
	if not entry then
		return
	end
	-- Rebuild from the saved history entry so opinion/tags/facts/changes match the DB.
	frame.profileMember = self:HistoryProfileForMember(entry)
	if type(entry.changes) == "table" then
		frame.profileMember.changes = entry.changes
	end
	if type(entry.events) == "table" then
		frame.profileMember.events = entry.events
	end
	frame.profileMember.rating = {
		personal = self:GetPersonalRating(entry),
	}
	if options and options.opinionOnly then
		UpdateProfileOpinionControls(frame, frame.profileMember)
	elseif options and options.tagsOnly then
		if frame.tagGroups then
			local editable = frame.profileMember.guid and frame.profileMember.guid ~= ""
			RefreshProfileTagCheckboxes(frame, frame.profileMember, editable)
		end
		UpdateProfileOpinionControls(frame, frame.profileMember)
	else
		UpdateProfileEditor(frame, frame.profileMember)
	end
	if options and options.deferViewRefresh then
		ScheduleRatingViewRefresh()
	else
		self:RefreshRatingViews()
	end
end

function Addon:SaveProfileNotes(notes)
	local frame = self.raidDetailFrame
	local member = frame and frame.profileMember
	if not member or not member.guid or member.guid == "" or not self.SaveProfileNotesForGuid then
		return
	end
	local entry = self:SaveProfileNotesForGuid(member.guid, member, notes)
	if not entry then
		return
	end
	frame.profileMember = self:HistoryProfileForMember(member)
	if frame.notesBox then
		frame.isUpdatingNotes = true
		frame.notesBox:SetText(frame.profileMember.notes or "")
		frame.isUpdatingNotes = false
	end
	self:RefreshRatingViews()
end

function Addon:ResetProfileNotes()
	local frame = self.raidDetailFrame
	local member = frame and frame.profileMember
	if not member or not member.guid or member.guid == "" then
		return
	end
	if frame.notesBox then
		frame.isUpdatingNotes = true
		frame.notesBox:SetText("")
		frame.notesBox:ClearFocus()
		frame.isUpdatingNotes = false
	end
	self:SaveProfileNotes("")
end

-- DELETE candidate: no callers; opinion changes go through ApplyOpinionChoice / radio handlers.
function Addon:SetProfileOpinion(opinion)
	ApplyOpinionChoice(opinion)
end

function Addon:ToggleProfileTag(tagId)
	local frame = self.raidDetailFrame
	if not frame then
		return
	end
	local ok, key, limit = self:ToggleProfileDraftTag(GetDraftState(frame), tagId)
	if not ok then self:Print(self:T(key, limit)); return end
	PaintDraftEditorLabels(frame)
	if frame.tagGroups then
		local member = frame.profileMember
		local editable = member and member.guid and member.guid ~= ""
		RefreshProfileTagCheckboxes(frame, member, editable)
	end
end

function Addon:ToggleProfileFact(factId)
	local frame = self.raidDetailFrame
	if not frame or not factId then
		return
	end
	local ok, key, limit = self:ToggleProfileDraftFact(GetDraftState(frame), factId)
	if not ok then self:Print(self:T(key, limit)); return end
	if frame.factCheckboxes then
		local member = frame.profileMember
		local editable = member and member.guid and member.guid ~= ""
		RefreshProfileFactCheckboxes(frame, member, editable)
	end
end

function Addon:CommitProfileRating()
	local frame = self.raidDetailFrame
	local member = frame and frame.profileMember
	if not member or not member.guid or member.guid == "" then
		return
	end
	local opinion, tags, facts = GetProfileDraft(frame)
	local draftEvents = CopyEventList(GetProfileDraftEvents(frame))
	self:SaveProfilePersonalRating(opinion, tags, facts, {})
	if self.SaveHistoryEventsForGuid then
		local entry = self:SaveHistoryEventsForGuid(member.guid, frame.profileMember or member, draftEvents)
		if entry then
			frame.profileMember = self:HistoryProfileForMember(entry)
			if type(entry.changes) == "table" then
				frame.profileMember.changes = entry.changes
			end
			if type(entry.events) == "table" then
				frame.profileMember.events = entry.events
			end
			frame.profileMember.rating = {
				personal = self:GetPersonalRating(entry),
			}
		end
	end
	InitProfileDraft(frame, frame.profileMember)
	UpdateProfileEditor(frame, frame.profileMember)
end

function Addon:AddProfileEvent(eventTypeId)
	local frame = self.raidDetailFrame
	local member = frame and frame.profileMember
	if not member or not member.guid or member.guid == "" or not eventTypeId then
		return
	end
	self:AddProfileDraftEvent(GetDraftState(frame), eventTypeId)
	UpdateProfileEventsPanel(frame, member)
end

function Addon:RemoveProfileEvent(eventId)
	local frame = self.raidDetailFrame
	if not frame or not eventId or eventId == "" then
		return
	end
	self:RemoveProfileDraftEvent(GetDraftState(frame), eventId)
	UpdateProfileEventsPanel(frame, frame.profileMember)
end

local function CreateRaidCharacterWindow()
	local frame = CreateFrame("Frame", "RaidwiseRaidCharacterFrame", UIParent)
	-- Named frames are reused; drop old children so prior layouts cannot steal clicks.
	W.DetachFrameChildren(frame)
	frame:SetSize(UI.RAID_DETAIL_W, UI.RAID_DETAIL_H)
	frame:SetPoint("CENTER", 40, 20)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:Hide()
	W.ApplyPlainPanel(frame)
	W.ApplyOuterBorder(frame)
	frame.layoutVersion = PROFILE_LAYOUT_VERSION
	frame.opinionButtons = nil
	frame.profileTabButtons = nil
	frame.profilePanels = nil
	frame.tagGroups = nil
	if not frame.rwInSpecialFrames then
		tinsert(UISpecialFrames, "RaidwiseRaidCharacterFrame")
		frame.rwInSpecialFrames = true
	end
	-- Esc / X / Hide: push saved opinion, tags, and notes into the open roster/history tab.
	frame:SetScript("OnHide", function()
		Addon:RefreshRatingViews()
	end)

	local titleBar = CreateFrame("Frame", nil, frame)
	titleBar:SetPoint("TOPLEFT", UI.BORDER_W, -UI.BORDER_W)
	titleBar:SetPoint("TOPRIGHT", -UI.BORDER_W, -UI.BORDER_W)
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

	local layoutVersionText = W.AttachLayoutVersionLabel(titleBar, PROFILE_LAYOUT_VERSION, close)
	frame.layoutVersionText = layoutVersionText

	local title = W.CreateFontString(titleBar, nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 8, 0)
	title:SetPoint("RIGHT", layoutVersionText, "LEFT", -8, 0)
	title:SetJustifyH("LEFT")
	W.SetFontColor(title, UI.GOLD)
	frame.titleText = title

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", UI.PAD, -(UI.TITLE_H + UI.PAD))
	body:SetPoint("BOTTOMRIGHT", -UI.PAD, UI.PAD)
	frame.body = body

	local bodyWidth = UI.RAID_DETAIL_W - UI.PAD * 2
	local columnGap = 12
	local columnWidth = math.floor((bodyWidth - columnGap) / 2)
	local iconSize = UI.PROFILE_ICON

	local header = CreateFrame("Frame", nil, body)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", 0, 0)
	header:SetHeight(iconSize + 22)
	frame.headerSection = header

	local classCell = CreateFrame("Frame", nil, header)
	classCell:SetPoint("TOPLEFT", 0, 0)
	classCell:SetSize(columnWidth, iconSize)
	frame.classCell = classCell

	local raceIconHost = CreateFrame("Frame", nil, classCell)
	raceIconHost:SetSize(iconSize, iconSize)
	raceIconHost:SetPoint("TOPLEFT", 0, 0)
	frame.raceIconHost = raceIconHost

	local raceIcon = raceIconHost:CreateTexture(nil, "ARTWORK")
	raceIcon:SetAllPoints(raceIconHost)
	frame.raceIcon = raceIcon
	raceIconHost:EnableMouse(true)
	raceIconHost:SetScript("OnEnter", function(self)
		local member = frame.profileMember
		if not member then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ProfileRaceLabel(member.race))
		local factionText = ProfileFactionText(member.faction)
		if factionText ~= "-" then
			GameTooltip:AddLine(factionText, 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	raceIconHost:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local classIconHost = CreateFrame("Frame", nil, classCell)
	classIconHost:SetSize(iconSize, iconSize)
	classIconHost:SetPoint("LEFT", raceIconHost, "RIGHT", 2, 0)
	frame.classIconHost = classIconHost

	local classIcon = classIconHost:CreateTexture(nil, "ARTWORK")
	classIcon:SetAllPoints(classIconHost)
	frame.classIcon = classIcon

	local classText = W.CreateFontString(classCell, nil, "OVERLAY", "GameFontNormalSmall")
	classText:SetPoint("TOPLEFT", classIconHost, "TOPRIGHT", 4, 0)
	classText:SetPoint("BOTTOMLEFT", classIconHost, "BOTTOMRIGHT", 4, 0)
	classText:SetPoint("RIGHT", classCell, "RIGHT", 0, 0)
	classText:SetJustifyH("LEFT")
	classText:SetJustifyV("MIDDLE")
	frame.classText = classText

	local specIconHost = CreateFrame("Frame", nil, header)
	specIconHost:SetSize(iconSize, iconSize)
	specIconHost:SetPoint("TOPLEFT", columnWidth + columnGap, 0)
	frame.specIconHost = specIconHost

	local specIcon = specIconHost:CreateTexture(nil, "ARTWORK")
	specIcon:SetAllPoints(specIconHost)
	frame.specIcon = specIcon

	local specText = W.CreateFontString(header, nil, "OVERLAY", "GameFontNormalSmall")
	specText:SetPoint("TOPLEFT", specIconHost, "TOPRIGHT", 6, 0)
	specText:SetPoint("BOTTOMLEFT", specIconHost, "BOTTOMRIGHT", 6, 0)
	specText:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	specText:SetJustifyH("LEFT")
	specText:SetJustifyV("MIDDLE")
	frame.specText = specText

	local gsText = W.CreateFontString(header, nil, "OVERLAY", "GameFontNormalSmall")
	gsText:SetPoint("TOPLEFT", classCell, "BOTTOMLEFT", 0, -4)
	gsText:SetWidth(columnWidth)
	gsText:SetJustifyH("LEFT")
	W.SetFontColor(gsText, UI.TEXT_IDLE)
	frame.gsText = gsText

	local ilvlText = W.CreateFontString(header, nil, "OVERLAY", "GameFontNormalSmall")
	ilvlText:SetPoint("TOPLEFT", specIconHost, "BOTTOMLEFT", 0, -4)
	ilvlText:SetWidth(columnWidth)
	ilvlText:SetJustifyH("LEFT")
	W.SetFontColor(ilvlText, UI.TEXT_IDLE)
	frame.ilvlText = ilvlText

	local summary = CreateFrame("Frame", nil, body)
	summary:SetPoint("TOPLEFT", gsText, "BOTTOMLEFT", 0, -4)
	summary:SetPoint("TOPRIGHT", ilvlText, "BOTTOMRIGHT", 0, -4)
	summary:SetHeight(122)
	frame.summarySection = summary

	local function CreateSummaryLine(parent, anchor, topOffset, width)
		local text = W.CreateFontString(parent, nil, "OVERLAY", "GameFontNormalSmall")
		if anchor then
			text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, topOffset or -6)
		else
			text:SetPoint("TOPLEFT", 0, 0)
		end
		text:SetWidth(width)
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		W.SetFontColor(text, UI.TEXT_IDLE)
		return text
	end

	frame.opinionText = CreateSummaryLine(summary, nil, 0, columnWidth)
	frame.tagText = CreateSummaryLine(summary, frame.opinionText, -6, columnWidth)
	frame.factText = CreateSummaryLine(summary, frame.tagText, -6, columnWidth)
	frame.guildText = CreateSummaryLine(summary, frame.factText, -6, columnWidth)
	frame.guidText = CreateSummaryLine(summary, frame.guildText, -6, columnWidth)
	frame.metRealmText = CreateSummaryLine(summary, frame.guidText, -6, columnWidth)

	local communityHeading = W.CreateFontString(summary, nil, "OVERLAY", "GameFontNormal")
	communityHeading:SetPoint("TOPLEFT", columnWidth + columnGap, 0)
	communityHeading:SetWidth(columnWidth)
	communityHeading:SetJustifyH("LEFT")
	W.SetFontColor(communityHeading, UI.GOLD)
	frame.communityHeading = communityHeading

	local communityText = W.CreateFontString(summary, nil, "OVERLAY", "GameFontHighlight")
	communityText:SetPoint("TOPLEFT", communityHeading, "BOTTOMLEFT", 0, -4)
	communityText:SetWidth(columnWidth)
	communityText:SetJustifyH("LEFT")
	communityText:SetJustifyV("TOP")
	frame.communityText = communityText

	-- Tab bar + panels (opinion, facts, events, notes, history).
	local tabBar = CreateFrame("Frame", nil, body)
	tabBar:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)
	tabBar:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -8)
	tabBar:SetHeight(UI.PROFILE_TAB_H)
	frame.tabBar = tabBar

	frame.profileTabButtons = {}
	frame.profilePanels = {}
	local tabGap = 4
	local tabWidth = math.floor((bodyWidth - tabGap * (#PROFILE_TABS - 1)) / #PROFILE_TABS)
	for index = 1, #PROFILE_TABS do
		local tab = PROFILE_TABS[index]
		local button = CreateProfileTabButton(tabBar, tab.id, T(tab.labelKey), tabWidth)
		if index == 1 then
			button:SetPoint("LEFT", 0, 0)
		else
			button:SetPoint("LEFT", frame.profileTabButtons[index - 1], "RIGHT", tabGap, 0)
		end
		frame.profileTabButtons[index] = button
	end

	local tabHost = CreateFrame("Frame", nil, body)
	tabHost:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
	tabHost:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, UI.ACTION_BTN_H + 8)
	frame.tabHost = tabHost

	local updateBtn = W.CreatePlainButton(body, bodyWidth, UI.ACTION_BTN_H, T("BTN_SAVE_AND_UPDATE"))
	updateBtn:SetPoint("BOTTOMLEFT", 0, 0)
	updateBtn:SetPoint("BOTTOMRIGHT", 0, 0)
	updateBtn:SetScript("OnClick", function()
		Addon:CommitProfileRating()
	end)
	frame.ratingUpdateBtn = updateBtn

	local tabContentWidth = bodyWidth
	local tabContent = CreateFrame("Frame", nil, tabHost)
	tabContent:SetPoint("TOPLEFT", 0, 0)
	tabContent:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.tabContent = tabContent

	Addon:CreateProfilePanels(frame, tabContent, tabContentWidth, {
		CreateOpinionRadio = CreateOpinionRadio,
		CreateProfileFactCheckbox = CreateProfileFactCheckbox,
		CreateProfileNotesBox = CreateProfileNotesBox,
		CreateProfileTagCheckbox = CreateProfileTagCheckbox,
		GetRatingTagGroups = GetRatingTagGroups,
		PROFILE_EVENT_GROUP_ICON = PROFILE_EVENT_GROUP_ICON,
		PROFILE_EVENT_PICKER_H = PROFILE_EVENT_PICKER_H,
		PROFILE_EVENT_TYPE_BTN_H = PROFILE_EVENT_TYPE_BTN_H,
		PROFILE_EVENT_TYPE_ROW_H = PROFILE_EVENT_TYPE_ROW_H,
		PROFILE_LAYOUT_VERSION = PROFILE_LAYOUT_VERSION,
		PROFILE_OPINION_HEADER_H = PROFILE_OPINION_HEADER_H,
		PROFILE_OPINION_ROW_H = PROFILE_OPINION_ROW_H,
		PROFILE_TAG_COL_GAP = PROFILE_TAG_COL_GAP,
		PROFILE_TAG_GROUP_GAP = PROFILE_TAG_GROUP_GAP,
		PROFILE_TAG_GROUP_HEADING_H = PROFILE_TAG_GROUP_HEADING_H,
		PROFILE_TAG_ROW_H = PROFILE_TAG_ROW_H,
		ProfileTagGroupHeight = ProfileTagGroupHeight,
		UI = UI,
	})

	frame.selectedProfileTab = "history"

	return frame
end

-- REFACTOR candidate: long populate path + repetitive enable/disable gates for every control group.
function Addon:ShowRaidCharacterWindow(member)
	if not member then
		return
	end

	if self.HistoryProfileForMember then
		member = self:HistoryProfileForMember(member)
	end

	if member.unit and UnitExists(member.unit) and UnitSex then
		member.gender = UnitSex(member.unit)
	end

	if ProfileFrameNeedsRebuild(self.raidDetailFrame) then
		if self.raidDetailFrame then
			self.raidDetailFrame:Hide()
			self.raidDetailFrame:SetParent(nil)
		end
		self.raidDetailFrame = nil
	end

	local frame = self.raidDetailFrame
	if not frame then
		local ok, created = pcall(CreateRaidCharacterWindow)
		if not ok then
			self:Print("Character profile failed to open: " .. tostring(created))
			return
		end
		frame = created
		self.raidDetailFrame = frame
	end

	frame.profileMember = member

	frame.titleText:SetText(T("PROFILE_TITLE", member.name or "?"))
	W.SetSpecOrClassIcon(frame.classIcon, nil, member.class)
	frame.classText:SetText(member.classLabel ~= "" and member.classLabel or "-")
	frame.classText:SetTextColor(W.ClassColor(member.class))

	if member.specIcon and member.specIcon ~= "" then
		W.SetSpecOrClassIcon(frame.specIcon, member.specIcon, member.class)
		frame.specIcon:Show()
	else
		W.SetSpecOrClassIcon(frame.specIcon, nil, member.class)
		frame.specIcon:Show()
	end
	frame.specText:SetText((member.spec and member.spec ~= "") and member.spec or "-")
	W.SetFontColor(frame.specText, UI.TEXT_IDLE)

	if member.gearScore then
		frame.gsText:SetText(T("PROFILE_GS", tostring(member.gearScore)))
		W.SetFontColor(frame.gsText, UI.GOLD)
	else
		frame.gsText:SetText(T("PROFILE_GS", "-"))
		W.SetFontColor(frame.gsText, UI.TEXT_DISABLED)
	end

	if member.averageIlvl then
		frame.ilvlText:SetText(T("PROFILE_ILVL", tostring(member.averageIlvl)))
		W.SetFontColor(frame.ilvlText, UI.TEXT_IDLE)
	else
		frame.ilvlText:SetText(T("PROFILE_ILVL", "-"))
		W.SetFontColor(frame.ilvlText, UI.TEXT_DISABLED)
	end

	if SetProfileRaceIcon(frame.raceIcon, member.race, member.gender) then
		frame.raceIconHost:Show()
		frame.classIconHost:ClearAllPoints()
		frame.classIconHost:SetPoint("LEFT", frame.raceIconHost, "RIGHT", 2, 0)
	else
		frame.raceIconHost:Hide()
		frame.classIconHost:ClearAllPoints()
		frame.classIconHost:SetPoint("TOPLEFT", frame.classCell, "TOPLEFT", 0, 0)
	end

	frame.guildText:SetText(T("PROFILE_GUILD", W.FormatGuildDisplay(member.guildName, member.guildRank)))
	W.SetFontColor(frame.guildText, UI.TEXT_IDLE)

	InitProfileDraft(frame, member)
	PaintSavedHeaderLabels(frame, member)
	PaintDraftEditorLabels(frame)

	if member.guid and member.guid ~= "" then
		frame.guidText:SetText(T("PROFILE_GUID", member.guid))
		W.SetFontColor(frame.guidText, UI.TEXT_IDLE)
	else
		frame.guidText:SetText(T("PROFILE_GUID", "-"))
		W.SetFontColor(frame.guidText, UI.TEXT_DISABLED)
	end

	if member.metRealm and member.metRealm ~= "" then
		frame.metRealmText:SetText(T("PROFILE_REALM", member.metRealm))
		W.SetFontColor(frame.metRealmText, UI.TEXT_IDLE)
	else
		frame.metRealmText:SetText(T("PROFILE_REALM", "-"))
		W.SetFontColor(frame.metRealmText, UI.TEXT_DISABLED)
	end

	if frame.profileTabButtons then
		for index = 1, #PROFILE_TABS do
			local button = frame.profileTabButtons[index]
			local tab = PROFILE_TABS[index]
			if button and button.label and tab then
				button.label:SetText(T(tab.labelKey))
			end
		end
	end

	if frame.tagsHeading then
		frame.tagsHeading:SetText(T("RATING_TAGS_TITLE"))
	end
	if frame.notesHeading then
		frame.notesHeading:SetText(T("PROFILE_NOTES"))
	end
	if frame.notesHint then
		frame.notesHint:SetText(T("PROFILE_MEMO_HINT"))
	end
	if frame.notesBox then
		frame.isUpdatingNotes = true
		frame.notesBox:SetText(member.notes or "")
		frame.isUpdatingNotes = false
	end
	if frame.ratingUpdateBtn then
		frame.ratingUpdateBtn.label:SetText(T("BTN_SAVE_AND_UPDATE"))
	end

	UpdateProfileEditor(frame, member)
	local editable = member.guid and member.guid ~= ""
	local draftOpinion = GetProfileDraft(frame)
	if frame.opinionButtons then
		for _, button in ipairs(frame.opinionButtons) do
			if editable then
				button:Enable()
				if button.hit then
					button.hit:Enable()
				end
			else
				button:Disable()
				if button.hit then
					button.hit:Disable()
				end
			end
		end
		RefreshOpinionRadios(frame, draftOpinion)
	end
	if frame.tagGroups then
		RefreshProfileTagCheckboxes(frame, member, editable)
	end
	if frame.factCheckboxes then
		RefreshProfileFactCheckboxes(frame, member, editable)
	end
	if frame.eventsAddBtn then
		if editable then
			frame.eventsAddBtn:Enable()
		else
			frame.eventsAddBtn:Disable()
		end
	end
	if frame.eventTypeButtons then
		for _, button in ipairs(frame.eventTypeButtons) do
			if editable then
				button:Enable()
			else
				button:Disable()
			end
		end
	end
	if frame.ratingUpdateBtn then
		if editable then
			frame.ratingUpdateBtn:Enable()
		else
			frame.ratingUpdateBtn:Disable()
		end
	end
	if frame.notesBox and frame.notesHost then
		if editable then
			frame.notesBox:EnableMouse(true)
			frame.notesBox:EnableKeyboard(true)
			W.SetFontColor(frame.notesBox, Theme.TEXT_BODY)
			frame.notesHost:SetAlpha(1)
		else
			frame.notesBox:ClearFocus()
			frame.notesBox:EnableMouse(false)
			frame.notesBox:EnableKeyboard(false)
			W.SetFontColor(frame.notesBox, Theme.TEXT_DISABLED)
			frame.notesHost:SetAlpha(0.6)
		end
	end
	if frame.notesSaveBtn then
		frame.notesSaveBtn.label:SetText(T("BTN_SAVE"))
		if editable then
			frame.notesSaveBtn:Enable()
		else
			frame.notesSaveBtn:Disable()
		end
	end
	if frame.notesResetBtn then
		frame.notesResetBtn.label:SetText(T("BTN_RESET"))
		if editable then
			frame.notesResetBtn:Enable()
		else
			frame.notesResetBtn:Disable()
		end
	end
	frame.selectedProfileTab = "history"
	self:SelectProfileTab("history")

	frame:Show()
	frame:Raise()
end
