-- Canonical report fields and scan completeness, independent of equipment grades.
local Addon = Raidwise

function Addon:GetGearCheckEquipment(report)
	return report and (report.equipment or report.slots) or {}
end

function Addon:GetGearCheckInspect(report)
	return report and ((report.collection and report.collection.inspect) or report.inspect) or {}
end

function Addon:NormalizeGearCheckReport(report)
	if not report then return nil end
	report.character = report.character or {}
	report.equipment = report.equipment or report.slots or {}
	report.collection = report.collection or {}
	local character, collection = report.character, report.collection
	local legacyStats = report.stats or {}
	collection.inspect = collection.inspect or report.inspect or {}
	collection.counts = collection.counts or {}
	collection.scanStatus = collection.scanStatus or report.scanStatus
	for _, key in ipairs({"name", "isSelf", "specKnown"}) do
		if character[key] == nil then character[key] = report[key] end
	end
	for _, key in ipairs({"gearScore", "averageIlvl"}) do
		if character[key] == nil then character[key] = legacyStats[key] end
	end
	for _, key in ipairs({"checkedSlots", "filledCheckedSlots"}) do
		if collection.counts[key] == nil then collection.counts[key] = legacyStats[key] end
	end
	-- Compatibility aliases are assigned only at this boundary; nested data wins.
	report.slots, report.inspect = report.equipment, collection.inspect
	report.name, report.isSelf, report.specKnown = character.name, character.isSelf, character.specKnown
	report.scanStatus = collection.scanStatus
	report.stats = {
		checkedSlots = collection.counts.checkedSlots,
		filledCheckedSlots = collection.counts.filledCheckedSlots,
		gearScore = character.gearScore, averageIlvl = character.averageIlvl,
	}
	return report
end

function Addon:GetGearCheckScanState(report)
	if not report then return "unavailable", "missing_report" end
	local collection = report.collection or {}
	local inspect = collection.inspect or report.inspect or {}
	local counts = collection.counts or report.stats or {}
	if counts.filledCheckedSlots == 0 then return "unavailable", "no_equipment" end
	if inspect.needed and inspect.canInspect == false and not inspect.complete then
		return "unavailable", inspect.tooFar and "too_far" or "cannot_inspect"
	end
	if inspect.needed and not inspect.complete then return "incomplete", "inspect_pending" end
	for _, slot in ipairs(report.equipment or report.slots or {}) do
		if slot.policy == "CHECKED" and slot.item then
			if slot.item.pendingLink then return "incomplete", "item_pending" end
			if slot.item.sockets and slot.item.sockets.gemDataUncertain then
				return "incomplete", "gems_pending"
			end
		end
	end
	return "complete"
end

function Addon:GetGearCheckScanLabel(report)
	local state = self:GetGearCheckScanState(report)
	if state == "complete" then return nil end
	local key = state == "unavailable" and "GEAR_CHECK_SCAN_UNAVAILABLE" or "GEAR_CHECK_SCAN_INCOMPLETE"
	return self.T and self:T(key) or state
end
