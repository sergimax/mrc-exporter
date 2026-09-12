-- Profile tab construction; commands and rendering remain in CharacterProfile.
local Addon = Raidwise
local W = Addon.Widgets
local function T(key, ...) return W.T(key, ...) end

function Addon:CreateProfilePanels(frame, tabContent, tabContentWidth, controls)
	local CreateOpinionRadio = controls.CreateOpinionRadio
	local CreateProfileFactCheckbox = controls.CreateProfileFactCheckbox
	local CreateProfileNotesBox = controls.CreateProfileNotesBox
	local CreateProfileTagCheckbox = controls.CreateProfileTagCheckbox
	local GetRatingTagGroups = controls.GetRatingTagGroups
	local PROFILE_EVENT_GROUP_ICON = controls.PROFILE_EVENT_GROUP_ICON
	local PROFILE_EVENT_PICKER_H = controls.PROFILE_EVENT_PICKER_H
	local PROFILE_EVENT_TYPE_BTN_H = controls.PROFILE_EVENT_TYPE_BTN_H
	local PROFILE_EVENT_TYPE_ROW_H = controls.PROFILE_EVENT_TYPE_ROW_H
	local PROFILE_LAYOUT_VERSION = controls.PROFILE_LAYOUT_VERSION
	local PROFILE_OPINION_HEADER_H = controls.PROFILE_OPINION_HEADER_H
	local PROFILE_OPINION_ROW_H = controls.PROFILE_OPINION_ROW_H
	local PROFILE_TAG_COL_GAP = controls.PROFILE_TAG_COL_GAP
	local PROFILE_TAG_GROUP_GAP = controls.PROFILE_TAG_GROUP_GAP
	local PROFILE_TAG_GROUP_HEADING_H = controls.PROFILE_TAG_GROUP_HEADING_H
	local PROFILE_TAG_ROW_H = controls.PROFILE_TAG_ROW_H
	local ProfileTagGroupHeight = controls.ProfileTagGroupHeight
	local UI = controls.UI

	local function CreateProfileOpinionPanel(frame, tabContent, tabContentWidth)
		local opinionPanel = CreateFrame("Frame", nil, tabContent)
		opinionPanel:SetPoint("TOPLEFT", 0, 0)
		opinionPanel:SetPoint("BOTTOMRIGHT", 0, 0)
		frame.profilePanels.opinion = opinionPanel

		-- Solid header above the tag list (radios here; scroll never covers them).
		local opinionHeader = CreateFrame("Frame", nil, opinionPanel)
		opinionHeader:SetPoint("TOPLEFT", 0, 0)
		opinionHeader:SetPoint("TOPRIGHT", 0, 0)
		opinionHeader:SetHeight(PROFILE_OPINION_HEADER_H)
		opinionHeader:EnableMouse(true)
		opinionHeader:SetFrameLevel(opinionPanel:GetFrameLevel() + 40)
		frame.opinionHeader = opinionHeader

		local summaryLine = W.CreateFontString(opinionHeader, nil, "OVERLAY", "GameFontNormalSmall")
		summaryLine:SetPoint("TOPLEFT", 0, 0)
		summaryLine:SetPoint("RIGHT", opinionHeader, "RIGHT", 0, 0)
		summaryLine:SetHeight(16)
		summaryLine:SetJustifyH("LEFT")
		summaryLine:SetJustifyV("MIDDLE")
		frame.ratingSummary = summaryLine

		-- Mutually exclusive radios (AceConfigDialog style="radio" / Details RadioOnClick).
		local opinionRow = CreateFrame("Frame", nil, opinionHeader)
		opinionRow:SetPoint("TOPLEFT", summaryLine, "BOTTOMLEFT", 0, -6)
		opinionRow:SetPoint("TOPRIGHT", summaryLine, "BOTTOMRIGHT", 0, -6)
		opinionRow:SetHeight(PROFILE_OPINION_ROW_H)
		frame.opinionRow = opinionRow

		frame.opinionButtons = {}
		local opinionOrder = { "positive", "neutral", "negative" }
		local opinionWidth = math.floor((tabContentWidth - UI.ACTION_BTN_GAP * 2) / 3)
		for index = 1, #opinionOrder do
			local opinionId = opinionOrder[index]
			local radio = CreateOpinionRadio(opinionRow, opinionId, opinionWidth)
			if index == 1 then
				radio.host:SetPoint("LEFT", opinionRow, "LEFT", 0, 0)
			else
				radio.host:SetPoint("LEFT", frame.opinionButtons[index - 1].host, "RIGHT", UI.ACTION_BTN_GAP, 0)
			end
			frame.opinionButtons[index] = radio
		end

		local tagsHeading = W.CreateFontString(opinionHeader, nil, "OVERLAY", "GameFontNormal")
		tagsHeading:SetPoint("TOPLEFT", opinionRow, "BOTTOMLEFT", 0, -6)
		tagsHeading:SetPoint("RIGHT", opinionHeader, "RIGHT", 0, 0)
		tagsHeading:SetJustifyH("LEFT")
		tagsHeading:SetText(T("RATING_TAGS_TITLE"))
		W.SetFontColor(tagsHeading, UI.GOLD)
		frame.tagsHeading = tagsHeading

		frame.profileTabContentWidth = tabContentWidth
		frame.tagGroups = {}

		-- Tag list starts strictly below the mouse-blocking header.
		local tagBody = CreateFrame("Frame", nil, opinionPanel)
		tagBody:SetPoint("TOPLEFT", opinionHeader, "BOTTOMLEFT", 0, -2)
		tagBody:SetPoint("BOTTOMRIGHT", opinionPanel, "BOTTOMRIGHT", 0, 0)
		tagBody:SetFrameLevel(opinionPanel:GetFrameLevel() + 1)
		frame.tagBody = tagBody

		local tagScrollName = "RaidwiseProfileTagScrollV" .. tostring(PROFILE_LAYOUT_VERSION)
		local existingScroll = _G[tagScrollName]
		if existingScroll then
			existingScroll:Hide()
			existingScroll:EnableMouse(false)
			existingScroll:SetParent(nil)
		end
		local tagScroll = CreateFrame("ScrollFrame", tagScrollName, tagBody, "UIPanelScrollFrameTemplate")
		tagScroll:SetPoint("TOPLEFT", 0, 0)
		tagScroll:SetPoint("BOTTOMRIGHT", -24, 0)
		frame.tagScroll = tagScroll

		local tagScrollBar = _G[tagScrollName .. "ScrollBar"]
		if tagScrollBar then
			tagScrollBar:ClearAllPoints()
			tagScrollBar:SetPoint("TOPLEFT", tagBody, "TOPRIGHT", -20, -16)
			tagScrollBar:SetPoint("BOTTOMLEFT", tagBody, "BOTTOMRIGHT", -20, 16)
		end

		local tagContent = CreateFrame("Frame", nil, tagScroll)
		tagContent:SetWidth(tabContentWidth - 28)
		tagScroll:SetScrollChild(tagContent)
		frame.tagContent = tagContent

		local currentY = 0
		local groups = GetRatingTagGroups()
		local columnWidth = math.floor((tabContentWidth - PROFILE_TAG_COL_GAP - 28) / 2)
		for groupIndex = 1, #groups do
			local group = groups[groupIndex]
			local label = W.CreateFontString(tagContent, nil, "OVERLAY", "GameFontNormalSmall")
			label:SetPoint("TOPLEFT", tagContent, "TOPLEFT", 0, -currentY)
			label:SetPoint("RIGHT", tagContent, "RIGHT", 0, 0)
			label:SetJustifyH("LEFT")
			W.SetFontColor(label, UI.TEXT_HOVER)
			label:SetText(T(group.labelKey))

			local checkboxes = {}
			local leftColumn = CreateFrame("Frame", nil, tagContent)
			leftColumn:SetSize(columnWidth, 1)
			leftColumn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)

			local rightColumn = CreateFrame("Frame", nil, tagContent)
			rightColumn:SetSize(columnWidth, 1)
			rightColumn:SetPoint("TOPLEFT", leftColumn, "TOPRIGHT", PROFILE_TAG_COL_GAP, 0)

			for tagIndex = 1, #group.tags do
				local tag = group.tags[tagIndex]
				local column = (tagIndex % 2 == 0) and rightColumn or leftColumn
				local rowIndex = math.floor((tagIndex - 1) / 2)
				local checkbox = CreateProfileTagCheckbox(column, tag, group, columnWidth)
				checkbox:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -(rowIndex * PROFILE_TAG_ROW_H))
				checkboxes[#checkboxes + 1] = checkbox
			end

			local rows = math.ceil(#group.tags / 2)
			local columnHeight = rows * PROFILE_TAG_ROW_H
			leftColumn:SetHeight(columnHeight)
			rightColumn:SetHeight(columnHeight)

			frame.tagGroups[#frame.tagGroups + 1] = {
				group = group,
				label = label,
				leftColumn = leftColumn,
				rightColumn = rightColumn,
				checkboxes = checkboxes,
			}
			currentY = currentY + ProfileTagGroupHeight(#group.tags)
		end
		tagContent:SetHeight(math.max(currentY, 1))

		-- Facts tab: role / identity checkboxes (draft until Save and Update).
	end

	local function CreateProfileFactsPanel(frame, tabContent, tabContentWidth)
		local factsPanel = CreateFrame("Frame", nil, tabContent)
		factsPanel:SetPoint("TOPLEFT", 0, 0)
		factsPanel:SetPoint("BOTTOMRIGHT", 0, 0)
		factsPanel:Hide()
		frame.profilePanels.facts = factsPanel

		local factsHeading = W.CreateFontString(factsPanel, nil, "OVERLAY", "GameFontNormal")
		factsHeading:SetPoint("TOPLEFT", 0, 0)
		factsHeading:SetPoint("RIGHT", factsPanel, "RIGHT", 0, 0)
		factsHeading:SetJustifyH("LEFT")
		factsHeading:SetText(T("RATING_FACTS_TITLE"))
		W.SetFontColor(factsHeading, UI.GOLD)
		frame.factsHeading = factsHeading

		local factsHint = W.CreateFontString(factsPanel, nil, "OVERLAY", "GameFontNormalSmall")
		factsHint:SetPoint("TOPLEFT", factsHeading, "BOTTOMLEFT", 0, -4)
		factsHint:SetPoint("RIGHT", factsPanel, "RIGHT", 0, 0)
		factsHint:SetJustifyH("LEFT")
		local maxFacts = (Addon.MaxPersonalFacts and Addon:MaxPersonalFacts()) or 4
		factsHint:SetText(T("RATING_FACTS_HINT", maxFacts))
		W.SetFontColor(factsHint, UI.TEXT_IDLE)
		frame.factsHint = factsHint

		frame.factCheckboxes = {}
		local factCatalog = (Addon.FactCatalog and Addon:FactCatalog()) or {}
		local factColumnWidth = math.floor((tabContentWidth - PROFILE_TAG_COL_GAP) / 2)
		local factLeft = CreateFrame("Frame", nil, factsPanel)
		factLeft:SetSize(factColumnWidth, 1)
		factLeft:SetPoint("TOPLEFT", factsHint, "BOTTOMLEFT", 0, -8)
		local factRight = CreateFrame("Frame", nil, factsPanel)
		factRight:SetSize(factColumnWidth, 1)
		factRight:SetPoint("TOPLEFT", factLeft, "TOPRIGHT", PROFILE_TAG_COL_GAP, 0)
		for factIndex = 1, #factCatalog do
			local fact = factCatalog[factIndex]
			local column = (factIndex % 2 == 0) and factRight or factLeft
			local rowIndex = math.floor((factIndex - 1) / 2)
			local checkbox = CreateProfileFactCheckbox(column, fact, factColumnWidth)
			checkbox:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -(rowIndex * PROFILE_TAG_ROW_H))
			frame.factCheckboxes[#frame.factCheckboxes + 1] = checkbox
		end
		local factRows = math.ceil(math.max(#factCatalog, 1) / 2)
		factLeft:SetHeight(factRows * PROFILE_TAG_ROW_H)
		factRight:SetHeight(factRows * PROFILE_TAG_ROW_H)

		-- Events tab: pick type + draft Add/Remove; commit via Save and Update.
	end

	local function CreateProfileEventsPanel(frame, tabContent, tabContentWidth)
		local eventsPanel = CreateFrame("Frame", nil, tabContent)
		eventsPanel:SetPoint("TOPLEFT", 0, 0)
		eventsPanel:SetPoint("BOTTOMRIGHT", 0, 0)
		eventsPanel:Hide()
		frame.profilePanels.events = eventsPanel

		local eventsAddBtn = W.CreatePlainButton(eventsPanel, 110, UI.ACTION_BTN_H, T("PROFILE_EVENTS_ADD"))
		eventsAddBtn:SetPoint("TOPRIGHT", 0, 0)
		eventsAddBtn:SetScript("OnClick", function()
			if frame.selectedEventType then
				Addon:AddProfileEvent(frame.selectedEventType)
			end
		end)
		frame.eventsAddBtn = eventsAddBtn

		local eventsHeading = W.CreateFontString(eventsPanel, nil, "OVERLAY", "GameFontNormal")
		eventsHeading:SetPoint("TOPLEFT", 0, 0)
		eventsHeading:SetPoint("RIGHT", eventsAddBtn, "LEFT", -8, 0)
		eventsHeading:SetJustifyH("LEFT")
		eventsHeading:SetText(T("PROFILE_TAB_EVENTS"))
		W.SetFontColor(eventsHeading, UI.GOLD)
		frame.eventsHeading = eventsHeading

		local eventsPickLabel = W.CreateFontString(eventsPanel, nil, "OVERLAY", "GameFontNormalSmall")
		eventsPickLabel:SetPoint("TOPLEFT", eventsHeading, "BOTTOMLEFT", 0, -4)
		eventsPickLabel:SetPoint("RIGHT", eventsPanel, "RIGHT", 0, 0)
		eventsPickLabel:SetJustifyH("LEFT")
		eventsPickLabel:SetText(T("PROFILE_EVENTS_PICK_TYPE"))
		W.SetFontColor(eventsPickLabel, UI.TEXT_IDLE)
		frame.eventsPickLabel = eventsPickLabel

		local typePickerHost = CreateFrame("Frame", nil, eventsPanel)
		typePickerHost:SetPoint("TOPLEFT", eventsPickLabel, "BOTTOMLEFT", 0, -6)
		typePickerHost:SetPoint("RIGHT", eventsPanel, "RIGHT", 0, 0)
		typePickerHost:SetHeight(PROFILE_EVENT_PICKER_H)
		frame.eventTypePickerHost = typePickerHost

		local typeScrollName = "RaidwiseProfileEventTypeScrollV" .. tostring(PROFILE_LAYOUT_VERSION)
		local existingTypeScroll = _G[typeScrollName]
		if existingTypeScroll then
			existingTypeScroll:Hide()
			existingTypeScroll:SetParent(nil)
		end
		local typeScroll = CreateFrame("ScrollFrame", typeScrollName, typePickerHost, "UIPanelScrollFrameTemplate")
		typeScroll:SetPoint("TOPLEFT", 0, 0)
		typeScroll:SetPoint("BOTTOMRIGHT", -24, 0)

		local typeContent = CreateFrame("Frame", nil, typeScroll)
		typeContent:SetWidth(tabContentWidth - 28)
		typeScroll:SetScrollChild(typeContent)
		frame.eventTypeButtons = {}
		frame.eventTypeGroupLabels = {}
		frame.selectedEventType = nil
		local eventGroups = (Addon.EventTypeGroups and Addon:EventTypeGroups()) or {}
		local typeBtnWidth = math.floor((tabContentWidth - 28 - PROFILE_TAG_COL_GAP) / 2)
		local typeY = 0
		local function SelectEventType(eventTypeId)
			frame.selectedEventType = eventTypeId
			for _, other in ipairs(frame.eventTypeButtons) do
				W.SetMenuButtonState(other, other.eventTypeId == frame.selectedEventType, false)
			end
		end
		for groupIndex = 1, #eventGroups do
			local group = eventGroups[groupIndex]
			if groupIndex > 1 then
				typeY = typeY + PROFILE_TAG_GROUP_GAP
			end
			local icon = typeContent:CreateTexture(nil, "ARTWORK")
			icon:SetSize(PROFILE_EVENT_GROUP_ICON, PROFILE_EVENT_GROUP_ICON)
			icon:SetPoint("TOPLEFT", typeContent, "TOPLEFT", 0, -typeY)
			if group.icon then
				W.SetSpellIconTexture(icon, group.icon)
			end

			local heading = W.CreateFontString(typeContent, nil, "OVERLAY", "GameFontNormalSmall")
			heading:SetPoint("LEFT", icon, "RIGHT", 4, 0)
			heading:SetPoint("RIGHT", typeContent, "RIGHT", 0, 0)
			heading:SetPoint("TOP", icon, "TOP", 0, 1)
			heading:SetHeight(PROFILE_TAG_GROUP_HEADING_H)
			heading:SetJustifyH("LEFT")
			heading:SetJustifyV("MIDDLE")
			heading:SetText(T(group.labelKey))
			W.SetFontColor(heading, UI.GOLD)
			heading.labelKey = group.labelKey
			frame.eventTypeGroupLabels[#frame.eventTypeGroupLabels + 1] = heading
			typeY = typeY + math.max(PROFILE_EVENT_GROUP_ICON, PROFILE_TAG_GROUP_HEADING_H) + 2

			local types = group.events or {}
			for typeIndex = 1, #types do
				local eventType = types[typeIndex]
				local col = (typeIndex % 2 == 0) and 1 or 0
				local row = math.floor((typeIndex - 1) / 2)
				local button = CreateFrame("Button", nil, typeContent)
				button:SetSize(typeBtnWidth, PROFILE_EVENT_TYPE_BTN_H)
				button:SetPoint(
					"TOPLEFT",
					typeContent,
					"TOPLEFT",
					col * (typeBtnWidth + PROFILE_TAG_COL_GAP),
					-(typeY + row * PROFILE_EVENT_TYPE_ROW_H)
				)
				W.ApplyPlainPanel(button, UI.BTN_IDLE)
				button.eventTypeId = eventType.id
				local label = W.CreateFontString(button, nil, "OVERLAY", "GameFontNormalSmall")
				label:SetPoint("LEFT", 6, 0)
				label:SetPoint("RIGHT", -6, 0)
				label:SetJustifyH("LEFT")
				label:SetText(Addon.EventTypeLabel and Addon:EventTypeLabel(eventType.id) or eventType.id)
				button.label = label
				button:SetScript("OnEnter", function(self)
					W.SetMenuButtonState(self, frame.selectedEventType == self.eventTypeId, true)
				end)
				button:SetScript("OnLeave", function(self)
					W.SetMenuButtonState(self, frame.selectedEventType == self.eventTypeId, false)
				end)
				button:SetScript("OnClick", function(self)
					SelectEventType(self.eventTypeId)
				end)
				frame.eventTypeButtons[#frame.eventTypeButtons + 1] = button
			end
			local rows = math.ceil(math.max(#types, 1) / 2)
			typeY = typeY + rows * PROFILE_EVENT_TYPE_ROW_H
		end
		typeContent:SetHeight(math.max(typeY, 1))
		if #frame.eventTypeButtons > 0 then
			SelectEventType(frame.eventTypeButtons[1].eventTypeId)
		end

		local eventsListHost = CreateFrame("Frame", nil, eventsPanel)
		eventsListHost:SetPoint("TOPLEFT", typePickerHost, "BOTTOMLEFT", 0, -8)
		eventsListHost:SetPoint("BOTTOMRIGHT", eventsPanel, "BOTTOMRIGHT", 0, 0)
		frame.eventsListHost = eventsListHost

		local eventsListScrollName = "RaidwiseProfileEventListScrollV" .. tostring(PROFILE_LAYOUT_VERSION)
		local existingEventListScroll = _G[eventsListScrollName]
		if existingEventListScroll then
			existingEventListScroll:Hide()
			existingEventListScroll:SetParent(nil)
		end
		local eventsListScroll = CreateFrame("ScrollFrame", eventsListScrollName, eventsListHost, "UIPanelScrollFrameTemplate")
		eventsListScroll:SetPoint("TOPLEFT", 0, 0)
		eventsListScroll:SetPoint("BOTTOMRIGHT", -24, 0)
		frame.eventsListScroll = eventsListScroll

		local eventsListContent = CreateFrame("Frame", nil, eventsListScroll)
		eventsListContent:SetWidth(tabContentWidth - 28)
		eventsListScroll:SetScrollChild(eventsListContent)
		frame.eventsListContent = eventsListContent
		frame.eventRows = {}
		frame.eventRemoveButtons = {}

	end

	local function CreateProfileNotesPanel(frame, tabContent, tabContentWidth)
		local notesPanel = CreateFrame("Frame", nil, tabContent)
		notesPanel:SetPoint("TOPLEFT", 0, 0)
		notesPanel:SetPoint("TOPRIGHT", 0, 0)
		notesPanel:SetHeight(190)
		notesPanel:Hide()
		frame.profilePanels.notes = notesPanel

		local notesHeading = W.CreateFontString(notesPanel, nil, "OVERLAY", "GameFontNormal")
		notesHeading:SetPoint("TOPLEFT", 0, 0)
		notesHeading:SetPoint("RIGHT", notesPanel, "RIGHT", 0, 0)
		notesHeading:SetJustifyH("LEFT")
		notesHeading:SetText(T("PROFILE_NOTES"))
		W.SetFontColor(notesHeading, UI.GOLD)
		frame.notesHeading = notesHeading

		local notesHint = W.CreateFontString(notesPanel, nil, "OVERLAY", "GameFontNormalSmall")
		notesHint:SetPoint("TOPLEFT", notesHeading, "BOTTOMLEFT", 0, -4)
		notesHint:SetPoint("RIGHT", notesPanel, "RIGHT", 0, 0)
		notesHint:SetJustifyH("LEFT")
		notesHint:SetJustifyV("TOP")
		notesHint:SetText(T("PROFILE_MEMO_HINT"))
		W.SetFontColor(notesHint, UI.TEXT_IDLE)
		frame.notesHint = notesHint

		local notesHost, notesBox = CreateProfileNotesBox(notesPanel, tabContentWidth, 96)
		notesHost:SetPoint("TOPLEFT", notesHint, "BOTTOMLEFT", 0, -8)
		frame.notesHost = notesHost
		frame.notesBox = notesBox

		local notesButtonWidth = math.floor((tabContentWidth - UI.ACTION_BTN_GAP) / 2)
		local notesSaveBtn = W.CreatePlainButton(notesPanel, notesButtonWidth, UI.ACTION_BTN_H, T("BTN_SAVE"))
		notesSaveBtn:SetPoint("TOPLEFT", notesHost, "BOTTOMLEFT", 0, -8)
		notesSaveBtn:SetScript("OnClick", function()
			if frame.notesBox then
				frame.notesBox:ClearFocus()
				Addon:SaveProfileNotes(frame.notesBox:GetText() or "")
			end
		end)
		frame.notesSaveBtn = notesSaveBtn

		local notesResetBtn = W.CreatePlainButton(notesPanel, notesButtonWidth, UI.ACTION_BTN_H, T("BTN_RESET"))
		notesResetBtn:SetPoint("LEFT", notesSaveBtn, "RIGHT", UI.ACTION_BTN_GAP, 0)
		notesResetBtn:SetScript("OnClick", function()
			Addon:ResetProfileNotes()
		end)
		frame.notesResetBtn = notesResetBtn

	end

	local function CreateProfileHistoryPanel(frame, tabContent, tabContentWidth)
		local historyPanel = CreateFrame("Frame", nil, tabContent)
		historyPanel:SetPoint("TOPLEFT", 0, 0)
		historyPanel:SetPoint("BOTTOMRIGHT", 0, 0)
		historyPanel:Hide()
		frame.profilePanels.history = historyPanel

		local historyTogetherText = W.CreateFontString(historyPanel, nil, "OVERLAY", "GameFontHighlight")
		historyTogetherText:SetPoint("TOPRIGHT", 0, 0)
		historyTogetherText:SetJustifyH("RIGHT")
		historyTogetherText:SetJustifyV("TOP")
		frame.historyTogetherText = historyTogetherText

		local historyMetText = W.CreateFontString(historyPanel, nil, "OVERLAY", "GameFontHighlight")
		historyMetText:SetPoint("TOPLEFT", 0, 0)
		historyMetText:SetPoint("RIGHT", historyTogetherText, "LEFT", -8, 0)
		historyMetText:SetJustifyH("LEFT")
		historyMetText:SetJustifyV("TOP")
		frame.historyMetText = historyMetText

		local historyWhenText = W.CreateFontString(historyPanel, nil, "OVERLAY", "GameFontHighlight")
		historyWhenText:SetPoint("TOPLEFT", historyMetText, "BOTTOMLEFT", 0, -6)
		historyWhenText:SetPoint("RIGHT", historyPanel, "RIGHT", 0, 0)
		historyWhenText:SetJustifyH("LEFT")
		historyWhenText:SetJustifyV("TOP")
		frame.historyWhenText = historyWhenText

		local historyListHost = CreateFrame("Frame", nil, historyPanel)
		historyListHost:SetPoint("TOPLEFT", historyWhenText, "BOTTOMLEFT", 0, -8)
		historyListHost:SetPoint("BOTTOMRIGHT", historyPanel, "BOTTOMRIGHT", 0, 0)
		frame.historyListHost = historyListHost

		local historyScrollName = "RaidwiseProfileHistoryScrollV" .. tostring(PROFILE_LAYOUT_VERSION)
		local existingHistoryScroll = _G[historyScrollName]
		if existingHistoryScroll then
			existingHistoryScroll:Hide()
			existingHistoryScroll:SetParent(nil)
		end
		local historyScroll = CreateFrame("ScrollFrame", historyScrollName, historyListHost, "UIPanelScrollFrameTemplate")
		historyScroll:SetPoint("TOPLEFT", 0, 0)
		historyScroll:SetPoint("BOTTOMRIGHT", -24, 0)
		frame.historyListScroll = historyScroll

		local historyListContent = CreateFrame("Frame", nil, historyScroll)
		historyListContent:SetWidth(tabContentWidth - 28)
		historyScroll:SetScrollChild(historyListContent)
		frame.historyListContent = historyListContent
		frame.historyRows = {}

	end

	CreateProfileOpinionPanel(frame, tabContent, tabContentWidth)
	CreateProfileFactsPanel(frame, tabContent, tabContentWidth)
	CreateProfileEventsPanel(frame, tabContent, tabContentWidth)
	CreateProfileNotesPanel(frame, tabContent, tabContentWidth)
	CreateProfileHistoryPanel(frame, tabContent, tabContentWidth)
end

local function FormatProfileChangeDetail(change)
	if type(change) ~= "table" then
		return "?"
	end
	if change.kind == "opinion" then
		return T("PROFILE_CHANGE_OPINION", Addon:RatingOpinionLabel(change.detail))
	end
	if change.kind == "tags" then
		local detail = change.detail
		if type(detail) ~= "string" or detail == "" then
			detail = T("RATING_TAGS_NONE")
		end
		return T("PROFILE_CHANGE_TAGS", detail)
	end
	if change.kind == "facts" then
		local detail = change.detail
		if type(detail) ~= "string" or detail == "" then
			detail = T("RATING_FACTS_NONE")
		end
		return T("PROFILE_CHANGE_FACTS", detail)
	end
	if change.kind == "event_add" then
		local label = change.detail
		if Addon.EventTypeDisplayLabel then
			label = Addon:EventTypeDisplayLabel(change.detail)
		elseif Addon.EventTypeLabel then
			label = Addon:EventTypeLabel(change.detail)
		end
		return T("PROFILE_CHANGE_EVENT_ADD", label)
	end
	if change.kind == "event_remove" then
		local label = change.detail
		if Addon.EventTypeDisplayLabel then
			label = Addon:EventTypeDisplayLabel(change.detail)
		elseif Addon.EventTypeLabel then
			label = Addon:EventTypeLabel(change.detail)
		end
		return T("PROFILE_CHANGE_EVENT_REMOVE", label)
	end
	if change.kind == "notes" then
		-- Legacy change-log rows only; notes saves no longer append history entries.
		return T("PROFILE_CHANGE_NOTES")
	end
	return change.detail or "?"
end

function Addon:RefreshProfileHistoryPanel(frame, member, iconSize)
	if not frame or not member then
		return
	end
	local metZone = (member.metZone and member.metZone ~= "") and member.metZone or "-"
	local meetCount = tonumber(member.meetCount) or 0
	if meetCount < 1 and member.metAt and tonumber(member.metAt) and tonumber(member.metAt) > 0 then
		meetCount = 1
	end
	if frame.historyTogetherText then
		frame.historyTogetherText:SetText(T("PROFILE_TOGETHER", meetCount))
	end
	if frame.historyMetText then
		frame.historyMetText:SetText(T("PROFILE_MET", metZone))
	end
	local metWhen = "-"
	if Addon.FormatHistoryTime and member.metAt then
		metWhen = Addon:FormatHistoryTime(member.metAt) or "-"
	end
	if frame.historyWhenText then
		frame.historyWhenText:SetText(T("PROFILE_WHEN", metWhen))
	end
	if not frame.historyListContent then
		return
	end

	if frame.historyRows then
		for _, row in ipairs(frame.historyRows) do
			row:Hide()
			row:SetParent(nil)
		end
	end
	frame.historyRows = {}

	local rowHeight = 20
	local contentWidth = frame.historyListContent:GetWidth() or 400
	local y = 0
	local changes = member.changes
	local function AddHistoryRow(text, iconPath)
		local row = CreateFrame("Frame", nil, frame.historyListContent)
		row:SetSize(contentWidth, rowHeight)
		row:SetPoint("TOPLEFT", frame.historyListContent, "TOPLEFT", 0, -y)

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", 0, 0)
		local label = W.CreateFontString(row, nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		if iconPath then
			W.SetSpellIconTexture(icon, iconPath)
			icon:Show()
			label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		else
			icon:Hide()
			label:SetPoint("LEFT", 0, 0)
		end
		label:SetText(text)
		row.icon = icon
		row.label = label
		frame.historyRows[#frame.historyRows + 1] = row
		y = y + rowHeight
	end

	if type(changes) ~= "table" or #changes == 0 then
		AddHistoryRow(T("PROFILE_HISTORY_EMPTY"), nil)
	else
		for index = #changes, 1, -1 do
			local change = changes[index]
			local when = Addon.FormatHistoryTime and Addon:FormatHistoryTime(change.at) or "?"
			local iconPath = Addon.ProfileHistoryChangeIcon and Addon:ProfileHistoryChangeIcon(change)
			AddHistoryRow(when .. " — " .. FormatProfileChangeDetail(change), iconPath)
		end
	end
	frame.historyListContent:SetHeight(math.max(y, 1))
end

