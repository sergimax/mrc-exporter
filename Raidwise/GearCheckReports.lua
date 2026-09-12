-- Gear report formatting; collection and scan orchestration stay in GearCheck.lua.
local Addon = Raidwise

-- Phase 7: chat reports. Destination is Settings report channel. Finding text stays English.
local CHAT_ITEM_CATEGORIES = {
	item = true,
	armor = true,
	weapon = true,
	stat = true,
}
local CHAT_MAX_DETAIL = 15
local CHAT_SHORT_LINE_MAX = 220

local SLOT_SHORT = {
	head = "head",
	neck = "neck",
	shoulder = "shoulder",
	back = "back",
	chest = "chest",
	wrist = "wrist",
	hands = "hands",
	waist = "waist",
	legs = "legs",
	feet = "feet",
	finger1 = "finger1",
	finger2 = "finger2",
	trinket1 = "trinket1",
	trinket2 = "trinket2",
	mainHand = "MH",
	offHand = "OH",
	ranged = "ranged",
}

local function IsShortReportForm()
	return not Addon.GetReportForm or Addon:GetReportForm() ~= "full"
end

local function ChatPlayerName(report)
	local character = report.character or {}
	return character.name or report.name or "?"
end

local function ChatSlotShort(report, slotKey, compact)
	if not slotKey then
		return "Gear"
	end
	if compact then
		return SLOT_SHORT[slotKey] or tostring(slotKey)
	end
	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.key == slotKey then
			return slot.slotName or slot.key
		end
	end
	return tostring(slotKey)
end

local function ChatSlotItem(report, slotKey)
	if not slotKey then
		return nil
	end
	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.key == slotKey then
			return slot.item
		end
	end
	return nil
end

local function FormatItemIdIlvl(item)
	if not item then
		return nil
	end
	local id = item.itemId and tostring(item.itemId) or "-"
	local ilvl = item.itemLevel and tostring(item.itemLevel) or "-"
	return string.format("id=%s ilvl=%s", id, ilvl)
end

local function ShortFindingText(finding)
	local code = finding.code or "?"
	local message = finding.message or ""
	local detail = message:match("%(([^%)]+)%)%s*$")
	if code == "MISSING_ENCHANT" then
		return "missing"
	end
	if detail and detail ~= "" then
		return code .. "(" .. detail .. ")"
	end
	return code
end

local function ChatFindingMatches(finding, mode)
	local category = finding.category
	if mode == "items" then
		return CHAT_ITEM_CATEGORIES[category] == true
	end
	if mode == "enchants" then
		return category == "enchant"
	end
	if mode == "gems" then
		return category == "gem" or category == "meta"
	end
	return false
end

