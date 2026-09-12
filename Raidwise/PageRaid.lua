-- PageRaid — raid groups grid with integrated gear-check scan and report rows.

local Addon = Raidwise
local W = Addon.Widgets
local UI = Addon.UITheme

Addon.Pages = Addon.Pages or {}

local LAYOUT_VERSION = 30

local RAID_CELL_W = 168
local RAID_CELL_H = 100
local RAID_CELL_GAP = 2
local RAID_CELL_PAD = 4
local RAID_LINE_H = 14
local RAID_ICON = 20
local RAID_BTN_H = 16
local RAID_BTN_GAP = 2
local RAID_GROUP_LABEL_H = 16
local RAID_BLOCK_GAP = 12
local RAID_REPORT_ICON = "Interface\\Icons\\Ability_Warrior_BattleShout"
local RAID_TOOLBAR_SCAN_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local RAID_TOOLBAR_EXPORT_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local RAID_TOOLBAR_REFRESH_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local RAID_TOOLBAR_BACK_ICON = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider"
local GRADE_CHIP_LABELS = { "S", "A", "B", "C", "D" }

local function WrapThemeColor(color, text)
	local r = math.floor(((color and color[1]) or 1) * 255 + 0.5)
	local g = math.floor(((color and color[2]) or 1) * 255 + 0.5)
	local b = math.floor(((color and color[3]) or 1) * 255 + 0.5)
	return string.format("|cff%02x%02x%02x%s|r", r, g, b, tostring(text or ""))
end

local function SummaryHeadingPrefix(heading)
	return WrapThemeColor(UI.GOLD, heading) .. "  "
end

local SCAN_PHASE_KEYS = {
	inspect = "GEAR_CHECK_RAID_PHASE_INSPECT",
	spec = "GEAR_CHECK_RAID_PHASE_SPEC",
	gems = "GEAR_CHECK_RAID_PHASE_GEMS",
	evaluate = "GEAR_CHECK_RAID_PHASE_EVALUATE",
	done = "GEAR_CHECK_RAID_PHASE_DONE",
	export = "GEAR_CHECK_RAID_PHASE_EXPORT",
}

