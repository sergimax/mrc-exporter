local Addon = Raidwise
local Policy = Addon.GearCheckPolicy
local ENCHANT_OPTIONAL = Policy.ENCHANT_OPTIONAL
local RankArmor = Policy.RankArmor
local RankWeapon = Policy.RankWeapon
local TrinketInSet = Policy.TrinketInSet
local SlotRequiresEnchantForGood = Policy.SlotRequiresEnchantForGood

local ITEM_ISSUE_CATEGORIES = {
	armor = true,
	weapon = true,
	stat = true,
	item = true,
}

local ENCHANT_SOCKET_CATEGORIES = {
	enchant = true,
	gem = true,
	meta = true,
}

local GEAR_GOOD_BLOCKING_INFO = {
	ITEM_NOT_CHECKABLE = true,
}

local ENCHANT_SOCKET_GOOD_BLOCKING_INFO = {
	ENCHANT_NOT_CHECKABLE = true,
	GEM_NOT_CHECKABLE = true,
	META_NOT_CHECKABLE = true,
}

local VERDICT_SEVERITY = {
	S = 1,
	A = 2,
	B = 3,
	C = 4,
	D = 5,
}

local function CountUnique(map)
	local n = 0
	for _ in pairs(map) do
		n = n + 1
	end
	return n
end

local function CountIssueGroups(findings)
	local items, enchants, gems, meta = {}, {}, {}, {}
	for index = 1, #findings do
		local finding = findings[index]
		if finding.severity == "hard" or finding.severity == "soft" then
			local key = finding.slot or "_gear"
			if finding.category == "enchant" then
				enchants[key] = true
			elseif finding.category == "gem" then
				gems[key] = true
			elseif finding.category == "meta" then
				meta[key] = true
			elseif ITEM_ISSUE_CATEGORIES[finding.category] then
				items[key] = true
			end
		end
	end
	return {
		items = CountUnique(items),
		enchants = CountUnique(enchants),
		gems = CountUnique(gems),
		meta = CountUnique(meta),
	}
end

local function CountResilienceItems(findings)
	local slots = {}
	for index = 1, #findings do
		local finding = findings[index]
		if finding.code == "RESILIENCE_PVE" and finding.slot then
			slots[finding.slot] = true
		end
	end
	return CountUnique(slots)
end

local function IsInspectIncomplete(report)
	if not report then
		return false
	end
	return Addon:GetGearCheckScanState(report) ~= "complete"
end

local function EnchantIsMaxLevel(enchant)
	if not enchant or not enchant.present then
		return false
	end
	local info = Addon.GetGearCheckEnchantInfo and Addon:GetGearCheckEnchantInfo(enchant.enchantId)
	return info and info.maxLevel == true
end

