-- PageCooldowns

local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

Addon.Pages = Addon.Pages or {}

local LAYOUT_VERSION = 8

local CD_INSTANCE_COL_W = 170
local CD_CHAR_COL_W = 90
local CD_HEADER_H = 68
local CD_REMOVE_BTN_H = 16
local CD_REMOVE_BTN_PAD = 2
local CD_CURRENCY_ICON = 14
local CD_CURRENCY_CHIP_H = 16
local CD_CURRENCY_CHIP_GAP_Y = 1
local CD_CURRENCY_PAD = 3
local CD_CURRENCY_LEADER_H = 16
local CD_CURRENCY_ENTRY_COUNT = 9
local CD_CURRENCY_ROW_H = CD_CURRENCY_PAD * 2
	+ CD_CURRENCY_LEADER_H
	+ CD_CURRENCY_CHIP_GAP_Y
	+ CD_CURRENCY_ENTRY_COUNT * CD_CURRENCY_CHIP_H
	+ (CD_CURRENCY_ENTRY_COUNT - 1) * CD_CURRENCY_CHIP_GAP_Y

local function CurrencyChipWidth()
	return CD_CHAR_COL_W - CD_CURRENCY_PAD * 2
end

local function CurrencyEntryTop(index)
	return CD_CURRENCY_PAD
		+ CD_CURRENCY_LEADER_H
		+ CD_CURRENCY_CHIP_GAP_Y
		+ (index - 1) * (CD_CURRENCY_CHIP_H + CD_CURRENCY_CHIP_GAP_Y)
end

local function FormatLastCheckTime(timestamp)
	timestamp = tonumber(timestamp)
	if not timestamp or timestamp <= 0 then
		return "-"
	end
	if Addon.FormatShortDateTime then
		return Addon:FormatShortDateTime(timestamp)
	end
	return date("%d %b %H:%M", timestamp)
end

local function FormatLastCheckTooltip(timestamp)
	timestamp = tonumber(timestamp)
	if not timestamp or timestamp <= 0 then
		return W.T("CD_LAST_CHECK_NONE")
	end
	if Addon.FormatHistoryTime then
		return W.T("CD_LAST_CHECK", Addon:FormatHistoryTime(timestamp))
	end
	return W.T("CD_LAST_CHECK", date("%Y-%m-%d %H:%M", timestamp))
end