local function FormatRaidStatsLine(gearScore, averageIlvl)
	local parts = {}
	if gearScore then
		parts[#parts + 1] = W.T("STATS_GS", tostring(gearScore))
	end
	if averageIlvl then
		parts[#parts + 1] = W.T("STATS_ILVL", tostring(averageIlvl))
	end
	if #parts == 0 then
		return ""
	end
	return table.concat(parts, " ")
end

local function FormatRaidAverageGs(gearScore)
	local gsText = gearScore ~= nil and tostring(gearScore) or "-"
	return W.T("AVG_GS", gsText)
end

local function FormatRoleGsSummary(label, bucket)
	bucket = bucket or {}
	local gsText = bucket.gearScore ~= nil and tostring(bucket.gearScore) or "-"
	return W.T("ROLE_SUMMARY", label, tostring(bucket.count or 0), gsText)
end

local function IsGearVerdictLabel(label)
	return label == "S" or label == "A" or label == "B" or label == "C" or label == "D"
end

local function GearStatusLabelForEntry(entry)
	if not entry then
		return W.T("RAID_CELL_NOT_SCANNED")
	end
	local failLabel = Addon.GetGearCheckRaidEntryStatusLabel and Addon:GetGearCheckRaidEntryStatusLabel(entry)
	if failLabel then
		return failLabel
	end
	if not entry or not entry.report then
		return W.T("RAID_CELL_NOT_SCANNED")
	end
	local overall = entry.report.overall or {}
	return Addon:GetGearCheckScanLabel(entry.report) or overall.status or "B"
end

local function GradeFromEntry(entry, field)
	if not entry or not entry.report then
		return nil
	end
	if Addon:GetGearCheckScanState(entry.report) ~= "complete" then return nil end
	local overall = entry.report.overall or {}
	if field == "enchant" then
		return overall.enchantSocketGrade or "B"
	end
	return overall.gearGrade or overall.status or "B"
end

local function EntryDisplayName(entry)
	local member = entry and entry.member or {}
	local character = entry and entry.report and entry.report.character or {}
	return member.name or character.name or "?"
end

local function SummarizeGearCategory(results, field)
	local summary = {
		scanned = 0,
		s = 0,
		a = 0,
		b = 0,
		c = 0,
		d = 0,
		failed = 0,
		issueNames = {},
	}
	if type(results) ~= "table" then
		return summary
	end
	for index = 1, #results do
		local entry = results[index]
		local grade = GradeFromEntry(entry, field)
		if not entry or not entry.report or not grade then
			summary.failed = summary.failed + 1
		else
			summary.scanned = summary.scanned + 1
			if grade == "S" then
				summary.s = summary.s + 1
			elseif grade == "A" then
				summary.a = summary.a + 1
			elseif grade == "C" then
				summary.c = summary.c + 1
			elseif grade == "D" then
				summary.d = summary.d + 1
			else
				summary.b = summary.b + 1
			end
			if grade == "C" or grade == "D" then
				summary.issueNames[#summary.issueNames + 1] = string.format("%s (%s)", EntryDisplayName(entry), grade)
			end
		end
	end
	return summary
end

local function FormatCompactGradesLine(gearGrade, enchantGrade)
	return W.T("RAID_CELL_GRADE_GEAR", W.WrapGearGradation(gearGrade))
		.. "  "
		.. W.T("RAID_CELL_GRADE_ENCH", W.WrapGearGradation(enchantGrade))
end

-- Compact rating row: personal Qiraji crystal icon + community percent (e.g. "P: [icon]  C: 75%").
local function FormatRatingCellLine(member)
	local iconMarkup = W.IconMarkup(W.RatingOpinionIcon(member), RAID_LINE_H)
	if iconMarkup == "" then
		iconMarkup = W.RatingOpinionSymbol(member)
		if Addon.RatingWrapColor then
			iconMarkup = Addon:RatingWrapColor(iconMarkup, W.RatingOpinionColor(member))
		end
	end
	local personalPart = W.T("RAID_CELL_PERSONAL", iconMarkup)

	local community = Addon.GetCommunityRating and Addon:GetCommunityRating(member)
	local percent = community and tonumber(community.positivePercent)
	local communityPart
	local communityColor = UI.TEXT_DISABLED
	if percent then
		communityPart = W.T("RAID_CELL_COMMUNITY", percent)
		communityColor = UI.TEXT_IDLE
	else
		communityPart = W.T("RAID_CELL_COMMUNITY_EMPTY")
	end
	if Addon.RatingWrapColor then
		communityPart = Addon:RatingWrapColor(communityPart, communityColor)
	end
	return personalPart .. "  " .. communityPart
end

local function FormatGearCategorySummaryLine(summary)
	summary = summary or {}
	local failedSuffix = ""
	if (summary.failed or 0) > 0 then
		failedSuffix = " · Failed " .. tostring(summary.failed)
	end
	return W.FormatGearVerdictCountsLine(nil, summary, failedSuffix)
end

local function FillGearCategorySummaryLabel(label, heading, summary)
	if not label then
		return
	end
	local prefix = SummaryHeadingPrefix(heading)
	local scanned = (summary and summary.scanned) or 0
	local failed = (summary and summary.failed) or 0
	W.SetFontColor(label, UI.TEXT_BODY)
	if scanned + failed <= 0 then
		label:SetText(prefix .. WrapThemeColor(UI.TEXT_DISABLED, W.T("RAID_GRADE_SUMMARY_EMPTY")))
		return
	end
	label:SetText(prefix .. FormatGearCategorySummaryLine(summary))
end

local function UpdateRaidGradeSummaries(page, results)
	if not page then
		return
	end
	results = results or {}
	local gear = SummarizeGearCategory(results, "gear")
	local enchant = SummarizeGearCategory(results, "enchant")
	page.gearGradeSummary = gear
	page.enchantGradeSummary = enchant
	FillGearCategorySummaryLabel(page.gearGradeSummaryLabel, W.T("RAID_SUMMARY_GEAR"), gear)
	FillGearCategorySummaryLabel(page.enchantGradeSummaryLabel, W.T("RAID_SUMMARY_ENCHANT"), enchant)
end

local function IndexGearResults(results)
	local byGuid = {}
	local byName = {}
	if type(results) ~= "table" then
		return byGuid, byName
	end
	for index = 1, #results do
		local entry = results[index]
		local member = entry and entry.member or {}
		local character = entry and entry.report and entry.report.character or {}
		local guid = member.guid or character.guid
		if type(guid) == "string" and guid ~= "" then
			byGuid[guid] = entry
		end
		local name = member.name or character.name
		if type(name) == "string" and name ~= "" then
			byName[name] = entry
		end
	end
	return byGuid, byName
end

local function GearEntryForMember(member, byGuid, byName)
	if not member then
		return nil
	end
	if member.guid and byGuid[member.guid] then
		return byGuid[member.guid]
	end
	if member.name and byName[member.name] then
		return byName[member.name]
	end
	return nil
end

local function ResolveGearCheckResults(page)
	local results = page and page.gearCheckResults
	if (not results or #results == 0) and Addon.GetLastGearCheckRaidResults then
		results = Addon:GetLastGearCheckRaidResults() or {}
		if page then
			page.gearCheckResults = results
		end
	end
	return results or {}
end

local function FormatGradeChipLine()
	local parts = {}
	for index = 1, #GRADE_CHIP_LABELS do
		parts[#parts + 1] = W.WrapGearGradation(GRADE_CHIP_LABELS[index])
	end
	return table.concat(parts, " · ")
end

local function FormatRaidRoleChip(label, bucket)
	bucket = bucket or {}
	return label .. " " .. tostring(bucket.count or 0)
end

local function FormatRaidRosterStatsCompact(gearScore, roles)
	roles = roles or {}
	return FormatRaidAverageGs(gearScore)
		.. "   "
		.. FormatRaidRoleChip(W.T("ROLE_TANKS"), roles.tank or {})
		.. " · "
		.. FormatRaidRoleChip(W.T("ROLE_HEALERS"), roles.healer or {})
		.. " · "
		.. FormatRaidRoleChip(W.T("ROLE_MELEE_SHORT"), roles.melee or {})
		.. " · "
		.. FormatRaidRoleChip(W.T("ROLE_RANGE"), roles.ranged or {})
end

local function RosterStatsTipLines(gearScore, roles)
	roles = roles or {}
	return {
		FormatRaidAverageGs(gearScore),
		FormatRoleGsSummary(W.T("ROLE_TANKS"), roles.tank or {}),
		FormatRoleGsSummary(W.T("ROLE_HEALERS"), roles.healer or {}),
		FormatRoleGsSummary(W.T("ROLE_MELEE_SHORT"), roles.melee or {}),
		FormatRoleGsSummary(W.T("ROLE_RANGE"), roles.ranged or {}),
	}
end

local function ShowRosterStatsTooltip(owner, page)
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
	local lines = page and page.rosterStatsTipLines
	if type(lines) ~= "table" or #lines == 0 then
		lines = RosterStatsTipLines(nil, {})
	end
	for index = 1, #lines do
		local r, g, b = 1, 1, 1
		if index == 1 then
			r, g, b = UI.GOLD[1], UI.GOLD[2], UI.GOLD[3]
		end
		GameTooltip:AddLine(lines[index], r, g, b)
	end
	GameTooltip:Show()
end

local function UpdateRaidRosterStatsLabels(page, members)
	if not page or not page.statsLabel then
		return
	end

	local overall, roles
	if Addon.AverageRosterStatsByRole then
		overall, roles = Addon:AverageRosterStatsByRole(members)
	end
	overall = overall or {}
	roles = roles or {}

	page.rosterStatsTipLines = RosterStatsTipLines(overall.gearScore, roles)
	page.statsLabel:SetText(FormatRaidRosterStatsCompact(overall.gearScore, roles))
end

local function RosterMembersFromPage(page)
	local members = {}
	if not page then
		return members
	end
	local blocks = { page.topBlock, page.bottomBlock }
	for blockIndex = 1, #blocks do
		local block = blocks[blockIndex]
		if block and block.columns then
			for _, column in pairs(block.columns) do
				for slot = 1, 5 do
					local cell = column.cells and column.cells[slot]
					if cell and cell.member then
						members[#members + 1] = cell.member
					end
				end
			end
		end
	end
	return members
end

local function FormatConsumableStatus(present, total)
	return tostring(present) .. "/" .. tostring(total)
end

local function FillConsumableSummaryLabel(label, heading, present, total, missingCount)
	if not label then
		return
	end
	local prefix = SummaryHeadingPrefix(heading)
	W.SetFontColor(label, UI.TEXT_BODY)
	local cell = label:GetParent()
	if cell then
		cell.missingCount = missingCount or 0
	end
	if (total or 0) <= 0 then
		label:SetText(prefix .. WrapThemeColor(UI.TEXT_DISABLED, "—"))
		return
	end
	local status = FormatConsumableStatus(present, total)
	local color = ((missingCount or 0) > 0) and UI.TEXT_ALERT or UI.TEXT_GOOD
	label:SetText(prefix .. WrapThemeColor(color, status))
end

local function UpdateRaidConsumableSummary(page, members)
	if not page then
		return
	end
	local summary
	if Addon.SummarizeRaidConsumables then
		summary = Addon:SummarizeRaidConsumables(members or RosterMembersFromPage(page))
	end
	summary = summary or { total = 0, flaskPresent = 0, foodPresent = 0, flaskMissing = {}, foodMissing = {} }
	page.consumableSummary = summary
	local total = summary.total or 0
	FillConsumableSummaryLabel(
		page.flaskSummaryLabel,
		W.T("RAID_CONSUMABLE_FLASK"),
		summary.flaskPresent or 0,
		total,
		#(summary.flaskMissing or {})
	)
	FillConsumableSummaryLabel(
		page.foodSummaryLabel,
		W.T("RAID_CONSUMABLE_FOOD"),
		summary.foodPresent or 0,
		total,
		#(summary.foodMissing or {})
	)
end

local CHAT_LINE_MAX = 240

local function SendRaidConsumableChat(message)
	if Addon.SendReportChat then
		Addon:SendReportChat(message)
		return
	end
	Addon:Print(message)
end

local function SendRaidChatMessages(messages)
	if type(messages) ~= "table" then
		return
	end
	for index = 1, #messages do
		SendRaidConsumableChat(messages[index])
	end
end

local function BuildNameListMessages(template, names)
	local messages = {}
	if type(names) ~= "table" or #names == 0 then
		return messages
	end
	local batch = {}
	local function flush()
		if #batch == 0 then
			return
		end
		messages[#messages + 1] = string.format(template, table.concat(batch, ", "))
		batch = {}
	end
	for index = 1, #names do
		local name = names[index]
		local trial = name
		if #batch > 0 then
			trial = table.concat(batch, ", ") .. ", " .. name
		end
		if #batch > 0 and string.len(string.format(template, trial)) > CHAT_LINE_MAX then
			flush()
		end
		batch[#batch + 1] = name
	end
	flush()
	return messages
end

local function BuildMissingConsumableMessages(kind)
	local frame = Addon.mainFrame
	local page = frame and frame.pages and frame.pages.raid
	local summary = page and page.consumableSummary
	if not summary and Addon.SummarizeRaidConsumables then
		summary = Addon:SummarizeRaidConsumables(RosterMembersFromPage(page))
		if page then
			page.consumableSummary = summary
		end
	end
	summary = summary or { flaskMissing = {}, foodMissing = {} }
	if kind == "food" then
		local names = summary.foodMissing or {}
		if #names == 0 then
			return { W.T("RAID_CHAT_FOOD_ALL") }
		end
		return BuildNameListMessages(W.T("RAID_CHAT_FOOD_MISSING"), names)
	end
	local names = summary.flaskMissing or {}
	if #names == 0 then
		return { W.T("RAID_CHAT_FLASK_ALL") }
	end
	return BuildNameListMessages(W.T("RAID_CHAT_FLASK_MISSING"), names)
end

local function BuildGearCategoryMessages(kind)
	local frame = Addon.mainFrame
	local page = frame and frame.pages and frame.pages.raid
	local summary
	if kind == "enchant" then
		summary = page and page.enchantGradeSummary
	else
		summary = page and page.gearGradeSummary
	end
	local scanned = (summary and summary.scanned) or 0
	local failed = (summary and summary.failed) or 0
	if scanned + failed <= 0 then
		if kind == "enchant" then
			return { W.T("RAID_CHAT_ENCHANT_NONE") }
		end
		return { W.T("RAID_CHAT_GEAR_NONE") }
	end
	local names = (summary and summary.issueNames) or {}
	if #names == 0 then
		if kind == "enchant" then
			return { W.T("RAID_CHAT_ENCHANT_ALL") }
		end
		return { W.T("RAID_CHAT_GEAR_ALL") }
	end
	if kind == "enchant" then
		return BuildNameListMessages(W.T("RAID_CHAT_ENCHANT_ISSUES"), names)
	end
	return BuildNameListMessages(W.T("RAID_CHAT_GEAR_ISSUES"), names)
end

local function ReportMissingConsumablesToChat(kind)
	SendRaidChatMessages(BuildMissingConsumableMessages(kind))
end

local function ReportGearCategoryToChat(kind)
	SendRaidChatMessages(BuildGearCategoryMessages(kind))
end

local function SummaryStatusText(owner)
	if not owner then
		return nil
	end
	local body = owner.body
	if not body and owner.GetParent then
		local parent = owner:GetParent()
		body = parent and parent.body
	end
	if body and body.GetText then
		local text = body:GetText()
		if text and text ~= "" then
			return text
		end
	end
	return nil
end

local function ShowChatReportTooltip(owner, tipKey, messages)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if tipKey then
		GameTooltip:AddLine(W.T(tipKey), nil, nil, nil, true)
	end
	local statusText = SummaryStatusText(owner)
	if statusText then
		GameTooltip:AddLine(statusText, 1, 1, 1, true)
	end
	local cell = owner.body and owner or (owner.GetParent and owner:GetParent())
	local missingCount = cell and cell.missingCount
	if missingCount and missingCount > 0 then
		GameTooltip:AddLine(W.T("RAID_CONSUMABLE_MISSING_COUNT", missingCount), UI.TEXT_ALERT[1], UI.TEXT_ALERT[2], UI.TEXT_ALERT[3])
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(W.T("RAID_CHAT_PREVIEW"), 0.6, 0.6, 0.6)
	if type(messages) == "table" then
		for index = 1, #messages do
			GameTooltip:AddLine(Addon:PrepareReportMessage(messages[index]), 1, 1, 1, true)
		end
	end
	GameTooltip:Show()
end

local function SetChatReportButtonTooltip(button, tipKey, buildMessages)
	if not button then
		return
	end
	button.tooltipKey = tipKey
	button.buildChatMessages = buildMessages
	button:SetScript("OnEnter", function(self)
		W.SetPlainButtonState(self, W.ActionButtonState(self, true))
		local messages = self.buildChatMessages and self.buildChatMessages() or {}
		ShowChatReportTooltip(self, self.tooltipKey, messages)
	end)
	button:SetScript("OnLeave", function(self)
		W.SetPlainButtonState(self, W.ActionButtonState(self, false))
		GameTooltip:Hide()
	end)
end

local function SetSummaryCellTooltip(cell)
	if not cell then
		return
	end
	cell:EnableMouse(true)
	cell:SetScript("OnEnter", function(self)
		local reportBtn = self.reportBtn
		local messages = reportBtn and reportBtn.buildChatMessages and reportBtn.buildChatMessages() or {}
		ShowChatReportTooltip(self, reportBtn and reportBtn.tooltipKey, messages)
	end)
	cell:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function EqualColumnWidth(totalWidth, count, gap)
	count = count or 1
	gap = gap or 0
	return math.max(1, math.floor((math.max(1, totalWidth) - gap * (count - 1)) / count))
end

local function CreateRaidRosterHeader(page)
	local headerHost = CreateFrame("Frame", nil, page)
	headerHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	headerHost:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	headerHost:SetHeight(W.RaidRosterHeaderHeight())
	page.headerHost = headerHost

	local miniH = W.RaidRosterMiniTableHeight()
	local colGap = UI.RAID_HEADER_COL_GAP or 8
	local summaryCount = UI.RAID_SUMMARY_COL_COUNT or 4
	local row1H = UI.CD_TOOLBAR_H
	local row2H = UI.RAID_SUMMARY_BAND_H or 20
	local rowGap = UI.RAID_HEADER_ROW_GAP or 4
	local iconSize = UI.RAID_SUMMARY_REPORT_ICON or 16
	local iconGap = 4
	local btnGap = UI.RAID_TOOLBAR_BTN_GAP or 4
	local btnCount = UI.RAID_TOOLBAR_BTN_COUNT or 4

	local miniTable = CreateFrame("Frame", nil, headerHost)
	miniTable:SetPoint("TOPLEFT", headerHost, "TOPLEFT", 0, 0)
	miniTable:SetPoint("RIGHT", headerHost, "RIGHT", 0, 0)
	miniTable:SetHeight(miniH)
	page.miniTable = miniTable

	local function CreateHeaderColumn()
		return CreateFrame("Frame", nil, miniTable)
	end

	local function FillColumnText(col, template)
		local label = W.CreateFontString(col, nil, "OVERLAY", template)
		label:SetPoint("TOPLEFT", 0, 0)
		label:SetPoint("BOTTOMRIGHT", 0, 0)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		label:SetWordWrap(false)
		label:SetNonSpaceWrap(false)
		return label
	end

	local legendCol = CreateHeaderColumn()
	local gradeLegend = FillColumnText(legendCol, "GameFontNormalSmall")
	gradeLegend:SetText(FormatGradeChipLine())
	W.SetFontColor(gradeLegend, UI.TEXT_IDLE)
	legendCol:EnableMouse(true)
	legendCol:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(W.ColorizeGearGradation(W.T("GEAR_CHECK_RAID_HINT")), nil, nil, nil, true)
		GameTooltip:Show()
	end)
	legendCol:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	page.legendCol = legendCol
	page.gradeLegendLabel = gradeLegend

	local statsCol = CreateHeaderColumn()
	local stats = FillColumnText(statsCol, "GameFontNormalSmall")
	W.SetFontColor(stats, UI.TEXT_IDLE)
	stats:SetText(FormatRaidRosterStatsCompact(nil, {}))
	statsCol:EnableMouse(true)
	statsCol:SetScript("OnEnter", function(self)
		ShowRosterStatsTooltip(self, page)
	end)
	statsCol:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	page.statsCol = statsCol
	page.statsLabel = stats

	local summaryCol = CreateHeaderColumn()
	page.summaryBand = summaryCol

	local function CreateChatReportButton(parent, tooltipKey, buildMessages, onClick)
		local button = W.CreatePlainButton(parent, iconSize, iconSize, "")
		if button.label then
			button.label:Hide()
		end
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("CENTER", 0, 0)
		icon:SetSize(iconSize - 4, iconSize - 4)
		W.SetSpellIconTexture(icon, RAID_REPORT_ICON)
		button.icon = icon
		SetChatReportButtonTooltip(button, tooltipKey, buildMessages)
		button:SetScript("OnClick", onClick)
		return button
	end

	local function CreateSummaryCell(tooltipKey, buildMessages, onClick)
		local cell = CreateFrame("Frame", nil, summaryCol)
		local reportBtn = CreateChatReportButton(cell, tooltipKey, buildMessages, onClick)
		reportBtn:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		local body = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
		body:SetPoint("LEFT", cell, "LEFT", 0, 0)
		body:SetPoint("RIGHT", reportBtn, "LEFT", -iconGap, 0)
		body:SetHeight(row2H)
		body:SetJustifyH("LEFT")
		body:SetJustifyV("MIDDLE")
		body:SetWordWrap(false)
		body:SetNonSpaceWrap(false)
		cell.body = body
		cell.reportBtn = reportBtn
		SetSummaryCellTooltip(cell)
		return cell
	end

	local flaskCol = CreateSummaryCell("BTN_RAID_REPORT_FLASK_TIP", function()
		return BuildMissingConsumableMessages("flask")
	end, function()
		ReportMissingConsumablesToChat("flask")
	end)
	page.flaskCol = flaskCol
	page.flaskSummaryLabel = flaskCol.body
	page.reportFlaskBtn = flaskCol.reportBtn

	local foodCol = CreateSummaryCell("BTN_RAID_REPORT_FOOD_TIP", function()
		return BuildMissingConsumableMessages("food")
	end, function()
		ReportMissingConsumablesToChat("food")
	end)
	page.foodCol = foodCol
	page.foodSummaryLabel = foodCol.body
	page.reportFoodBtn = foodCol.reportBtn

	local gearGradeCol = CreateSummaryCell("BTN_RAID_REPORT_GEAR_TIP", function()
		return BuildGearCategoryMessages("gear")
	end, function()
		ReportGearCategoryToChat("gear")
	end)
	page.gearGradeCol = gearGradeCol
	page.gearGradeSummaryLabel = gearGradeCol.body
	page.reportGearBtn = gearGradeCol.reportBtn

	local enchantGradeCol = CreateSummaryCell("BTN_RAID_REPORT_ENCHANT_TIP", function()
		return BuildGearCategoryMessages("enchant")
	end, function()
		ReportGearCategoryToChat("enchant")
	end)
	page.enchantGradeCol = enchantGradeCol
	page.enchantGradeSummaryLabel = enchantGradeCol.body
	page.reportEnchantBtn = enchantGradeCol.reportBtn

	local summaryRows = { flaskCol, foodCol, gearGradeCol, enchantGradeCol }

	local toolbar = CreateHeaderColumn()
	page.raidToolbar = toolbar

	local scanBtn = W.CreatePlainIconButton(
		toolbar,
		row1H,
		RAID_TOOLBAR_SCAN_ICON,
		"GEAR_CHECK_SCAN",
		"RAID_SCAN_TIP"
	)
	local exportBtn = W.CreatePlainIconButton(
		toolbar,
		row1H,
		RAID_TOOLBAR_EXPORT_ICON,
		"GEAR_CHECK_RAID_EXPORT",
		"GEAR_CHECK_RAID_EXPORT_TIP"
	)

	local refreshBtn = W.CreatePlainIconButton(
		toolbar,
		row1H,
		RAID_TOOLBAR_REFRESH_ICON,
		"BTN_REFRESH",
		"RAID_REFRESH_TIP"
	)
	refreshBtn:SetScript("OnClick", function()
		Addon:RefreshPartyData(true)
	end)

	local textViewBtn = W.CreatePlainIconButton(
		toolbar,
		row1H,
		RAID_TOOLBAR_BACK_ICON,
		"BTN_RAID_BACK_TO_ROSTER",
		"BTN_RAID_BACK_TO_ROSTER_TIP"
	)
	textViewBtn:Disable()

	page.gearCheckScanBtn = scanBtn
	page.gearCheckExportBtn = exportBtn
	page.refreshBtn = refreshBtn
	page.textViewBtn = textViewBtn

	local toolbarBtns = { scanBtn, exportBtn, refreshBtn, textViewBtn }

	local function LayoutRaidMiniTable()
		local toolbarW = row1H * btnCount + btnGap * (btnCount - 1)
		toolbar:ClearAllPoints()
		toolbar:SetSize(toolbarW, row1H)
		toolbar:SetPoint("TOPRIGHT", miniTable, "TOPRIGHT", 0, 0)

		local chipW = math.max(UI.RAID_GRADE_CHIPS_W or 72, (gradeLegend:GetStringWidth() or 72) + 4)
		legendCol:ClearAllPoints()
		legendCol:SetSize(chipW, row1H)
		legendCol:SetPoint("TOPLEFT", miniTable, "TOPLEFT", 0, 0)

		statsCol:ClearAllPoints()
		statsCol:SetHeight(row1H)
		statsCol:SetPoint("TOPLEFT", legendCol, "TOPRIGHT", colGap, 0)
		statsCol:SetPoint("TOPRIGHT", toolbar, "TOPLEFT", -colGap, 0)

		summaryCol:ClearAllPoints()
		summaryCol:SetHeight(row2H)
		summaryCol:SetPoint("TOPLEFT", legendCol, "BOTTOMLEFT", 0, -rowGap)
		summaryCol:SetPoint("RIGHT", miniTable, "RIGHT", 0, 0)

		local cellW = EqualColumnWidth(summaryCol:GetWidth() or 1, summaryCount, colGap)
		for index = 1, #summaryRows do
			local cell = summaryRows[index]
			cell:ClearAllPoints()
			cell:SetSize(cellW, row2H)
			cell:SetPoint("TOPLEFT", summaryCol, "TOPLEFT", (index - 1) * (cellW + colGap), 0)
		end
		for index = 1, #toolbarBtns do
			local button = toolbarBtns[index]
			button:ClearAllPoints()
			button:SetSize(row1H, row1H)
			button:SetPoint("TOPLEFT", toolbar, "TOPLEFT", (index - 1) * (row1H + btnGap), 0)
		end
	end
	miniTable:SetScript("OnSizeChanged", function()
		LayoutRaidMiniTable()
	end)
	LayoutRaidMiniTable()

	local gearCheckStatusLabel = W.CreateFontString(headerHost, nil, "OVERLAY", "GameFontNormalSmall")
	gearCheckStatusLabel:SetPoint("TOPLEFT", miniTable, "BOTTOMLEFT", 0, -UI.RAID_DESC_BLOCK_GAP)
	gearCheckStatusLabel:SetPoint("RIGHT", headerHost, "RIGHT", 0, 0)
	gearCheckStatusLabel:SetHeight(UI.RAID_PROGRESS_STATUS_H)
	gearCheckStatusLabel:SetJustifyH("LEFT")
	gearCheckStatusLabel:SetJustifyV("TOP")
	gearCheckStatusLabel:SetWordWrap(true)
	gearCheckStatusLabel:SetNonSpaceWrap(false)
	gearCheckStatusLabel:SetText("")
	W.SetFontColor(gearCheckStatusLabel, UI.TEXT_IDLE)
	page.gearCheckStatusLabel = gearCheckStatusLabel

	local progressHost = W.CreateProgressBar(headerHost, UI.RAID_PROGRESS_H)
	progressHost:SetPoint("TOPLEFT", gearCheckStatusLabel, "BOTTOMLEFT", 0, -UI.RAID_PROGRESS_STATUS_GAP)
	progressHost:SetPoint("RIGHT", headerHost, "RIGHT", 0, 0)
	progressHost:Show()
	page.gearCheckProgressHost = progressHost

	return headerHost
end

local function SetRaidProgress(page, value, maxValue, visible)
	local host = page and page.gearCheckProgressHost
	if not host then
		return
	end
	if visible then
		host:SetProgress(value, maxValue)
	else
		host:SetProgress(0, 1)
	end
end

local function RaidScanPhaseLabel(phase)
	local key = phase and SCAN_PHASE_KEYS[phase]
	if key then
		return W.T(key)
	end
	return W.T("GEAR_CHECK_RAID_PHASE_INSPECT")
end

local function PageGearActionsBusy(page)
	return page
		and (page.gearCheckScanning or page.gearCheckExporting or page.gearCheckMemberScanning)
end

local function SetRaidProgressIdleText(page)
	if not page or not page.gearCheckStatusLabel or PageGearActionsBusy(page) then
		return
	end
	if page.exportViewMode then
		page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_EXPORT_READY"))
		return
	end
	if page.lastFullScanAt then
		page.gearCheckStatusLabel:SetText(W.T(
			"GEAR_CHECK_RAID_STATUS_DONE",
			page.lastFullScanCount,
			date("%d %b %H:%M:%S", page.lastFullScanAt)
		))
		return
	end
	page.gearCheckStatusLabel:SetText("")
end

local function UpdateRaidExportActionButtons(page, busy)
	if not page then
		return
	end
	if busy == nil then
		busy = PageGearActionsBusy(page)
	end
	local exportOpen = page.exportViewMode == true
	if page.textViewBtn then
		if busy or not exportOpen then
			page.textViewBtn:Disable()
		else
			page.textViewBtn:Enable()
		end
	end
end

local function UpdateRaidExportView(page)
	if not page then
		return
	end
	local show = page.exportViewMode == true
	if page.tableHost then
		if show then
			page.tableHost:Hide()
		else
			page.tableHost:Show()
		end
	end
	if page.exportCopyHost then
		if show then
			page.exportCopyHost:Show()
		else
			page.exportCopyHost:Hide()
		end
	end
	UpdateRaidExportActionButtons(page)
end

local function ShowRaidExportText(page, text)
	if not page or not page.exportDumpBox then
		return false
	end
	page.exportDumpBox:SetText(text or "")
	page.exportViewMode = true
	UpdateRaidExportView(page)
	if W.FitCopyBoxToText then
		W.FitCopyBoxToText(page.exportDumpBox)
	end
	if (text or "") ~= "" then
		page.exportDumpBox:SetFocus()
		page.exportDumpBox:HighlightText()
	end
	if page.gearCheckStatusLabel then
		page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_EXPORT_READY"))
	end
	return true
end

function Addon:ShowRaidGearCheckExportText(text)
	local frame = self.mainFrame
	local page = frame and frame.pages and frame.pages.raid
	if not page then
		return false
	end
	self:ShowMainFrame()
	if frame.selectedTab ~= "raid" then
		self:SelectTab("raid")
	end
	return ShowRaidExportText(page, text)
end

local function ExitRaidExportView(page)
	if not page or not page.exportViewMode then
		return
	end
	page.exportViewMode = false
	UpdateRaidExportView(page)
	SetRaidProgressIdleText(page)
end

local function SetRaidBusyButtons(page, busy)
	if page.gearCheckScanBtn then
		if busy then
			page.gearCheckScanBtn:Disable()
		else
			page.gearCheckScanBtn:Enable()
		end
	end
	if page.gearCheckExportBtn then
		if busy then
			page.gearCheckExportBtn:Disable()
		else
			page.gearCheckExportBtn:Enable()
		end
	end
	UpdateRaidExportActionButtons(page, busy)
	local blocks = { page.topBlock, page.bottomBlock }
	for blockIndex = 1, #blocks do
		local block = blocks[blockIndex]
		if block and block.columns then
			for _, column in pairs(block.columns) do
				for slot = 1, 5 do
					local cell = column.cells and column.cells[slot]
					if cell and cell.rescanBtn and cell.member then
						if busy then
							cell.rescanBtn:Disable()
						else
							cell.rescanBtn:Enable()
						end
					end
				end
			end
		end
	end
end

local function UpsertRaidGearResult(page, entry)
	if not page or not entry or not entry.member then
		return
	end
	local results = page.gearCheckResults
	if type(results) ~= "table" then
		results = {}
		page.gearCheckResults = results
	end

	local member = entry.member
	local character = entry.report and entry.report.character or {}
	local guid = member.guid or character.guid
	local name = member.name or character.name
	local replaced = false
	for index = 1, #results do
		local existing = results[index]
		local existingMember = existing and existing.member or {}
		local existingCharacter = existing and existing.report and existing.report.character or {}
		local existingGuid = existingMember.guid or existingCharacter.guid
		local existingName = existingMember.name or existingCharacter.name
		if guid and existingGuid and guid == existingGuid then
			results[index] = entry
			replaced = true
			break
		end
		if name and existingName and name == existingName then
			results[index] = entry
			replaced = true
			break
		end
	end
	if not replaced then
		results[#results + 1] = entry
	end
	if Addon.SetLastGearCheckRaidResults then
		Addon:SetLastGearCheckRaidResults(results)
	end
end

local function MembersFromRaidGroups(groups)
	local members = {}
	if type(groups) ~= "table" then
		return members
	end
	for groupIndex = 1, 8 do
		local slots = groups[groupIndex]
		if slots then
			for slot = 1, #slots do
				members[#members + 1] = slots[slot]
			end
		end
	end
	return members
end

local function RaidColumnOffset(columnIndex)
	return (columnIndex - 1) * (RAID_CELL_W + RAID_CELL_GAP)
end

local function RaidBlockHeight()
	return RAID_GROUP_LABEL_H + RAID_CELL_H * 5 + RAID_CELL_GAP * 4
end

local function RaidContentSize()
	local width = RAID_CELL_W * 5 + RAID_CELL_GAP * 4
	local height = RaidBlockHeight() * 2 + RAID_BLOCK_GAP
	return width, height
end

local function CreateRaidPlayerCell(parent)
	local cell = CreateFrame("Button", nil, parent)
	cell:SetSize(RAID_CELL_W, RAID_CELL_H)
	W.ApplyPlainPanel(cell, UI.CD_ROW_A)
	cell:EnableMouse(true)
	cell:RegisterForClicks("LeftButtonUp")

	cell.classIconHost = CreateFrame("Frame", nil, cell)
	cell.classIconHost:SetSize(RAID_ICON, RAID_ICON)
	cell.classIconHost:SetPoint("TOPLEFT", RAID_CELL_PAD, -RAID_CELL_PAD)
	cell.classIcon = cell.classIconHost:CreateTexture(nil, "ARTWORK")
	cell.classIcon:SetAllPoints(cell.classIconHost)

	cell.foodHost = W.CreateConsumableStatusHost(cell)
	cell.foodHost:SetPoint("TOPRIGHT", -RAID_CELL_PAD, -RAID_CELL_PAD)
	cell.flaskHost = W.CreateConsumableStatusHost(cell)
	cell.flaskHost:SetPoint("RIGHT", cell.foodHost, "LEFT", -UI.PARTY_BUFF_GAP, 0)

	cell.nameText = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	cell.nameText:SetPoint("LEFT", cell.classIconHost, "RIGHT", 4, 0)
	cell.nameText:SetPoint("RIGHT", cell.flaskHost, "LEFT", -4, 0)
	cell.nameText:SetHeight(RAID_LINE_H)
	cell.nameText:SetJustifyH("LEFT")
	cell.nameText:SetJustifyV("MIDDLE")

	cell.roleIconHost = CreateFrame("Frame", nil, cell)
	cell.roleIconHost:SetSize(RAID_ICON, RAID_ICON)
	cell.roleIconHost:SetPoint("TOPLEFT", cell.classIconHost, "BOTTOMLEFT", 0, -3)
	cell.roleIcon = cell.roleIconHost:CreateTexture(nil, "ARTWORK")
	cell.roleIcon:SetAllPoints(cell.roleIconHost)
	cell.roleIconHost:EnableMouse(true)
	cell.roleIconHost:SetScript("OnEnter", function(self)
		if not cell.roleLabel or cell.roleLabel == "" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(cell.roleLabel)
		GameTooltip:Show()
	end)
	cell.roleIconHost:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	cell.specIconHost = CreateFrame("Frame", nil, cell)
	cell.specIconHost:SetSize(RAID_ICON, RAID_ICON)
	cell.specIconHost:SetPoint("LEFT", cell.roleIconHost, "RIGHT", 3, 0)
	cell.specIcon = cell.specIconHost:CreateTexture(nil, "ARTWORK")
	cell.specIcon:SetAllPoints(cell.specIconHost)

	cell.statsText = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	cell.statsText:SetPoint("LEFT", cell.specIconHost, "RIGHT", 4, 0)
	cell.statsText:SetPoint("RIGHT", cell, "RIGHT", -RAID_CELL_PAD, 0)
	cell.statsText:SetHeight(RAID_LINE_H)
	cell.statsText:SetJustifyH("LEFT")
	cell.statsText:SetJustifyV("MIDDLE")

	cell.opinionText = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	cell.opinionText:SetPoint("TOPLEFT", cell.roleIconHost, "BOTTOMLEFT", 0, -2)
	cell.opinionText:SetPoint("RIGHT", cell, "RIGHT", -RAID_CELL_PAD, 0)
	cell.opinionText:SetHeight(RAID_LINE_H)
	cell.opinionText:SetJustifyH("LEFT")

	cell.gradesText = W.CreateFontString(cell, nil, "OVERLAY", "GameFontNormalSmall")
	cell.gradesText:SetPoint("TOPLEFT", cell.opinionText, "BOTTOMLEFT", 0, -1)
	cell.gradesText:SetPoint("RIGHT", cell, "RIGHT", -RAID_CELL_PAD, 0)
	cell.gradesText:SetHeight(RAID_LINE_H)
	cell.gradesText:SetJustifyH("LEFT")

	local reportSize = RAID_BTN_H
	local btnWidth = math.floor((RAID_CELL_W - RAID_CELL_PAD * 2 - RAID_BTN_GAP * 3 - reportSize * 2) / 2)
	local gearBtn = W.CreatePlainButton(cell, btnWidth, RAID_BTN_H, W.T("BTN_RAID_GEAR"))
	gearBtn:SetPoint("BOTTOMLEFT", RAID_CELL_PAD, RAID_CELL_PAD)
	W.SetPlainButtonTooltip(gearBtn, "BTN_RAID_GEAR_TIP")
	gearBtn:SetScript("OnClick", function()
		local gearEntry = cell.gearEntry
		if gearEntry and gearEntry.report and Addon.ShowGearCheckReport then
			Addon:ShowGearCheckReport(gearEntry.report, gearEntry.status or "ok")
		end
	end)
	gearBtn:Hide()
	cell.gearBtn = gearBtn

	local rescanBtn = W.CreatePlainButton(cell, btnWidth, RAID_BTN_H, W.T("BTN_RAID_RESCAN"))
	rescanBtn:SetPoint("LEFT", gearBtn, "RIGHT", RAID_BTN_GAP, 0)
	W.SetPlainButtonTooltip(rescanBtn, "BTN_RAID_RESCAN_TIP")
	rescanBtn:SetScript("OnClick", function()
		local frame = Addon.mainFrame
		local page = frame and frame.pages and frame.pages.raid
		if page and cell.member then
			Addon:RunGearCheckMemberRescan(page, cell.member)
		end
	end)
	rescanBtn:Hide()
	cell.rescanBtn = rescanBtn

	cell.issueReportButtons = {}
	local previous = rescanBtn
	for _, category in ipairs({ "gear", "enchant" }) do
		local reportCategory = category
		local button = W.CreatePlainButton(cell, reportSize, reportSize, "")
		button:SetPoint("LEFT", previous, "RIGHT", RAID_BTN_GAP, 0)
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("CENTER", 0, 0)
		icon:SetSize(reportSize - 2, reportSize - 2)
		W.SetSpellIconTexture(icon, category == "gear" and "Interface\\Icons\\INV_Sword_04" or "Interface\\Icons\\INV_Misc_Gem_Diamond_01")
		local function BuildMessages()
			return Addon:FormatGearCheckMemberIssues(cell.gearEntry and cell.gearEntry.report, reportCategory)
		end
		SetChatReportButtonTooltip(button, category == "gear" and "BTN_RAID_MEMBER_GEAR_REPORT_TIP" or "BTN_RAID_MEMBER_ENCHANT_REPORT_TIP", BuildMessages)
		button:SetScript("OnClick", function()
			SendRaidChatMessages(BuildMessages())
		end)
		button:Hide()
		cell.issueReportButtons[#cell.issueReportButtons + 1] = button
		previous = button
	end

	cell:SetScript("OnEnter", function(self)
		if not self.member then
			return
		end
		W.SetBackdropColor(self, UI.BTN_HOVER)
		W.ShowMemberRatingTooltip(self, self.member, {
			gearCheck = true,
			gearEntry = self.gearEntry,
			raidBuffs = self.member.raidBuffs,
		})
	end)
	cell:SetScript("OnLeave", function(self)
		local stripe = self.stripe or UI.CD_ROW_A
		W.SetBackdropColor(self, stripe)
		GameTooltip:Hide()
	end)
	cell:SetScript("OnClick", function(self)
		if self.member then
			Addon:ShowRaidCharacterWindow(self.member)
		end
	end)

	return cell
end

local function CollectGroupMembers(slots)
	local members = {}
	if not slots then
		return members
	end
	for slot = 1, 5 do
		local member = slots[slot]
		if member then
			members[#members + 1] = member
		end
	end
	return members
end

local function UpdateRaidGroupHeader(column, slots)
	if not column then
		return
	end
	local coverage
	if Addon.PartyBuffCoverageForGroup then
		coverage = Addon:PartyBuffCoverageForGroup(CollectGroupMembers(slots))
	end
	W.FillPartyBuffStatusIcons(column.partyBuffHosts, coverage)
end

local function CreateRaidGroupColumn(parent, groupIndex)
	local column = CreateFrame("Frame", nil, parent)
	column:SetSize(RAID_CELL_W, RaidBlockHeight())

	local header = CreateFrame("Frame", nil, column)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", 0, 0)
	header:SetHeight(RAID_GROUP_LABEL_H)
	column.header = header

	local label = W.CreateFontString(header, nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", 0, 0)
	label:SetWidth(10)
	label:SetHeight(RAID_GROUP_LABEL_H)
	label:SetJustifyH("LEFT")
	label:SetText(tostring(groupIndex))
	W.SetFontColor(label, UI.GOLD)
	column.label = label

	column.partyBuffHosts = {}
	for buffIndex = 1, UI.PARTY_BUFF_MAX do
		local host = W.CreatePartyBuffStatusHost(header)
		if buffIndex == 1 then
			host:SetPoint("LEFT", label, "RIGHT", 2, 0)
		else
			host:SetPoint("LEFT", column.partyBuffHosts[buffIndex - 1], "RIGHT", UI.PARTY_BUFF_GAP, 0)
		end
		column.partyBuffHosts[buffIndex] = host
	end

	column.cells = {}
	for slot = 1, 5 do
		local cell = CreateRaidPlayerCell(column)
		cell:SetPoint("TOPLEFT", 0, -(RAID_GROUP_LABEL_H + (slot - 1) * (RAID_CELL_H + RAID_CELL_GAP)))
		column.cells[slot] = cell
	end

	return column
end

local function CreateRaidBlock(parent, startGroup, endGroup)
	local columnCount = endGroup - startGroup + 1
	local block = CreateFrame("Frame", nil, parent)
	block:SetSize(
		RAID_CELL_W * columnCount + RAID_CELL_GAP * (columnCount - 1),
		RaidBlockHeight()
	)

	block.columns = {}
	for groupIndex = startGroup, endGroup do
		local column = CreateRaidGroupColumn(block, groupIndex)
		column:SetPoint("TOPLEFT", RaidColumnOffset(groupIndex - startGroup + 1), 0)
		block.columns[groupIndex] = column
	end

	return block
end

local function FillGearReportRows(cell, member, entry)
	if not member then
		cell.gearEntry = nil
		cell.gradesText:SetText("")
		if cell.gearBtn then
			cell.gearBtn:Disable()
		end
		return
	end

	cell.gearEntry = entry
	local report = entry and entry.report
	local character = report and report.character or {}

	if not report then
		local statusLabel = GearStatusLabelForEntry(entry)
		cell.gradesText:SetText(statusLabel)
		if IsGearVerdictLabel(statusLabel) then
			cell.gradesText:SetText(W.WrapGearGradation(statusLabel))
			W.SetFontColor(cell.gradesText, UI.TEXT_IDLE)
		else
			W.SetFontColor(cell.gradesText, UI.GOLD)
		end
		if cell.gearBtn then
			cell.gearBtn:Disable()
		end
		return
	end

	local overall = report.overall or {}
	local gearGrade = overall.gearGrade or overall.status or "B"
	local enchantSocketGrade = overall.enchantSocketGrade or "B"
	cell.gradesText:SetText(Addon:GetGearCheckScanLabel(report) or FormatCompactGradesLine(gearGrade, enchantSocketGrade))
	W.SetFontColor(cell.gradesText, UI.TEXT_IDLE)

	if cell.gearBtn then
		cell.gearBtn:Enable()
	end

	if report and character.specIcon and character.specIcon ~= "" and member.specIcon ~= character.specIcon then
		W.SetSpecOrClassIcon(cell.specIcon, character.specIcon, member.class)
		cell.specIcon:Show()
	end
end

local function FillRaidConsumableIcons(cell, member)
	if not cell or not cell.flaskHost or not cell.foodHost then
		return
	end
	if not member or not member.unit or not Addon.UnitConsumableStatus then
		if cell.flaskHost then
			cell.flaskHost:Hide()
		end
		if cell.foodHost then
			cell.foodHost:Hide()
		end
		return
	end
	local status = Addon:UnitConsumableStatus(member.unit)
	W.FillConsumableStatusIcon(cell.flaskHost, status and status.flask, "RAID_CONSUMABLE_FLASK")
	W.FillConsumableStatusIcon(cell.foodHost, status and status.food, "RAID_CONSUMABLE_FOOD")
end

local function FillRaidPlayerCell(cell, member, gearEntry, stripe)
	local offline = member and member.unit and UnitIsConnected and not UnitIsConnected(member.unit)
	local unscanned = member and not (gearEntry and gearEntry.report)
	if offline then
		stripe = UI.BTN_DISABLED
	elseif unscanned then
		stripe = UI.BTN_SELECTED
	end
	cell.stripe = stripe
	W.SetBackdropColor(cell, stripe)
	-- Cells are reused as the roster changes; restore icons when a player reconnects.
	for _, icon in ipairs({ cell.classIcon, cell.roleIcon, cell.specIcon }) do
		icon:SetDesaturated(offline and true or false)
		icon:SetAlpha(offline and 0.5 or 1)
	end

	if not member then
		cell.member = nil
		cell.roleLabel = nil
		cell.nameText:SetText("")
		cell.statsText:SetText("")
		cell.opinionText:SetText("")
		cell.classIconHost:Hide()
		cell.roleIconHost:Hide()
		cell.specIconHost:Hide()
		FillRaidConsumableIcons(cell, nil)
		FillGearReportRows(cell, nil, nil)
		for _, button in ipairs(cell.issueReportButtons or {}) do
			button:Hide()
		end
		if cell.gearBtn then
			cell.gearBtn:Hide()
		end
		if cell.rescanBtn then
			cell.rescanBtn:Hide()
		end
		cell:EnableMouse(false)
		cell:Show()
		return
	end

	cell.member = member
	cell:EnableMouse(true)
	cell.nameText:SetText(member.name or "")
	cell.nameText:SetTextColor(W.ClassColor(member.class))
	if offline then
		W.SetFontColor(cell.nameText, UI.TEXT_DISABLED)
	end
	W.SetSpecOrClassIcon(cell.classIcon, nil, member.class)
	cell.classIconHost:Show()

	local role = member.role or "unknown"
	cell.roleLabel = (Addon.RaidRoleLabel and Addon:RaidRoleLabel(role)) or ""
	if Addon.RaidRoleIcon then
		W.SetSpellIconTexture(cell.roleIcon, Addon:RaidRoleIcon(role))
	else
		W.SetSpellIconTexture(cell.roleIcon, "Interface\\Icons\\INV_Misc_QuestionMark")
	end
	cell.roleIconHost:Show()

	if member.specIcon and member.specIcon ~= "" then
		W.SetSpecOrClassIcon(cell.specIcon, member.specIcon, member.class)
		cell.specIcon:Show()
	else
		cell.specIcon:SetTexture(nil)
		cell.specIcon:Hide()
	end
	cell.specIconHost:Show()

	local stats = FormatRaidStatsLine(member.gearScore, member.averageIlvl)
	cell.statsText:SetText(stats)
	if offline then
		cell.statsText:SetText(W.T("RAID_CONSUMABLE_OFFLINE"))
		W.SetFontColor(cell.statsText, UI.TEXT_DISABLED)
	elseif member.gearScore then
		W.SetFontColor(cell.statsText, UI.GOLD)
	else
		W.SetFontColor(cell.statsText, UI.TEXT_IDLE)
	end

	FillRaidConsumableIcons(cell, member)

	-- Embedded colors mark ratings; uncolored separators use the theme body color.
	cell.opinionText:SetText(FormatRatingCellLine(member))
	W.SetFontColor(cell.opinionText, UI.TEXT_BODY)

	FillGearReportRows(cell, member, gearEntry)
	for _, button in ipairs(cell.issueReportButtons or {}) do
		button:Show()
		if gearEntry and gearEntry.report then
			button:Enable()
		else
			button:Disable()
		end
	end
	if cell.gearBtn then
		cell.gearBtn:Show()
	end
	if cell.rescanBtn then
		cell.rescanBtn:Show()
		local frame = Addon.mainFrame
		local page = frame and frame.pages and frame.pages.raid
		if PageGearActionsBusy(page) then
			cell.rescanBtn:Disable()
		else
			cell.rescanBtn:Enable()
		end
	end
	cell:Show()
end

local function RunGearCheckRaidScan(page)
	if not Addon.StartGearCheckRaidScan then
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_STATUS_FAIL"))
		end
		return
	end
	if page.gearCheckExporting or page.gearCheckMemberScanning then
		return
	end
	if Addon.IsGearCheckScanBusy and Addon:IsGearCheckScanBusy() then
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_BUSY"))
		end
		return
	end
	SetRaidBusyButtons(page, true)
	ExitRaidExportView(page)
	if page.gearCheckStatusLabel then
		page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_STATUS_SCANNING"))
	end
	SetRaidProgress(page, 0, 1, true)
	page.gearCheckScanning = true
	page.gearCheckResults = {}

	local started = Addon:StartGearCheckRaidScan(
		function(entry, done, total)
			local name = (entry and entry.member and entry.member.name) or "?"
			local phase = entry and entry.phase
			if entry and entry.live then
				if page.gearCheckStatusLabel then
					page.gearCheckStatusLabel:SetText(
						W.T(
							"GEAR_CHECK_RAID_STATUS_SCANNING_PHASE",
							done,
							total,
							name,
							RaidScanPhaseLabel(phase)
						)
					)
				end
				-- Live update: current player in progress counts as a half step.
				SetRaidProgress(page, done + 0.5, total, true)
				return
			end
			if page.gearCheckStatusLabel then
				page.gearCheckStatusLabel:SetText(
					W.T("GEAR_CHECK_RAID_STATUS_SCANNING", done, total, name)
				)
			end
			SetRaidProgress(page, done, total, true)
			page.gearCheckResults[#page.gearCheckResults + 1] = entry
			Addon:ScheduleRosterRefresh(false)
		end,
		function(results, status)
			page.gearCheckScanning = false
			page.gearCheckResults = results
			SetRaidBusyButtons(page, false)
			SetRaidProgress(page, 0, 1, false)
			if status == "ok" then
				page.lastFullScanAt = time()
				page.lastFullScanCount = #results
			end
			if page.gearCheckStatusLabel then
				if status == "empty" then
					page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_EMPTY"))
				elseif status == "ok" then
					SetRaidProgressIdleText(page)
				else
					page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_STATUS_FAIL"))
				end
			end
			Addon:ScheduleRosterRefresh(false)
		end
	)
	if not started then
		page.gearCheckScanning = false
		SetRaidBusyButtons(page, false)
		SetRaidProgress(page, 0, 1, false)
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_BUSY"))
		end
	end
end

function Addon:RunGearCheckMemberRescan(page, member)
	if not page or not member or not member.unit then
		return false
	end
	if page.gearCheckScanning or page.gearCheckExporting or page.gearCheckMemberScanning then
		return false
	end
	if Addon.IsGearCheckScanBusy and Addon:IsGearCheckScanBusy() then
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_BUSY"))
		end
		return false
	end
	if not Addon.StartGearCheckUnitScan then
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_STATUS_FAIL"))
		end
		return false
	end

	page.gearCheckMemberScanning = true
	SetRaidBusyButtons(page, true)
	ExitRaidExportView(page)
	SetRaidProgress(page, 0.5, 1, true)
	if page.gearCheckStatusLabel then
		page.gearCheckStatusLabel:SetText(
			W.T("GEAR_CHECK_RAID_STATUS_RESCANNING", member.name or "?")
		)
	end

	local started = Addon:StartGearCheckUnitScan(member.unit, function(report, status)
		page.gearCheckMemberScanning = false
		SetRaidBusyButtons(page, false)
		SetRaidProgress(page, 0, 1, false)
		UpsertRaidGearResult(page, {
			member = member,
			report = report,
			status = status or (report and "ok") or "failed",
			phase = "done",
		})
		if page.gearCheckStatusLabel then
			if report then
				page.gearCheckStatusLabel:SetText(
					W.T("GEAR_CHECK_RAID_STATUS_RESCAN_DONE", member.name or "?")
				)
			else
				page.gearCheckStatusLabel:SetText(
					W.T("GEAR_CHECK_RAID_STATUS_RESCAN_FAIL", member.name or "?")
				)
			end
		end
		Addon:ScheduleRosterRefresh(false)
	end)

	if not started then
		page.gearCheckMemberScanning = false
		SetRaidBusyButtons(page, false)
		SetRaidProgress(page, 0, 1, false)
		if page.gearCheckStatusLabel then
			page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_BUSY"))
		end
		return false
	end
	return true
end

local function RunGearCheckRaidExport(page)
	if page.gearCheckScanning or page.gearCheckExporting or page.gearCheckMemberScanning then
		return
	end
	if Addon.IsGearCheckRaidDumpBusy and Addon:IsGearCheckRaidDumpBusy() then
		return
	end
	local results = ResolveGearCheckResults(page)
	if type(results) ~= "table" or #results == 0 then
		Addon:Print(W.T("GEAR_CHECK_RAID_EXPORT_EMPTY"))
		return
	end
	if not Addon.BuildGearCheckRaidDumpAsync then
		if Addon.ShowGearCheckRaidDump then
			Addon:ShowGearCheckRaidDump(results)
		end
		return
	end

	page.gearCheckExporting = true
	SetRaidBusyButtons(page, true)
	SetRaidProgress(page, 0, #results, true)
	if page.gearCheckStatusLabel then
		page.gearCheckStatusLabel:SetText(W.T("GEAR_CHECK_RAID_STATUS_EXPORTING", 0, #results))
	end

	local started = Addon:BuildGearCheckRaidDumpAsync(
		results,
		function(done, total, member)
			if page.gearCheckStatusLabel then
				page.gearCheckStatusLabel:SetText(
					W.T(
						"GEAR_CHECK_RAID_STATUS_EXPORTING_PHASE",
						done,
						total,
						(member and member.name) or "?",
						RaidScanPhaseLabel("export")
					)
				)
			end
			SetRaidProgress(page, done, total, true)
		end,
		function(text)
			page.gearCheckExporting = false
			SetRaidBusyButtons(page, false)
			SetRaidProgress(page, 0, 1, false)
			SetRaidProgressIdleText(page)
			if not text or text == "" then
				if text == "" then
					Addon:Print(W.T("GEAR_CHECK_RAID_EXPORT_EMPTY"))
				end
				return
			end
			-- Defer SetText to the next frame so the progress bar can clear first.
			local pendingText = text
			local defer = CreateFrame("Frame")
			defer:SetScript("OnUpdate", function(self)
				self:SetScript("OnUpdate", nil)
				if Addon.ShowRaidGearCheckExportText then
					Addon:ShowRaidGearCheckExportText(pendingText)
				elseif Addon.ShowGearCheckDumpText then
					Addon:ShowGearCheckDumpText(pendingText)
				else
					Addon:Print(W.T("GEAR_CHECK_STATUS_FAIL"))
				end
			end)
		end
	)
	if not started then
		page.gearCheckExporting = false
		SetRaidBusyButtons(page, false)
		SetRaidProgress(page, 0, 1, false)
		if Addon.ShowGearCheckRaidDump then
			Addon:ShowGearCheckRaidDump(results)
		end
	end
end

function Addon:RefreshGearCheckRaidView(_autoScan)
	self:RefreshRaidRosterView(false)
end

function Addon:RefreshRaidRosterView(refreshGearScore, snapshot)
	local frame = self.mainFrame
	local page = frame and frame.pages and frame.pages.raid
	if not page then
		return
	end

	if not self.BuildRaidGroups then
		if page.statsLabel then
			page.statsLabel:SetText(W.T("RAID_FAIL"))
		end
		return
	end

	local groups = snapshot and snapshot.groups or self:BuildRaidGroups(refreshGearScore)
	local members = MembersFromRaidGroups(groups)
	UpdateRaidRosterStatsLabels(page, members)
	UpdateRaidConsumableSummary(page, members)

	local results = ResolveGearCheckResults(page)
	UpdateRaidGradeSummaries(page, results)
	local byGuid, byName = IndexGearResults(results)

	local blocks = { page.topBlock, page.bottomBlock }
	for blockIndex = 1, #blocks do
		local block = blocks[blockIndex]
		for groupIndex, column in pairs(block.columns) do
			local slots = groups[groupIndex] or {}
			UpdateRaidGroupHeader(column, slots)
			for slot = 1, 5 do
				local stripe = (slot % 2 == 1) and UI.CD_ROW_A or UI.CD_ROW_B
				local member = slots[slot]
				FillRaidPlayerCell(column.cells[slot], member, GearEntryForMember(member, byGuid, byName), stripe)
			end
		end
	end

	local contentW, contentH = RaidContentSize()
	page.tableContent:SetSize(contentW, contentH)
	W.LayoutTableScrollBars(page)
	UpdateRaidExportView(page)
end

function Addon:RefreshRaidConsumableIcons()
	local frame = self.mainFrame
	local page = frame and frame.pages and frame.pages.raid
	if not frame or not frame:IsShown() or frame.selectedTab ~= "raid" or not page then
		return
	end
	local blocks = { page.topBlock, page.bottomBlock }
	for blockIndex = 1, #blocks do
		local block = blocks[blockIndex]
		if block and block.columns then
			for _, column in pairs(block.columns) do
				for slot = 1, 5 do
					local cell = column.cells and column.cells[slot]
					if cell then
						FillRaidConsumableIcons(cell, cell.member)
					end
				end
			end
		end
	end
	UpdateRaidConsumableSummary(page)
end

local function CreateRaidRosterPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints(parent)

	CreateRaidRosterHeader(page)
	page.gearCheckScanBtn:SetScript("OnClick", function()
		RunGearCheckRaidScan(page)
	end)
	page.gearCheckExportBtn:SetScript("OnClick", function()
		RunGearCheckRaidExport(page)
	end)
	page.textViewBtn:SetScript("OnClick", function()
		ExitRaidExportView(page)
	end)

	local tableTop = -W.RaidRosterTableTopOffset()
	local tableHost = CreateFrame("Frame", nil, page)
	tableHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, tableTop)
	tableHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	W.ApplyPlainPanel(tableHost, UI.PANEL_BG)
	page.tableHost = tableHost

	local scroll = CreateFrame("ScrollFrame", "RaidwiseRaidRosterScrollV" .. tostring(LAYOUT_VERSION), tableHost)
	scroll:SetPoint("TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", -(UI.CD_SCROLLBAR_W + 2), UI.CD_HSCROLL_H + 2)
	scroll:EnableMouseWheel(true)
	page.scroll = scroll

	local content = CreateFrame("Frame", nil, scroll)
	local contentW, contentH = RaidContentSize()
	content:SetSize(contentW, contentH)
	scroll:SetScrollChild(content)
	page.tableContent = content

	local topBlock = CreateRaidBlock(content, 1, 5)
	topBlock:SetPoint("TOPLEFT", 0, 0)
	page.topBlock = topBlock

	local bottomBlock = CreateRaidBlock(content, 6, 8)
	bottomBlock:SetPoint("TOPLEFT", topBlock, "BOTTOMLEFT", 0, -RAID_BLOCK_GAP)
	page.bottomBlock = bottomBlock

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

	local exportDumpBox, exportCopyHost = W.CreateCopyBox(
		page,
		"RaidwiseRaidExportScrollV" .. tostring(LAYOUT_VERSION),
		"RaidwiseRaidExportBoxV" .. tostring(LAYOUT_VERSION)
	)
	exportCopyHost:SetPoint("TOPLEFT", page, "TOPLEFT", 0, tableTop)
	exportCopyHost:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	exportCopyHost:SetFrameLevel(tableHost:GetFrameLevel() + 2)
	exportCopyHost:Hide()
	page.exportDumpBox = exportDumpBox
	page.exportCopyHost = exportCopyHost

	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxV = math.max(0, (content:GetHeight() or 0) - (self:GetHeight() or 0))
		local step = RAID_CELL_H
		local nextValue = math.max(0, math.min(maxV, (self:GetVerticalScroll() or 0) - delta * step))
		self:SetVerticalScroll(nextValue)
		vBar:SetValue(nextValue)
	end)
	scroll:SetScript("OnSizeChanged", function()
		W.LayoutTableScrollBars(page)
	end)

	page:SetScript("OnShow", function()
		Addon:RefreshRaidRosterView(true)
	end)

	page.gearCheckResults = {}
	page.gearCheckScanning = false
	page.gearCheckExporting = false
	page.gearCheckMemberScanning = false
	page.exportViewMode = false
	page.layoutVersion = LAYOUT_VERSION
	return page
end

local function ApplyLocale(page)
	if not page then
		return
	end
	if page.gradeLegendLabel then
		page.gradeLegendLabel:SetText(FormatGradeChipLine())
	end
	if page.reportFlaskBtn then
		page.reportFlaskBtn.tooltipKey = "BTN_RAID_REPORT_FLASK_TIP"
	end
	if page.reportFoodBtn then
		page.reportFoodBtn.tooltipKey = "BTN_RAID_REPORT_FOOD_TIP"
	end
	if page.reportGearBtn then
		page.reportGearBtn.tooltipKey = "BTN_RAID_REPORT_GEAR_TIP"
	end
	if page.reportEnchantBtn then
		page.reportEnchantBtn.tooltipKey = "BTN_RAID_REPORT_ENCHANT_TIP"
	end
	SetRaidProgressIdleText(page)
	UpdateRaidGradeSummaries(page, ResolveGearCheckResults(page))
	UpdateRaidConsumableSummary(page)
	UpdateRaidRosterStatsLabels(page, RosterMembersFromPage(page))
	UpdateRaidExportActionButtons(page)

	local blocks = { page.topBlock, page.bottomBlock }
	for blockIndex = 1, #blocks do
		local block = blocks[blockIndex]
		if block and block.columns then
			for _, column in pairs(block.columns) do
				for slot = 1, 5 do
					local cell = column.cells and column.cells[slot]
					if cell and cell.gearBtn and cell.gearBtn.label then
						cell.gearBtn.label:SetText(W.T("BTN_RAID_GEAR"))
					end
					if cell and cell.rescanBtn and cell.rescanBtn.label then
						cell.rescanBtn.label:SetText(W.T("BTN_RAID_RESCAN"))
					end
				end
			end
		end
	end
end

Addon.Pages.Raid = {
	capabilities = { reportChat = true },
	id = "raid",
	LAYOUT_VERSION = LAYOUT_VERSION,
	Refresh = function(_, entering)
		if entering then Addon:RefreshPartyData(true) else Addon:RefreshRaidRosterView(false) end
	end,
	Create = CreateRaidRosterPage,
	ApplyLocale = ApplyLocale,
}
