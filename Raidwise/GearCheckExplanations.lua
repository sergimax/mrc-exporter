local Addon = Raidwise
local Policy = Addon.GearCheckPolicy
local ITEM_ISSUE_CATEGORIES = Policy.ITEM_ISSUE_CATEGORIES
local ENCHANT_SOCKET_CATEGORIES = Policy.ENCHANT_SOCKET_CATEGORIES
local CollectNotGoodGearReasons = Policy.CollectNotGoodGearReasons
local CollectNotGoodEnchantSocketReasons = Policy.CollectNotGoodEnchantSocketReasons
local GearSlotQualifiesForGood = Policy.GearSlotQualifiesForGood
local EnchantSocketSlotQualifiesForGood = Policy.EnchantSocketSlotQualifiesForGood
local FindingMatchesCategory = Policy.FindingMatchesCategory
local CollectNotGoodReasons = Policy.CollectNotGoodReasons

local TOOLTIP_CATEGORY_CONFIG = {
	gear = {
		categories = ITEM_ISSUE_CATEGORIES,
		qualifiesForGood = GearSlotQualifiesForGood,
		collectNotGood = CollectNotGoodGearReasons,
		cleanKey = "GEAR_CHECK_RAID_TIP_GEAR_CLEAN",
	},
	enchantSocket = {
		categories = ENCHANT_SOCKET_CATEGORIES,
		qualifiesForGood = EnchantSocketSlotQualifiesForGood,
		collectNotGood = CollectNotGoodEnchantSocketReasons,
		cleanKey = "GEAR_CHECK_RAID_TIP_ENCHANT_CLEAN",
	},
}

local function TipMsg(key)
	if Addon.T then
		return Addon:T(key)
	end
	return key
end

local function SlotShortName(report, slotKey)
	if not slotKey then
		return "Gear"
	end
	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.key == slotKey then
			return slot.slotName or slotKey
		end
	end
	return tostring(slotKey)
end

local function SlotHasCategoryIssue(findings, slotKey, categoryMap)
	for index = 1, #findings do
		local finding = findings[index]
		if finding.slot == slotKey and FindingMatchesCategory(finding, categoryMap) then
			if finding.severity == "hard" or finding.severity == "soft" then
				return true
			end
		end
	end
	return false
end

--- Detail lines for raid roster cell tooltips (hard/soft findings + B-not-A reasons).
function Addon:BuildGearCheckCategoryTooltipLines(report, categoryKey, maxLines)
	maxLines = maxLines or 8
	local config = TOOLTIP_CATEGORY_CONFIG[categoryKey]
	local result = { grade = "B", lines = {}, hidden = 0 }
	if not config or not report then
		return result
	end

	local overall = report.overall or {}
	if categoryKey == "gear" then
		result.grade = overall.gearGrade or overall.status or "B"
	else
		result.grade = overall.enchantSocketGrade or "B"
	end

	local findings = report.findings or {}
	local categoryMap = config.categories
	local bySlot = {}
	local order = {}

	local function AppendBucket(slotKey, severity, message)
		local key = slotKey or "_gear"
		local bucket = bySlot[key]
		if not bucket then
			bucket = { severity = severity, messages = {} }
			bySlot[key] = bucket
			order[#order + 1] = key
		end
		if severity == "hard" then
			bucket.severity = "hard"
		elseif severity == "soft" and bucket.severity ~= "hard" then
			bucket.severity = "soft"
		elseif severity == "info" and bucket.severity ~= "hard" and bucket.severity ~= "soft" then
			bucket.severity = "info"
		end
		bucket.messages[#bucket.messages + 1] = message
	end

	for index = 1, #findings do
		local finding = findings[index]
		if FindingMatchesCategory(finding, categoryMap) and (finding.severity == "hard" or finding.severity == "soft") then
			AppendBucket(finding.slot, finding.severity, finding.message or finding.code or "?")
		end
	end

	local profile = nil
	if report.character then
		profile = self:GetGearCheckProfile(
			report.character.classFile,
			report.character.specTab,
			report.character.specKnown
		)
	end

	if result.grade == "B" then
		local equipment = Addon:GetGearCheckEquipment(report)
		for index = 1, #equipment do
			local slot = equipment[index]
			if slot.policy == "CHECKED" and slot.item and not SlotHasCategoryIssue(findings, slot.key, categoryMap) then
				if not config.qualifiesForGood(profile, slot, findings) then
					local reasons = config.collectNotGood(profile, slot, findings)
					for reasonIndex = 1, #reasons do
						AppendBucket(slot.key, "info", reasons[reasonIndex])
					end
				end
			end
		end
	end

	local function AppendSlotTooltipLines(slotLabel, bucket)
		local messages = bucket.messages
		local severity = bucket.severity or "info"
		if #messages == 0 then
			result.lines[#result.lines + 1] = { severity = severity, text = slotLabel, kind = "slot" }
			return
		end
		result.lines[#result.lines + 1] = { severity = severity, text = slotLabel .. ":", kind = "slot" }
		for messageIndex = 1, #messages do
			result.lines[#result.lines + 1] = {
				severity = severity,
				text = "- " .. messages[messageIndex],
				kind = "bullet",
			}
		end
	end

	for index = 1, #order do
		local key = order[index]
		local bucket = bySlot[key]
		local slotLabel = SlotShortName(report, key ~= "_gear" and key or nil)
		AppendSlotTooltipLines(slotLabel, bucket)
	end

	if #result.lines == 0 then
		if result.grade == "S" or result.grade == "A" then
			result.lines[1] = { severity = "clean", text = TipMsg(config.cleanKey) }
		elseif result.grade == "B" then
			result.lines[1] = { severity = "info", text = TipMsg("GEAR_CHECK_RAID_TIP_OK_CLEAN") }
		end
	end

	if #result.lines > maxLines then
		result.hidden = #result.lines - maxLines
		while #result.lines > maxLines do
			result.lines[#result.lines] = nil
		end
	end

	return result
end

--- Reasons a CHECKED slot stayed B instead of A (empty if not B / already A or S).
function Addon:ExplainGearCheckNotGood(report, slot)
	local reasons = {}
	if not report or not slot or slot.verdict ~= "B" or not slot.item then
		return reasons
	end
	local profile = nil
	if report.character then
		profile = self:GetGearCheckProfile(
			report.character.classFile,
			report.character.specTab,
			report.character.specKnown
		)
	end
	return CollectNotGoodReasons(profile, slot, report.findings or {})
end