local function CreateCooldownHeaderCell(parent)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetHeight(CD_HEADER_H)

	local icon = cell:CreateTexture(nil, "ARTWORK")
	icon:SetSize(UI.CD_SPEC_ICON, UI.CD_SPEC_ICON)
	icon:SetPoint("TOPLEFT", 6, -4)
	cell.icon = icon

	local name = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
	name:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
	name:SetHeight(14)
	name:SetJustifyH("LEFT")
	name:SetJustifyV("MIDDLE")
	cell.name = name

	local lastCheck = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	lastCheck:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
	lastCheck:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
	lastCheck:SetJustifyH("LEFT")
	W.SetFontColor(lastCheck, UI.TEXT_DISABLED)
	cell.lastCheck = lastCheck

	local removeBtn = W.CreatePlainButton(cell, CD_CHAR_COL_W - 8, CD_REMOVE_BTN_H, W.T("BTN_REMOVE"))
	removeBtn:SetPoint("BOTTOM", 0, CD_REMOVE_BTN_PAD)
	removeBtn:SetScript("OnClick", function(self)
		local characterKey = self.characterKey
		if not characterKey or not Addon.RemoveCharacterLockouts then
			return
		end
		if Addon:RemoveCharacterLockouts(characterKey) then
			Addon:RefreshCooldownTable()
		end
	end)
	W.SetPlainButtonTooltip(removeBtn, "CD_REMOVE_TIP")
	removeBtn:Hide()
	cell.removeBtn = removeBtn

	cell:EnableMouse(true)
	cell:SetScript("OnEnter", function(self)
		if not self.tooltipTitle then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.tooltipTitle)
		if self.tooltipSpec then
			GameTooltip:AddLine(self.tooltipSpec, 0.8, 0.8, 0.8)
		end
		if self.tooltipLastCheck then
			GameTooltip:AddLine(self.tooltipLastCheck, 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	cell:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return cell
end

local function CreateCooldownRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(UI.CD_ROW_H)
	W.ApplyPlainPanel(row, UI.CD_ROW_A)

	local name = W.CreateFontString(row, nil, "OVERLAY", "GameFontHighlight")
	name:SetPoint("TOPLEFT", 6, -4)
	name:SetPoint("RIGHT", row, "LEFT", CD_INSTANCE_COL_W - 4, 0)
	name:SetJustifyH("LEFT")
	name:SetJustifyV("TOP")
	row.instanceName = name

	local typeLabel = W.CreateFontString(row, nil, "OVERLAY", "GameFontNormalSmall")
	typeLabel:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
	typeLabel:SetPoint("RIGHT", row, "LEFT", CD_INSTANCE_COL_W - 4, 0)
	typeLabel:SetJustifyH("LEFT")
	W.SetFontColor(typeLabel, UI.TEXT_IDLE)
	row.typeLabel = typeLabel

	row.cells = {}
	return row
end

local function RowHeight(rowData)
	if rowData and rowData.kind == "currency" then
		return CD_CURRENCY_ROW_H
	end
	return UI.CD_ROW_H
end

local function CreateCurrencyChip(parent)
	local chip = CreateFrame("Frame", nil, parent)
	chip:SetSize(CurrencyChipWidth(), CD_CURRENCY_CHIP_H)

	local icon = chip:CreateTexture(nil, "ARTWORK")
	icon:SetSize(CD_CURRENCY_ICON, CD_CURRENCY_ICON)
	icon:SetPoint("LEFT", 0, 0)
	chip.icon = icon

	local count = W.CreateFontString(chip, nil, "OVERLAY", "GameFontNormalSmall")
	count:SetPoint("LEFT", icon, "RIGHT", 2, 0)
	count:SetPoint("RIGHT", chip, "RIGHT", 0, 0)
	count:SetJustifyH("LEFT")
	count:SetJustifyV("MIDDLE")
	count:SetNonSpaceWrap(false)
	chip.count = count

	return chip
end

local function ColorText(color, text)
	return W.ColorText(color, text)
end

local function FormatLockoutDisplayText(variants)
	local parts = {}
	for index = 1, #variants do
		local variant = variants[index]
		if index > 1 then
			parts[#parts + 1] = " "
		end
		local color = variant.heroic and UI.TEXT_ALERT or UI.GOLD
		parts[#parts + 1] = ColorText(color, variant.tag)
	end
	return table.concat(parts)
end

local function CreateCooldownValueCell(parent)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetHeight(UI.CD_ROW_H)
	cell.chips = {}

	local text = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", 4, 0)
	text:SetPoint("RIGHT", -4, 0)
	text:SetJustifyH("CENTER")
	cell.text = text

	cell:EnableMouse(true)
	cell:SetScript("OnEnter", function(self)
		if not self.tooltipTitle then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.tooltipTitle)
		if self.tooltipType and self.tooltipType ~= "" then
			GameTooltip:AddLine(self.tooltipType, 0.8, 0.8, 0.8)
		end
		if self.tooltipEntries then
			for lineIndex = 1, #self.tooltipEntries do
				local entry = self.tooltipEntries[lineIndex]
				if entry.heroic then
					GameTooltip:AddLine(entry.text, UI.TEXT_ALERT[1], UI.TEXT_ALERT[2], UI.TEXT_ALERT[3])
				else
					GameTooltip:AddLine(entry.text, 1, 1, 1)
				end
			end
		elseif self.tooltipLines then
			for lineIndex = 1, #self.tooltipLines do
				GameTooltip:AddLine(self.tooltipLines[lineIndex], 1, 1, 1)
			end
		elseif self.tooltipBody then
			GameTooltip:AddLine(self.tooltipBody, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	cell:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return cell
end

local function HideCurrencyChips(cell)
	if not cell.chips then
		return
	end
	for index = 1, #cell.chips do
		cell.chips[index]:Hide()
	end
end

-- REFACTOR candidate: positions pooled currency icon chips with computed Y offsets.
local function FillCurrencyChips(cell, entries, hasValue)
	cell.chips = cell.chips or {}
	local chipW = CurrencyChipWidth()
	entries = entries or {}
	W.HidePoolFrom(cell.chips, #entries + 1)
	for index = 1, #entries do
		local entry = entries[index]
		local chip = cell.chips[index]
		if not chip then
			chip = CreateCurrencyChip(cell)
			cell.chips[index] = chip
		end
		chip:ClearAllPoints()
		chip:SetSize(chipW, CD_CURRENCY_CHIP_H)
		chip:SetPoint(
			"TOPLEFT",
			cell,
			"TOPLEFT",
			CD_CURRENCY_PAD,
			-CurrencyEntryTop(index)
		)
		local icon = entry.icon
		if type(icon) ~= "string" or icon == "" then
			icon = "Interface\\Icons\\INV_Misc_QuestionMark"
		end
		chip.icon:SetTexture(icon)
		chip.count:SetText(entry.displayCount or "0")
		if hasValue then
			W.SetFontColor(chip.count, UI.GOLD)
		else
			W.SetFontColor(chip.count, UI.TEXT_IDLE)
		end
		chip:Show()
	end
end

local function HideCurrencyRowLabels(row)
	if not row.labelLines then
		return
	end
	for index = 1, #row.labelLines do
		row.labelLines[index]:Hide()
	end
end

local function CreateCurrencyRowLabel(parent)
	local label = W.CreateFontString(parent, nil, "OVERLAY", "GameFontNormalSmall")
	label:SetHeight(CD_CURRENCY_CHIP_H)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	return label
end

-- REFACTOR candidate: pooled label lines aligned to currency entry indices.
local function FillCurrencyRowLabels(row, summaries)
	row.labelLines = row.labelLines or {}
	summaries = summaries or {}
	W.HidePoolFrom(row.labelLines, #summaries + 1)
	for index = 1, #summaries do
		local summary = summaries[index]
		local label = row.labelLines[index]
		if not label then
			label = CreateCurrencyRowLabel(row)
			row.labelLines[index] = label
		end
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -CurrencyEntryTop(index))
		label:SetPoint("RIGHT", row, "LEFT", CD_INSTANCE_COL_W - 4, 0)
		if type(summary) == "table" then
			label:SetText(summary.text or ((summary.label or "") .. "  " .. (summary.displayTotal or "0")))
			if (tonumber(summary.total) or 0) > 0 then
				W.SetFontColor(label, UI.GOLD)
			else
				W.SetFontColor(label, UI.TEXT_IDLE)
			end
		else
			label:SetText(tostring(summary or ""))
			W.SetFontColor(label, UI.TEXT_IDLE)
		end
		label:Show()
	end
end

local function ConfigureLockoutRowHeading(row)
	row.instanceName:ClearAllPoints()
	row.instanceName:SetPoint("TOPLEFT", 6, -4)
	row.instanceName:SetPoint("RIGHT", row, "LEFT", CD_INSTANCE_COL_W - 4, 0)
	row.instanceName:SetJustifyH("LEFT")
	row.instanceName:SetJustifyV("TOP")
	row.instanceName:SetFontObject("GameFontHighlight")
	row.typeLabel:Show()
	HideCurrencyRowLabels(row)
end

local function ConfigureCurrencyRowHeading(row, title, summaries)
	row.instanceName:ClearAllPoints()
	row.instanceName:SetPoint("TOPLEFT", 6, -CD_CURRENCY_PAD)
	row.instanceName:SetPoint("RIGHT", row, "LEFT", CD_INSTANCE_COL_W - 4, 0)
	row.instanceName:SetHeight(CD_CURRENCY_LEADER_H)
	row.instanceName:SetJustifyH("LEFT")
	row.instanceName:SetJustifyV("MIDDLE")
	row.instanceName:SetText(title or "")
	W.SetFontColor(row.instanceName, UI.GOLD)
	row.typeLabel:SetText("")
	row.typeLabel:Hide()
	FillCurrencyRowLabels(row, summaries)
end

local function ConfigureCurrencyCell(cell)
	cell:SetHeight(CD_CURRENCY_ROW_H)
	cell.text:SetText("")
	cell.text:Hide()
end

local function ConfigureLockoutCell(cell, rowHeight)
	cell:SetHeight(rowHeight)
	HideCurrencyChips(cell)
	cell.text:Show()
	cell.text:ClearAllPoints()
	cell.text:SetPoint("LEFT", 4, 0)
	cell.text:SetPoint("RIGHT", -4, 0)
	cell.text:SetJustifyH("CENTER")
	cell.text:SetJustifyV("MIDDLE")
	cell.text:SetWidth(0)
end

local function CreateCooldownsPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints(parent)

	local hint = W.CreateFontString(page, nil, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("TOPLEFT", 0, 0)
	hint:SetPoint("RIGHT", page, "RIGHT", -100, 0)
	hint:SetJustifyH("LEFT")
	hint:SetJustifyV("TOP")
	hint:SetText(W.T("CD_HINT"))

	local refreshBtn = W.CreatePlainButton(page, 96, UI.CD_TOOLBAR_H, W.T("BTN_REFRESH"))
	refreshBtn:SetPoint("TOPRIGHT", 0, 0)
	W.SetPlainButtonTooltip(refreshBtn, "CD_REFRESH_TIP")
	refreshBtn:SetScript("OnClick", function()
		Addon.pendingLockoutTable = true
		RequestRaidInfo()
		Addon:RefreshCooldownTable()
	end)

	local tableTop = -W.CooldownTableTopOffset()

	local emptyLabel = W.CreateFontString(page, nil, "OVERLAY", "GameFontNormalSmall")
	emptyLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, tableTop)
	emptyLabel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	emptyLabel:SetJustifyH("CENTER")
	emptyLabel:SetJustifyV("MIDDLE")
	W.SetFontColor(emptyLabel, UI.TEXT_IDLE)
	emptyLabel:SetText(W.T("CD_EMPTY"))
	page.emptyLabel = emptyLabel

	local tableHost = CreateFrame("Frame", nil, page)
	tableHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, tableTop)
	tableHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	W.ApplyPlainPanel(tableHost, UI.PANEL_BG)
	page.tableHost = tableHost

	local scroll = CreateFrame("ScrollFrame", "RaidwiseCooldownScrollV" .. tostring(LAYOUT_VERSION), tableHost)
	scroll:SetPoint("TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", -(UI.CD_SCROLLBAR_W + 2), UI.CD_HSCROLL_H + 2)
	scroll:EnableMouseWheel(true)
	page.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	page.tableContent = content
	page.headerCells = {}
	page.rowFrames = {}

	local headerBg = CreateFrame("Frame", nil, content)
	headerBg:SetPoint("TOPLEFT", 0, 0)
	headerBg:SetHeight(CD_HEADER_H)
	W.ApplyPlainPanel(headerBg, UI.TITLE_BG)
	page.headerBg = headerBg

	local instanceHeader = W.CreateFontString(headerBg, nil, "OVERLAY", "GameFontNormal")
	instanceHeader:SetPoint("LEFT", 6, 0)
	instanceHeader:SetText(W.T("CD_INSTANCE"))
	W.SetFontColor(instanceHeader, UI.GOLD)
	page.instanceHeader = instanceHeader

	local noRowsLabel = W.CreateFontString(content, nil, "OVERLAY", "GameFontNormalSmall")
	noRowsLabel:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 8, -10)
	noRowsLabel:SetPoint("RIGHT", content, "RIGHT", -8, 0)
	noRowsLabel:SetJustifyH("LEFT")
	W.SetFontColor(noRowsLabel, UI.TEXT_IDLE)
	noRowsLabel:SetText(W.T("CD_NO_ROWS"))
	noRowsLabel:Hide()
	page.noRowsLabel = noRowsLabel

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

	page.hint = hint
	page.refreshBtn = refreshBtn
	page.layoutVersion = LAYOUT_VERSION
	return page
end
-- REFACTOR candidate: full table relayout — headers, row pool, lockout vs currency cells, scrollbars (~160 lines).
function Addon:RefreshCooldownTable()
	local frame = self.mainFrame
	local page = frame and frame.pages and frame.pages.cooldowns
	if not page then
		return
	end

	self:SaveCurrentCharacterLockouts()

	local model = self:BuildCooldownTable()
	local characters = model.characters
	local rows = model.rows
	local lockoutRowCount = model.lockoutRowCount or 0
	local content = page.tableContent
	local headerBg = page.headerBg

	if #characters == 0 then
		page.emptyLabel:ClearAllPoints()
		page.emptyLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -W.CooldownTableTopOffset())
		page.emptyLabel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
		page.emptyLabel:SetText(W.T("CD_EMPTY"))
		page.emptyLabel:Show()
		page.tableHost:Hide()
		return
	end

	page.emptyLabel:Hide()
	page.tableHost:Show()

	local tableW = CD_INSTANCE_COL_W + (#characters * CD_CHAR_COL_W)
	local tableH = CD_HEADER_H
	for rowIndex = 1, #rows do
		tableH = tableH + RowHeight(rows[rowIndex])
	end
	if tableH <= CD_HEADER_H then
		tableH = CD_HEADER_H + UI.CD_ROW_H
	end
	content:SetSize(tableW, tableH)
	headerBg:SetWidth(tableW)

	W.HidePoolFrom(page.headerCells, #characters + 1)
	for index = 1, #characters do
		local character = characters[index]
		local cell = page.headerCells[index]
		if not cell then
			cell = CreateCooldownHeaderCell(headerBg)
			page.headerCells[index] = cell
		end
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", headerBg, "TOPLEFT", CD_INSTANCE_COL_W + (index - 1) * CD_CHAR_COL_W, 0)
		cell:SetWidth(CD_CHAR_COL_W)
		cell.name:SetText(character.displayName)
		cell.name:SetTextColor(W.ClassColor(character.class))
		W.SetSpecOrClassIcon(cell.icon, character.specIcon, character.class)
		cell.lastCheck:SetText(FormatLastCheckTime(character.updatedAt))
		cell.tooltipTitle = character.displayName
		cell.tooltipSpec = character.spec ~= "" and character.spec or nil
		cell.tooltipLastCheck = FormatLastCheckTooltip(character.updatedAt)
		if cell.removeBtn then
			if character.isCurrent then
				cell.removeBtn.characterKey = nil
				cell.removeBtn:Hide()
			else
				cell.removeBtn.characterKey = character.key
				cell.removeBtn.label:SetText(W.T("BTN_REMOVE"))
				cell.removeBtn:Show()
			end
		end
		cell:Show()
	end

	W.HidePoolFrom(page.rowFrames, #rows + 1)
	local yOffset = CD_HEADER_H
	for rowIndex = 1, #rows do
		local rowData = rows[rowIndex]
		local rowHeight = RowHeight(rowData)
		local row = page.rowFrames[rowIndex]
		if not row then
			row = CreateCooldownRow(content)
			page.rowFrames[rowIndex] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
		row:SetSize(tableW, rowHeight)
		yOffset = yOffset + rowHeight
		local stripe = (rowIndex % 2 == 1) and UI.CD_ROW_A or UI.CD_ROW_B
		row.stripe = stripe
		W.SetBackdropColor(row, stripe)
		if rowData.kind == "currency" then
			ConfigureCurrencyRowHeading(row, rowData.name, rowData.entrySummaries or rowData.entryLabels)
		else
			ConfigureLockoutRowHeading(row)
			row.instanceName:SetText(rowData.name)
			row.typeLabel:SetText(rowData.typeLabel)
		end

		W.HidePoolFrom(row.cells, #characters + 1)
		for colIndex = 1, #characters do
			local character = characters[colIndex]
			local cell = row.cells[colIndex]
			if not cell then
				cell = CreateCooldownValueCell(row)
				row.cells[colIndex] = cell
			end
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", row, "TOPLEFT", CD_INSTANCE_COL_W + (colIndex - 1) * CD_CHAR_COL_W, 0)
			cell:SetWidth(CD_CHAR_COL_W)

			local saved = rowData.cells[character.key]
			cell.tooltipTitle = rowData.name
			cell.tooltipType = rowData.typeLabel
			cell.tooltipEntries = nil
			cell.tooltipLines = nil
			cell.tooltipBody = nil
			if rowData.kind == "currency" then
				ConfigureCurrencyCell(cell)
				if saved and saved.entries then
					FillCurrencyChips(cell, saved.entries, saved.hasValue)
					cell.tooltipLines = saved.tooltipLines
				else
					HideCurrencyChips(cell)
					cell.text:Show()
					cell.text:ClearAllPoints()
					cell.text:SetPoint("TOPLEFT", CD_CURRENCY_PAD, -CurrencyEntryTop(1))
					cell.text:SetPoint("RIGHT", cell, "RIGHT", -CD_CURRENCY_PAD, 0)
					cell.text:SetHeight(CD_CURRENCY_CHIP_H)
					cell.text:SetJustifyH("CENTER")
					cell.text:SetJustifyV("MIDDLE")
					cell.text:SetText("-")
					W.SetFontColor(cell.text, UI.TEXT_DISABLED)
					cell.tooltipBody = W.T("CD_CURRENCY_NONE")
				end
			else
				ConfigureLockoutCell(cell, rowHeight)
				if saved and saved.variants and #saved.variants > 0 then
					cell.text:SetText(FormatLockoutDisplayText(saved.variants))
					cell.tooltipEntries = saved.tooltipEntries
				elseif saved and saved.displayText then
					cell.text:SetText(saved.displayText)
					W.SetFontColor(cell.text, UI.GOLD)
				else
					cell.text:SetText("-")
					W.SetFontColor(cell.text, UI.TEXT_DISABLED)
					cell.tooltipBody = W.T("CD_NOT_SAVED")
				end
			end
			cell:Show()
		end
		row:Show()
	end

	if page.noRowsLabel then
		if lockoutRowCount == 0 then
			page.noRowsLabel:Show()
		else
			page.noRowsLabel:Hide()
		end
	end

	page.emptyLabel:Hide()
	W.LayoutTableScrollBars(page)
end

local function ApplyLocale(page)
	if page then
		if page.hint then
			page.hint:SetText(W.T("CD_HINT"))
		end
		if page.refreshBtn then
			page.refreshBtn.label:SetText(W.T("BTN_REFRESH"))
		end
		if page.emptyLabel then
			page.emptyLabel:SetText(W.T("CD_EMPTY"))
		end
		if page.instanceHeader then
			page.instanceHeader:SetText(W.T("CD_INSTANCE"))
		end
		if page.noRowsLabel then
			page.noRowsLabel:SetText(W.T("CD_NO_ROWS"))
		end
	end
end

Addon.Pages.Cooldowns = {
	id = "cooldowns",
	LAYOUT_VERSION = LAYOUT_VERSION,
	Refresh = function(_, entering)
		if entering then
			Addon.pendingLockoutTable = true
			Addon:SaveCurrentCharacterLockouts()
			RequestRaidInfo()
		end
		Addon:RefreshCooldownTable()
	end,
	ApplyLocale = ApplyLocale,
	Create = CreateCooldownsPage,
}