local function PackChatLines(prefix, parts, maxLen)
	local lines = {}
	if #parts == 0 then
		return lines
	end
	local current = prefix
	for index = 1, #parts do
		local part = parts[index]
		local trial
		if current == prefix then
			trial = prefix .. part
		else
			trial = current .. "; " .. part
		end
		if current ~= prefix and string.len(trial) > maxLen then
			lines[#lines + 1] = current
			current = prefix .. part
		else
			current = trial
		end
	end
	if current ~= prefix then
		lines[#lines + 1] = current
	end
	return lines
end

-- Roster reports always use code/slot groups, including unavailable checks.
function Addon:FormatGearCheckMemberIssues(report, category)
	if not report then
		return {}
	end
	local groups, order = {}, {}
	for _, finding in ipairs(report.findings or {}) do
		local matches = category == "gear" and ChatFindingMatches(finding, "items")
			or category == "enchant" and (ChatFindingMatches(finding, "enchants") or ChatFindingMatches(finding, "gems"))
		local code = finding.code or "UNKNOWN"
		if matches and (finding.severity == "hard" or finding.severity == "soft" or string.find(code, "NOT_CHECKABLE", 1, true)) then
			if not groups[code] then
				groups[code] = { slots = {}, seen = {} }
				order[#order + 1] = code
			end
			local group = groups[code]
			local slot = ChatSlotShort(report, finding.slot, true)
			if not group.seen[slot] then
				group.seen[slot] = true
				group.slots[#group.slots + 1] = slot
			end
		end
	end
	local categoryLabel = category == "gear" and "Gear" or "Enchants/Gems"
	local prefix = "[Rw]-raid " .. ChatPlayerName(report) .. " " .. categoryLabel .. ": "
	local parts = {}
	for _, code in ipairs(order) do
		local part = code .. " - "
		for _, slot in ipairs(groups[code].slots) do
			if #prefix + #part + #slot + 1 > CHAT_SHORT_LINE_MAX then
				parts[#parts + 1] = part
				part = code .. " - "
			end
			part = part .. (string.sub(part, -3) == " - " and "" or ",") .. slot
		end
		parts[#parts + 1] = part
	end
	if #parts == 0 then
		parts[1] = "No issues in this category."
	end
	return PackChatLines(prefix, parts, CHAT_SHORT_LINE_MAX)
end

local GEM_CHAT_LABELS = {
	MISSING_GEM = "Missing gems",
	GEM_LOWER_LEVEL = "Lower-level gems",
	GEM_BAD_STAT = "Inappropriate gem stats",
	RESILIENCE_PVE = "PvP gems",
	META_MISSING = "Missing meta",
	META_NOT_META = "Wrong gem in meta socket",
	META_NOT_PREFERRED = "Non-preferred meta",
	META_INACTIVE = "Inactive meta",
}

local function GemChatDetailLines(report)
	local groups, order = {}, {}
	for _, finding in ipairs(report.findings or {}) do
		if ChatFindingMatches(finding, "gems") and (finding.severity == "hard" or finding.severity == "soft") then
			local code = finding.code or "UNKNOWN"
			if not groups[code] then
				groups[code] = { slots = {}, seen = {} }
				order[#order + 1] = code
			end
			local group = groups[code]
			local slot = ChatSlotShort(report, finding.slot, true)
			if not group.seen[slot] then
				group.seen[slot] = true
				group.slots[#group.slots + 1] = slot
			end
		end
	end
	local lines = {}
	for _, code in ipairs(order) do
		local prefix = (GEM_CHAT_LABELS[code] or code) .. ": "
		-- Leave room for the player/category prefix when packing short reports.
		local grouped = PackChatLines(prefix, groups[code].slots, 140)
		for _, line in ipairs(grouped) do
			lines[#lines + 1] = line
		end
	end
	return lines
end

local function ChatDetailLines(report, mode, shortForm)
	if mode == "gems" then
		return GemChatDetailLines(report)
	end
	local lines = {}

	if mode == "ok" then
		local equipment = Addon:GetGearCheckEquipment(report)
		if shortForm then
			local parts = {}
			for index = 1, #equipment do
				local slot = equipment[index]
				if slot.policy == "CHECKED" and slot.item and slot.verdict == "B" then
					parts[#parts + 1] = ChatSlotShort(report, slot.key, true)
				end
			end
			return parts
		end
		for index = 1, #equipment do
			local slot = equipment[index]
			if slot.policy == "CHECKED" and slot.item and slot.verdict == "B" then
				local slotName = slot.slotName or slot.key
				local reasons = Addon.ExplainGearCheckNotGood and Addon:ExplainGearCheckNotGood(report, slot) or {}
				local detail = reasons[1] or "Usable, but not A."
				if #reasons > 1 then
					detail = detail .. " (+" .. tostring(#reasons - 1) .. " more)"
				end
				local meta = FormatItemIdIlvl(slot.item)
				if meta then
					lines[#lines + 1] = string.format("%s (%s): %s", slotName, meta, detail)
				else
					lines[#lines + 1] = string.format("%s: %s", slotName, detail)
				end
			end
		end
		return lines
	end

	local findings = report.findings or {}
	local bySlot = {}
	local order = {}

	for index = 1, #findings do
		local finding = findings[index]
		if ChatFindingMatches(finding, mode) and (finding.severity == "hard" or finding.severity == "soft") then
			local key = finding.slot or "_gear"
			local bucket = bySlot[key]
			if not bucket then
				bucket = {}
				bySlot[key] = bucket
				order[#order + 1] = key
			end
			bucket[#bucket + 1] = finding
		end
	end

	if shortForm and mode == "enchants" then
		local allMissing = #order > 0
		for index = 1, #order do
			local bucket = bySlot[order[index]]
			for findingIndex = 1, #bucket do
				if bucket[findingIndex].code ~= "MISSING_ENCHANT" then
					allMissing = false
					break
				end
			end
			if not allMissing then
				break
			end
		end
		if allMissing then
			local slots = {}
			for index = 1, #order do
				slots[#slots + 1] = ChatSlotShort(report, order[index] ~= "_gear" and order[index] or nil, true)
			end
			return { "missing " .. table.concat(slots, ", ") }
		end
	end

	for index = 1, #order do
		local key = order[index]
		local findingsForSlot = bySlot[key]
		local slotName = ChatSlotShort(report, key ~= "_gear" and key or nil, shortForm)
		if shortForm then
			local texts = {}
			for findingIndex = 1, #findingsForSlot do
				texts[#texts + 1] = ShortFindingText(findingsForSlot[findingIndex])
			end
			lines[#lines + 1] = string.format("%s %s", slotName, table.concat(texts, ","))
		else
			local messages = {}
			for findingIndex = 1, #findingsForSlot do
				local finding = findingsForSlot[findingIndex]
				messages[#messages + 1] = finding.message or finding.code or "?"
			end
			local meta = FormatItemIdIlvl(ChatSlotItem(report, key ~= "_gear" and key or nil))
			if meta then
				lines[#lines + 1] = string.format("%s (%s): %s", slotName, meta, table.concat(messages, "; "))
			else
				lines[#lines + 1] = string.format("%s: %s", slotName, table.concat(messages, "; "))
			end
		end
	end
	return lines
end

function Addon:FormatGearCheckChatReport(report, mode)
	mode = mode or "summary"
	if mode == "report" then
		mode = "summary"
	end
	local lines = {}
	if not report then
		return lines
	end

	local shortForm = IsShortReportForm()
	local name = ChatPlayerName(report)
	local overall = report.overall or {}
	local status = Addon:GetGearCheckScanLabel(report) or overall.status or "B"
	local scanLabel = Addon:GetGearCheckScanLabel(report)
	if scanLabel and mode ~= "summary" then
		lines[#lines + 1] = name .. ": " .. scanLabel
	end
	local issues = overall.issues or {}
	local verdicts = report.verdicts or {}

	if mode == "summary" then
		local stats = report.stats or {}
		local character = report.character or {}
		local gearScore = stats.gearScore or character.gearScore
		local averageIlvl = stats.averageIlvl or character.averageIlvl
		local parts = {}
		local dCount = verdicts.d or 0
		local cCount = verdicts.c or 0
		local bCount = verdicts.b or 0
		local aCount = verdicts.a or 0
		local sCount = verdicts.s or 0
		local enchantN = issues.enchants or 0
		local gemN = issues.gems or 0
		local metaN = issues.meta or 0
		parts[#parts + 1] = string.format("S: %d A: %d B: %d C: %d D: %d", sCount, aCount, bCount, cCount, dCount)
		if shortForm then
			if enchantN > 0 then
				parts[#parts + 1] = string.format("%dench", enchantN)
			end
			if gemN > 0 then
				parts[#parts + 1] = string.format("%dgem", gemN)
			end
			if metaN > 0 then
				parts[#parts + 1] = string.format("%dmeta", metaN)
			elseif report.meta and report.meta.present and report.meta.active == true then
				parts[#parts + 1] = "metaOK"
			end
			if #parts == 0 then
				parts[1] = "ok"
			end
			local head = string.format("%s — %s", name, status)
			if gearScore ~= nil then
				head = head .. " · GS " .. tostring(gearScore)
			end
			if averageIlvl ~= nil then
				head = head .. " · iLvl " .. tostring(averageIlvl)
			end
			head = head .. " · " .. table.concat(parts, " ")
			if overall.resilienceItems and overall.resilienceItems > 0 then
				head = head .. " · " .. tostring(overall.resilienceItems) .. "resil"
			end
			lines[#lines + 1] = head
			return lines
		end
		lines[#lines + 1] = string.format("%s — %s", name, status)
		if gearScore ~= nil or averageIlvl ~= nil then
			lines[#lines + 1] = string.format(
				"GearScore: %s · Avg iLvl: %s",
				gearScore ~= nil and tostring(gearScore) or "-",
				averageIlvl ~= nil and tostring(averageIlvl) or "-"
			)
		end
		if enchantN > 0 then
			parts[#parts + 1] = string.format("%d enchant issue%s", enchantN, enchantN == 1 and "" or "s")
		end
		if gemN > 0 then
			parts[#parts + 1] = string.format("%d gem issue%s", gemN, gemN == 1 and "" or "s")
		end
		if metaN > 0 then
			parts[#parts + 1] = string.format("%d meta issue%s", metaN, metaN == 1 and "" or "s")
		elseif report.meta and report.meta.present and report.meta.active == true then
			parts[#parts + 1] = "meta OK"
		end
		if #parts == 0 then
			parts[1] = "no significant issues"
		end
		lines[#lines + 1] = table.concat(parts, ", ") .. "."
		if overall.resilienceItems and overall.resilienceItems > 0 then
			lines[#lines + 1] = string.format("Resilience items: %d.", overall.resilienceItems)
		end
		return lines
	end

	local title = mode
	if mode == "items" then
		title = "Items"
	elseif mode == "enchants" then
		title = "Enchants"
	elseif mode == "gems" then
		title = "Gems"
	elseif mode == "ok" then
		title = shortForm and "B" or "B (not A)"
	end

	local details = ChatDetailLines(report, mode, shortForm)
	if #details == 0 then
		if scanLabel then return lines end
		if shortForm then
			lines[#lines + 1] = string.format("%s — %s: none", name, title)
		elseif mode == "ok" then
			lines[#lines + 1] = string.format("%s — %s:", name, title)
			lines[#lines + 1] = "No B items (all checked slots are A or S, or none scanned)."
		else
			lines[#lines + 1] = string.format("%s — %s:", name, title)
			lines[#lines + 1] = "No issues in this category."
		end
		return lines
	end

	if shortForm then
		local prefix = string.format("%s — %s: ", name, title)
		local packed = PackChatLines(prefix, details, CHAT_SHORT_LINE_MAX)
		for index = 1, #packed do
			lines[#lines + 1] = packed[index]
		end
		return lines
	end

	lines[#lines + 1] = string.format("%s — %s:", name, title)
	local limit = math.min(#details, CHAT_MAX_DETAIL)
	for index = 1, limit do
		lines[#lines + 1] = details[index]
	end
	if #details > CHAT_MAX_DETAIL then
		lines[#lines + 1] = string.format("… and %d more.", #details - CHAT_MAX_DETAIL)
	end
	return lines
end

function Addon:BuildGearCheckChatMessages(report, mode)
	local lines = self:FormatGearCheckChatReport(report, mode)
	local chatType = self.ResolveReportChatType and self:ResolveReportChatType()
	local prefix = chatType and "[Rw]-gear " or "|cff00ccff[Rw]-gear|r "
	local messages = {}
	for index = 1, #lines do
		messages[index] = self:PrepareReportMessage(prefix .. lines[index])
	end
	return messages
end

function Addon:PrintGearCheckReport(mode, report)
	report = report or self:GetLastGearCheckReport()
	if not report then
		self:Print(self:T("CHAT_GEARCHECK_NO_REPORT"))
		return false
	end
	for _, message in ipairs(self:BuildGearCheckChatMessages(report, mode)) do
		self:SendReportChat(message)
	end
	return true
end
