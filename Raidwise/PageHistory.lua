-- PageHistory

local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

Addon.Pages = Addon.Pages or {}

local LAYOUT_VERSION = 1

local HISTORY_COL_NAME = 90
local HISTORY_COL_CLASS = 28
local HISTORY_COL_SPEC = 28
local HISTORY_COL_OPINION = 70
local HISTORY_COL_TAGS = 120
local HISTORY_COL_GS = 52
local HISTORY_COL_ILVL = 44
local HISTORY_COL_ZONE = 140
local HISTORY_COL_MET = 130
local HISTORY_COL_GUILD = 120

local function HistoryTableWidth()
	return HISTORY_COL_NAME + HISTORY_COL_CLASS + HISTORY_COL_SPEC + HISTORY_COL_OPINION
		+ HISTORY_COL_TAGS + HISTORY_COL_GS + HISTORY_COL_ILVL + HISTORY_COL_ZONE
		+ HISTORY_COL_MET + HISTORY_COL_GUILD
end

local HISTORY_COLUMN_WIDTHS = {
	HISTORY_COL_NAME,
	HISTORY_COL_CLASS,
	HISTORY_COL_SPEC,
	HISTORY_COL_OPINION,
	HISTORY_COL_TAGS,
	HISTORY_COL_GS,
	HISTORY_COL_ILVL,
	HISTORY_COL_ZONE,
	HISTORY_COL_MET,
	HISTORY_COL_GUILD,
}

local function HistoryColumnOffset(index)
	local offset = 0
	for columnIndex = 1, index - 1 do
		offset = offset + HISTORY_COLUMN_WIDTHS[columnIndex]
	end
	return offset
end