local function GemsQualifyForGood(item)
	local sockets = item.sockets or {}
	local gems = item.gems or {}
	if sockets.gemDataUncertain then
		return false
	end
	local socketTotal = tonumber(sockets.total) or 0
	local empty = tonumber(sockets.empty)
	if empty == nil then
		empty = math.max(0, socketTotal - #gems)
	end
	if empty > 0 and sockets.emptyConfirmed then
		return false
	end
	if socketTotal <= 0 and #gems == 0 then
		return true
	end
	for index = 1, #gems do
		local gem = gems[index]
		local catalog = Addon.GetGearCheckGemInfo and Addon:GetGearCheckGemInfo(gem.itemId)
		if not catalog then
			return false
		end
		if catalog.maxLevel ~= true and not catalog.allStats then
			return false
		end
	end
	return true
end

-- BiS lists often use lower armor on wrist/hands/waist/feet (plate DPS leather/mail;
-- Enhancement/Hunter leather bracers/boots; etc.). Acceptable there still qualifies for A.
local GOOD_OFFSET_SLOTS = {
	wrist = true,
	hands = true,
	waist = true,
	feet = true,
}

local function TypeQualifiesForGood(profile, slot)
	local item = slot.item
	if slot.key == "trinket1" or slot.key == "trinket2" then
		local itemId = item and tonumber(item.itemId)
		local preferred = profile.trinketsPreferred
		if type(preferred) == "table" and next(preferred) then
			return TrinketInSet(preferred, itemId)
		end
		local allowed = profile.trinketsAllowed
		if type(allowed) == "table" and next(allowed) then
			return TrinketInSet(allowed, itemId)
		end
		return true
	end
	if slot.key == "back" or slot.key == "neck" or slot.key == "finger1" or slot.key == "finger2" then
		return true
	end
	if item.category == "armor" and not item.isRelic then
		local armorType = item.armorType
		if armorType == "misc" then
			return true
		end
		if armorType == "shield" or armorType == "offhand" then
			return RankWeapon(profile, armorType) == "preferred"
		end
		local rank = RankArmor(profile, armorType)
		if rank == "preferred" then
			return true
		end
		-- Acceptable offset pieces (e.g. Umbrage Armbands on Ret) still qualify for A.
		-- Acceptable cloth (Resto/Balance Druid, Holy Pala, Shaman) qualifies for A.
		if rank == "acceptable" and (GOOD_OFFSET_SLOTS[slot.key] or armorType == "cloth") then
			return true
		end
		return false
	end
	if item.category == "weapon" then
		local rank = RankWeapon(profile, item.weaponType)
		return rank == "preferred" or rank == "acceptable"
	end
	return true
end

local function SlotHasCategoryBlockingInfo(findings, slotKey, blockingMap)
	for index = 1, #findings do
		local finding = findings[index]
		if finding.slot == slotKey and finding.severity == "info" and blockingMap[finding.code] then
			return true
		end
	end
	return false
end

local function CollectBlockingInfoReasons(findings, slotKey, blockingMap)
	local reasons = {}
	for index = 1, #findings do
		local finding = findings[index]
		if finding.slot == slotKey and finding.severity == "info" and blockingMap[finding.code] then
			reasons[#reasons + 1] = finding.message or finding.code
		end
	end
	if #reasons == 0 then
		reasons[#reasons + 1] = "Incomplete or unknown data blocks A."
	end
	return reasons
end

local function CollectNotGoodGearReasons(profile, slot, findings)
	local reasons = {}
	local item = slot and slot.item
	if not profile or not item then
		reasons[#reasons + 1] = "Cannot confirm A without a profile or item data."
		return reasons
	end
	if SlotHasCategoryBlockingInfo(findings, slot.key, GEAR_GOOD_BLOCKING_INFO) then
		return CollectBlockingInfoReasons(findings, slot.key, GEAR_GOOD_BLOCKING_INFO)
	end
	if not TypeQualifiesForGood(profile, slot) then
		if slot.key == "trinket1" or slot.key == "trinket2" then
			local itemId = item and tonumber(item.itemId)
			if TrinketInSet(profile.trinketsAllowed, itemId) then
				reasons[#reasons + 1] = "Trinket is in progression pool, not endgame BiS."
			else
				reasons[#reasons + 1] = "Trinket is not preferred for this specialization."
			end
		elseif item.category == "armor" and item.armorType and item.armorType ~= "misc" then
			reasons[#reasons + 1] = string.format(
				"Armor type %s is not preferred for this specialization.",
				tostring(item.armorType)
			)
		elseif item.category == "weapon" then
			reasons[#reasons + 1] = string.format(
				"Weapon type %s is not preferred for this specialization.",
				tostring(item.weaponType or "?")
			)
		else
			reasons[#reasons + 1] = "Item type is not preferred for this specialization."
		end
	end
	return reasons
end

local function CollectNotGoodEnchantSocketReasons(profile, slot, findings)
	local reasons = {}
	local item = slot and slot.item
	if not item then
		return reasons
	end
	if SlotHasCategoryBlockingInfo(findings, slot.key, ENCHANT_SOCKET_GOOD_BLOCKING_INFO) then
		return CollectBlockingInfoReasons(findings, slot.key, ENCHANT_SOCKET_GOOD_BLOCKING_INFO)
	end
	if SlotRequiresEnchantForGood(slot) then
		if not item.enchant or not item.enchant.present then
			reasons[#reasons + 1] = "Missing a max-level enchant (required for A)."
		elseif not EnchantIsMaxLevel(item.enchant) then
			reasons[#reasons + 1] = "Enchant is not a recognized max-level enchant."
		end
	elseif ENCHANT_OPTIONAL[slot.key] and item.enchant and item.enchant.present then
		if not EnchantIsMaxLevel(item.enchant) then
			reasons[#reasons + 1] = "Optional enchant is present but not max-level."
		end
	end
	if not GemsQualifyForGood(item) then
		local sockets = item.sockets or {}
		local gems = item.gems or {}
		if sockets.gemDataUncertain then
			reasons[#reasons + 1] = "Gem socket data was not fully available from inspect."
		else
			local empty = tonumber(sockets.empty)
			if empty == nil then
				empty = math.max(0, (tonumber(sockets.total) or 0) - #gems)
			end
			if empty > 0 and sockets.emptyConfirmed then
				reasons[#reasons + 1] = "Empty sockets block A."
			else
				reasons[#reasons + 1] = "One or more gems are not recognized as max-level."
			end
		end
	end
	return reasons
end

local function CollectNotGoodReasons(profile, slot, findings)
	local reasons = {}
	local gearReasons = CollectNotGoodGearReasons(profile, slot, findings)
	for index = 1, #gearReasons do
		reasons[#reasons + 1] = gearReasons[index]
	end
	local enchantReasons = CollectNotGoodEnchantSocketReasons(profile, slot, findings)
	for index = 1, #enchantReasons do
		reasons[#reasons + 1] = enchantReasons[index]
	end
	return reasons
end

local function GearSlotQualifiesForGood(profile, slot, findings)
	return #CollectNotGoodGearReasons(profile, slot, findings) == 0
end

local function EnchantSocketSlotQualifiesForGood(profile, slot, findings)
	return #CollectNotGoodEnchantSocketReasons(profile, slot, findings) == 0
end

local function VerdictIsWorse(left, right)
	return (VERDICT_SEVERITY[left] or 0) > (VERDICT_SEVERITY[right] or 0)
end

local function WorstVerdict(verdicts)
	if not verdicts or #verdicts == 0 then
		return "B"
	end
	local worst = verdicts[1]
	for index = 2, #verdicts do
		if VerdictIsWorse(verdicts[index], worst) then
			worst = verdicts[index]
		end
	end
	return worst
end

local function CapIncompleteGrade(grade)
	if grade == "S" or grade == "A" then
		return "B"
	end
	return grade
end

local function SlotItemIsSpecBis(report, slot)
	local character = report and report.character
	if not character or character.specKnown ~= true then
		return false
	end
	local itemId = slot and slot.item and tonumber(slot.item.itemId)
	if not itemId then
		return false
	end
	return Addon:IsGearCheckBisItem(character.classFile, character.specTab, itemId)
end

local function FindingMatchesCategory(finding, categoryMap)
	return categoryMap[finding.category]
end

local function SlotVerdictForCategories(profile, slot, findings, categoryMap, qualifiesForGoodFn, allowS, report)
	if slot.policy ~= "CHECKED" or slot.empty or not slot.item then
		return nil
	end
	local hard = false
	local soft = false
	for index = 1, #findings do
		local finding = findings[index]
		if finding.slot == slot.key and FindingMatchesCategory(finding, categoryMap) then
			if finding.severity == "hard" then
				hard = true
			elseif finding.severity == "soft" then
				soft = true
			end
		end
	end
	if hard then
		return "D"
	end
	if soft then
		return "C"
	end
	if qualifiesForGoodFn(profile, slot, findings) then
		if allowS and SlotItemIsSpecBis(report, slot) then
			return "S"
		end
		return "A"
	end
	return "B"
end

local function AggregateCategoryGrade(report, categoryMap, qualifiesForGoodFn, applyResilience, allowS)
	local verdicts = {}
	if not report then
		return "B"
	end

	local findings = report.findings or {}
	for index = 1, #findings do
		local finding = findings[index]
		if not finding.slot and FindingMatchesCategory(finding, categoryMap) then
			if finding.severity == "hard" then
				verdicts[#verdicts + 1] = "D"
			elseif finding.severity == "soft" then
				verdicts[#verdicts + 1] = "C"
			end
		end
	end

	local profile = nil
	if report.character then
		profile = Addon:GetGearCheckProfile(
			report.character.classFile,
			report.character.specTab,
			report.character.specKnown
		)
	end

	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		local slot = equipment[index]
		local verdict = SlotVerdictForCategories(
			profile,
			slot,
			findings,
			categoryMap,
			qualifiesForGoodFn,
			allowS,
			report
		)
		if verdict then
			verdicts[#verdicts + 1] = verdict
		end
	end

	local status = WorstVerdict(verdicts)
	if applyResilience then
		local resilienceItems = CountResilienceItems(findings)
		if resilienceItems >= 2 then
			status = "D"
		elseif resilienceItems == 1 and (status == "S" or status == "A" or status == "B") then
			status = "C"
		end
	end
	if IsInspectIncomplete(report) then
		status = CapIncompleteGrade(status)
	end
	return status
end

local function SlotQualifiesForGood(profile, slot, findings)
	return #CollectNotGoodReasons(profile, slot, findings) == 0
end

-- Aggregate per-slot findings → S / A / B / C / D.
-- info-only findings do not demote an item (unknown stays B, never false D).
-- A requires preferred type + max-level enchant (when required) + max-level gems.
-- S is A on the item-ID BiS union for this spec (combined slot also needs the A ench/gem bar).
function Addon:AggregateGearCheckVerdicts(report)
	local summary = { s = 0, a = 0, b = 0, c = 0, d = 0, skipped = 0 }
	if not report then
		return summary
	end

	local bySlot = {}
	local findings = report.findings or {}
	for index = 1, #findings do
		local finding = findings[index]
		local slotKey = finding.slot
		if slotKey then
			local bucket = bySlot[slotKey]
			if not bucket then
				bucket = { hard = false, soft = false, count = 0 }
				bySlot[slotKey] = bucket
			end
			bucket.count = bucket.count + 1
			if finding.severity == "hard" then
				bucket.hard = true
			elseif finding.severity == "soft" then
				bucket.soft = true
			end
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

	local inspectIncomplete = IsInspectIncomplete(report)
	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		local slot = equipment[index]
		slot.verdict = nil
		if slot.policy ~= "CHECKED" or slot.empty or not slot.item then
			summary.skipped = summary.skipped + 1
		else
			local bucket = bySlot[slot.key]
			local verdict = "B"
			if bucket then
				if bucket.hard then
					verdict = "D"
				elseif bucket.soft then
					verdict = "C"
				end
			end
			if verdict == "B" and not inspectIncomplete and SlotQualifiesForGood(profile, slot, findings) then
				if SlotItemIsSpecBis(report, slot) then
					verdict = "S"
				else
					verdict = "A"
				end
			end
			slot.verdict = verdict
			if verdict == "S" then
				summary.s = summary.s + 1
			elseif verdict == "A" then
				summary.a = summary.a + 1
			elseif verdict == "C" then
				summary.c = summary.c + 1
			elseif verdict == "D" then
				summary.d = summary.d + 1
			else
				summary.b = summary.b + 1
			end
		end
	end

	report.verdicts = summary
	return summary
end

-- Overall status: worst item verdict, then Resilience count (1 → C, 2+ → D).
-- Set-piece counts are informational and must not change this result.
-- Overall S only when every filled checked slot is S (item on BiS lists and ench/sock at A).
function Addon:AggregateGearCheckOverall(report)
	local overall = {
		status = "B",
		reason = "clean",
		summary = "No significant issues.",
		issues = { items = 0, enchants = 0, gems = 0, meta = 0 },
		resilienceItems = 0,
		gearGrade = "B",
		enchantSocketGrade = "B",
	}
	if not report then
		return overall
	end

	local findings = report.findings or {}
	local verdicts = report.verdicts or { s = 0, a = 0, b = 0, c = 0, d = 0 }
	local issues = CountIssueGroups(findings)
	local resilienceItems = CountResilienceItems(findings)
	overall.issues = issues
	overall.resilienceItems = resilienceItems

	local status = "B"
	local reason = "clean"
	if (verdicts.d or 0) > 0 then
		status = "D"
		reason = "item_d"
	else
		for index = 1, #findings do
			if findings[index].severity == "hard" then
				status = "D"
				reason = "hard_finding"
				break
			end
		end
	end
	if status == "B" then
		if (verdicts.c or 0) > 0 then
			status = "C"
			reason = "item_c"
		else
			for index = 1, #findings do
				if findings[index].severity == "soft" then
					status = "C"
					reason = "soft_finding"
					break
				end
			end
		end
	end

	if resilienceItems >= 2 then
		status = "D"
		reason = "resilience"
	elseif resilienceItems == 1 and (status == "S" or status == "A" or status == "B") then
		status = "C"
		reason = "resilience"
	end

	if status == "B" then
		local sCount = verdicts.s or 0
		local aCount = verdicts.a or 0
		local bCount = verdicts.b or 0
		if bCount == 0 and not IsInspectIncomplete(report) then
			if sCount > 0 and aCount == 0 then
				status = "S"
				reason = "all_s"
			elseif sCount > 0 or aCount > 0 then
				status = "A"
				reason = "all_a"
			end
		end
	end

	overall.status = status
	overall.reason = reason
	overall.gearGrade = AggregateCategoryGrade(report, ITEM_ISSUE_CATEGORIES, GearSlotQualifiesForGood, true, true)
	overall.enchantSocketGrade = AggregateCategoryGrade(
		report,
		ENCHANT_SOCKET_CATEGORIES,
		EnchantSocketSlotQualifiesForGood,
		false,
		false
	)
	if IsInspectIncomplete(report) then
		overall.gearGrade = CapIncompleteGrade(overall.gearGrade)
		overall.enchantSocketGrade = CapIncompleteGrade(overall.enchantSocketGrade)
		if status == "S" or status == "A" then
			status = "B"
			reason = "inspect_incomplete"
			overall.status = status
			overall.reason = reason
		end
	end
	if status == "D" then
		if reason == "resilience" then
			overall.summary = string.format("%d items have Resilience (PvE: 2+ is D).", resilienceItems)
		else
			overall.summary = string.format("%d item(s) are D.", verdicts.d or 0)
		end
	elseif status == "C" then
		if reason == "resilience" then
			overall.summary = "1 item has Resilience (PvE: C)."
		else
			overall.summary = string.format("%d item(s) are C.", verdicts.c or 0)
		end
	elseif status == "S" then
		overall.summary = string.format("%d item(s) are S (on published BiS lists).", verdicts.s or 0)
	elseif status == "A" then
		overall.summary = string.format("%d item(s) are A.", verdicts.a or 0)
	end

	if IsInspectIncomplete(report) then
		overall.reason = "inspect_incomplete"
		overall.summary = "Inspect data is incomplete; grades are provisional."
	end
	overall.scanState, overall.scanReason = self:GetGearCheckScanState(report)
	overall.provisional = overall.scanState ~= "complete"
	report.overall = overall
	return overall
end


Policy.ITEM_ISSUE_CATEGORIES = ITEM_ISSUE_CATEGORIES
Policy.ENCHANT_SOCKET_CATEGORIES = ENCHANT_SOCKET_CATEGORIES
Policy.CollectNotGoodGearReasons = CollectNotGoodGearReasons
Policy.CollectNotGoodEnchantSocketReasons = CollectNotGoodEnchantSocketReasons
Policy.GearSlotQualifiesForGood = GearSlotQualifiesForGood
Policy.EnchantSocketSlotQualifiesForGood = EnchantSocketSlotQualifiesForGood
Policy.FindingMatchesCategory = FindingMatchesCategory
Policy.CollectNotGoodReasons = CollectNotGoodReasons