-- REFACTOR candidate: same column pattern as History CreateHistoryRow (no buff column).
local function CreateHistoryRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(UI.CD_ROW_H)
	W.ApplyPlainPanel(row, UI.CD_ROW_A)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")

	local function AddTextColumn(index, justify, insetLeft)
		local text = W.CreateFontString(row, nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("TOPLEFT", row, "TOPLEFT", HistoryColumnOffset(index) + (insetLeft or 4), -4)
		text:SetWidth(HISTORY_COLUMN_WIDTHS[index] - (insetLeft or 4) - 4)
		text:SetJustifyH(justify or "LEFT")
		text:SetJustifyV("TOP")
		return text
	end

	row.nameText = AddTextColumn(1, "LEFT")

	row.classIconHost = CreateFrame("Frame", nil, row)
	row.classIconHost:SetSize(UI.ROSTER_ICON, UI.ROSTER_ICON)
	row.classIconHost:SetPoint(
		"TOPLEFT",
		row,
		"TOPLEFT",
		HistoryColumnOffset(2) + W.TableIconInset(HISTORY_COL_CLASS, UI.ROSTER_ICON),
		W.TableIconTopOffset(UI.ROSTER_ICON)
	)
	row.classIcon = row.classIconHost:CreateTexture(nil, "ARTWORK")
	row.classIcon:SetAllPoints(row.classIconHost)

	row.specIconHost = CreateFrame("Frame", nil, row)
	row.specIconHost:SetSize(UI.ROSTER_ICON, UI.ROSTER_ICON)
	row.specIconHost:SetPoint(
		"TOPLEFT",
		row,
		"TOPLEFT",
		HistoryColumnOffset(3) + W.TableIconInset(HISTORY_COL_SPEC, UI.ROSTER_ICON),
		W.TableIconTopOffset(UI.ROSTER_ICON)
	)
	row.specIcon = row.specIconHost:CreateTexture(nil, "ARTWORK")
	row.specIcon:SetAllPoints(row.specIconHost)

	row.opinionText = AddTextColumn(4, "CENTER")
	row.tagText = AddTextColumn(5, "LEFT")
	row.gsText = AddTextColumn(6, "CENTER")
	row.ilvlText = AddTextColumn(7, "CENTER")
	row.zoneText = AddTextColumn(8, "LEFT")
	row.metText = AddTextColumn(9, "LEFT")
	row.guildText = AddTextColumn(10, "LEFT")

	row.classIconHost:EnableMouse(true)
	row.classIconHost:SetScript("OnEnter", function(self)
		if not row.classLabel or row.classLabel == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(row.classLabel)
		GameTooltip:Show()
	end)
	row.classIconHost:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row.specIconHost:EnableMouse(true)
	row.specIconHost:SetScript("OnEnter", function(self)
		if not row.specLabel or row.specLabel == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(row.specLabel)
		GameTooltip:Show()
	end)
	row.specIconHost:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row:SetScript("OnEnter", function(self)
		W.SetBackdropColor(self, UI.BTN_HOVER)
		W.ShowMemberRatingTooltip(self, self.member)
	end)
	row:SetScript("OnLeave", function(self)
		local stripe = self.stripe or UI.CD_ROW_A
		W.SetBackdropColor(self, stripe)
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(self)
		if self.member then
			Addon:ShowRaidCharacterWindow(self.member)
		end
	end)

	return row
end

local function CreateHistoryPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints(parent)

	local hint = W.CreateFontString(page, nil, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("TOPLEFT", 0, 0)
	hint:SetPoint("RIGHT", page, "RIGHT", -100, 0)
	hint:SetJustifyH("LEFT")
	hint:SetJustifyV("TOP")
	hint:SetText(W.T("HISTORY_HINT"))

	local refreshBtn = W.CreatePlainButton(page, 96, UI.CD_TOOLBAR_H, W.T("BTN_REFRESH"))
	refreshBtn:SetPoint("TOPRIGHT", 0, 0)
	refreshBtn:SetScript("OnClick", function()
		if Addon.RecordCurrentGroupHistory then
			Addon:RecordCurrentGroupHistory(true)
		end
		Addon:RefreshHistoryView()
	end)

	local tableTop = -W.CooldownTableTopOffset()
	local tableHost = CreateFrame("Frame", nil, page)
	tableHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, tableTop)
	tableHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	W.ApplyPlainPanel(tableHost, UI.PANEL_BG)
	page.tableHost = tableHost

	local scroll = CreateFrame("ScrollFrame", "RaidwiseHistoryScrollV" .. tostring(LAYOUT_VERSION), tableHost)
	scroll:SetPoint("TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", -(UI.CD_SCROLLBAR_W + 2), UI.CD_HSCROLL_H + 2)
	scroll:EnableMouseWheel(true)
	page.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	page.tableContent = content
	page.rowFrames = {}

	local headerBg = CreateFrame("Frame", nil, content)
	headerBg:SetPoint("TOPLEFT", 0, 0)
	headerBg:SetHeight(UI.CD_HEADER_H)
	W.ApplyPlainPanel(headerBg, UI.TITLE_BG)
	page.headerBg = headerBg

	local headers = {
		W.T("COL_NAME"), W.T("COL_CLASS"), W.T("COL_SPEC"), W.T("COL_OPINION"),
		W.T("COL_TAGS"), W.T("COL_GS"), W.T("COL_ILVL"), W.T("COL_ZONE"), W.T("COL_WHEN"), W.T("COL_GUILD"),
	}
	page.headerKeys = {
		"COL_NAME", "COL_CLASS", "COL_SPEC", "COL_OPINION",
		"COL_TAGS", "COL_GS", "COL_ILVL", "COL_ZONE", "COL_WHEN", "COL_GUILD",
	}
	page.headerLabels = {}
	for index = 1, #headers do
		local label = W.CreateFontString(headerBg, nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", headerBg, "TOPLEFT", HistoryColumnOffset(index) + 4, -10)
		label:SetWidth(HISTORY_COLUMN_WIDTHS[index] - 8)
		label:SetJustifyH((index == 4 or index == 6 or index == 7) and "CENTER" or "LEFT")
		label:SetText(headers[index])
		W.SetFontColor(label, UI.GOLD)
		page.headerLabels[index] = label
	end

	local vBar = W.CreateCooldownScrollBar(tableHost, "VERTICAL")
	vBar:SetPoint("TOPRIGHT", -1, -1)
	vBar:SetPoint("BOTTOMRIGHT", -1, UI.CD_HSCROLL_H + 2)
	vBar:SetScript("OnValueChanged", function(self)
		scroll:SetVerticalScroll(self:GetValue() or 0)
	end)
	page.vBar = vBar

	local hBar = W.CreateCooldownScrollBar(tableHost, "HORIZONTAL")
	hBar:SetPoint("BOTTOMLEFT", 1, 1)
	hBar:SetPoint("BOTTOMRIGHT", -(UI.CD_SCROLLBAR_W + 2), 1)
	hBar:SetScript("OnValueChanged", function(self)
		scroll:SetHorizontalScroll(self:GetValue() or 0)
	end)
	page.hBar = hBar

	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxV = math.max(0, (content:GetHeight() or 0) - (self:GetHeight() or 0))
		local step = UI.CD_ROW_H
		local nextValue = math.max(0, math.min(maxV, (self:GetVerticalScroll() or 0) - delta * step))
		self:SetVerticalScroll(nextValue)
		vBar:SetValue(nextValue)
	end)
	scroll:SetScript("OnSizeChanged", function()
		W.LayoutTableScrollBars(page)
	end)

	page:SetScript("OnShow", function()
		Addon:RefreshHistoryView()
	end)

	page.hint = hint
	page.refreshBtn = refreshBtn
	page.layoutVersion = LAYOUT_VERSION
	return page
end

-- REFACTOR candidate: standard row-pool refresh pattern shared with History.
function Addon:RefreshHistoryView()
	local frame = self.mainFrame
	local page = frame and frame.pages and frame.pages.history
	if not page then
		return
	end

	if not self.BuildHistoryRoster then
		if page.hint then
			page.hint:SetText(W.T("HISTORY_FAIL"))
		end
		return
	end

	page.tableHost:Show()

	local roster = self:BuildHistoryRoster()
	local content = page.tableContent
	local headerBg = page.headerBg
	local tableW = HistoryTableWidth()
	local tableH = UI.CD_HEADER_H + math.max(#roster, 1) * UI.CD_ROW_H

	content:SetSize(tableW, tableH)
	headerBg:SetWidth(tableW)

	W.HidePoolFrom(page.rowFrames, #roster + 1)
	for rowIndex = 1, #roster do
		local member = roster[rowIndex]
		local row = page.rowFrames[rowIndex]
		if not row then
			row = CreateHistoryRow(content)
			page.rowFrames[rowIndex] = row
		end

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(UI.CD_HEADER_H + (rowIndex - 1) * UI.CD_ROW_H))
		row:SetSize(tableW, UI.CD_ROW_H)
		local stripe = (rowIndex % 2 == 1) and UI.CD_ROW_A or UI.CD_ROW_B
		row.stripe = stripe
		W.SetBackdropColor(row, stripe)
		row.member = member

		row.nameText:SetText(member.name or "")
		row.nameText:SetTextColor(W.ClassColor(member.class))
		row.classLabel = member.classLabel
		row.specLabel = member.spec
		W.SetSpecOrClassIcon(row.classIcon, nil, member.class)
		W.SetSpecOrClassIcon(row.specIcon, member.specIcon, member.class)

		local opinionIcon = W.IconMarkup(W.RatingOpinionIcon(member), 16)
		if opinionIcon ~= "" then
			row.opinionText:SetText(opinionIcon)
			W.SetFontColor(row.opinionText, UI.TEXT_BODY)
		else
			row.opinionText:SetText(W.RatingOpinionSymbol(member))
			W.SetFontColor(row.opinionText, W.RatingOpinionColor(member))
		end

		local tags = W.FormatTagLine(member)
		if tags ~= "" then
			row.tagText:SetText(tags)
			W.SetFontColor(row.tagText, UI.TEXT_IDLE)
		else
			row.tagText:SetText("-")
			W.SetFontColor(row.tagText, UI.TEXT_DISABLED)
		end

		if member.gearScore then
			row.gsText:SetText(tostring(member.gearScore))
			W.SetFontColor(row.gsText, UI.GOLD)
		else
			row.gsText:SetText("-")
			W.SetFontColor(row.gsText, UI.TEXT_DISABLED)
		end

		if member.averageIlvl then
			row.ilvlText:SetText(tostring(member.averageIlvl))
			W.SetFontColor(row.ilvlText, UI.TEXT_IDLE)
		else
			row.ilvlText:SetText("-")
			W.SetFontColor(row.ilvlText, UI.TEXT_DISABLED)
		end

		if member.metZone and member.metZone ~= "" then
			row.zoneText:SetText(member.metZone)
			W.SetFontColor(row.zoneText, UI.TEXT_IDLE)
		else
			row.zoneText:SetText("-")
			W.SetFontColor(row.zoneText, UI.TEXT_DISABLED)
		end

		local metWhen = self:FormatHistoryTime(member.metAt)
		row.metText:SetText(metWhen)
		if metWhen ~= "-" then
			W.SetFontColor(row.metText, UI.TEXT_IDLE)
		else
			W.SetFontColor(row.metText, UI.TEXT_DISABLED)
		end

		row.guildText:SetText(W.FormatGuildDisplay(member.guildName, member.guildRank))
		W.SetFontColor(row.guildText, UI.TEXT_IDLE)
		row:Show()
	end

	W.LayoutTableScrollBars(page)
end

local function ApplyLocale(page)
	if page then
		if page.hint then
			page.hint:SetText(W.T("HISTORY_HINT"))
		end
		if page.refreshBtn then
			page.refreshBtn.label:SetText(W.T("BTN_REFRESH"))
		end
		for index, key in ipairs(page.headerKeys or {}) do
			if page.headerLabels[index] then page.headerLabels[index]:SetText(W.T(key)) end
		end
	end
end

Addon.Pages.History = {
	id = "history",
	LAYOUT_VERSION = LAYOUT_VERSION,
	Refresh = function(_, entering)
		if entering and Addon.RecordCurrentGroupHistory then
			Addon:RecordCurrentGroupHistory(false)
		else
			Addon:RefreshHistoryView()
		end
	end,
	ApplyLocale = ApplyLocale,
	Create = CreateHistoryPage,
}
