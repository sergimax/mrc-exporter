-- Gear scan orchestration and live report state.
local Addon = Raidwise

local pendingUnit = nil
local pendingCallback = nil
local pendingInspectReady = false
local pendingSpecRetry = false
local pendingGemRetry = false
local lastReport = nil
local raidQueue = nil
local lastRaidResults = nil

function Addon:ResolveGearCheckUnit()
	if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
		return "target"
	end
	return "player"
end

function Addon:GetLastGearCheckRaidResults()
	return lastRaidResults
end

function Addon:SetLastGearCheckRaidResults(results)
	if type(results) == "table" then
		lastRaidResults = results
	else
		lastRaidResults = nil
	end
end

function Addon:IsGearCheckScanBusy()
	return pendingUnit ~= nil or (raidQueue and raidQueue.active) or false
end

local function AttachFindings(report)
	if report and Addon.EvaluateGearCheck then
		Addon:EvaluateGearCheck(report)
	end
	return report
end

local function SetInspectComplete(report, complete)
	if not report then
		return
	end
	Addon:NormalizeGearCheckReport(report)
	local inspect = report.collection.inspect
	if inspect then
		inspect.complete = complete and true or false
	end
end

local function FinalizeGearCheckReport(report, complete)
	if not report then
		return report
	end
	if complete ~= nil then
		SetInspectComplete(report, complete)
	end
	return AttachFindings(report)
end

local function ReportGradesNeedRefresh(report)
	if not report then
		return false
	end
	local inspect = Addon:GetGearCheckInspect(report)
	if not inspect.complete then
		return false
	end
	if not report.verdicts then
		return true
	end
	local findings = report.findings or {}
	for index = 1, #findings do
		if findings[index].code == "INSPECT_INCOMPLETE" then
			return true
		end
	end
	return false
end

function Addon:EnsureGearCheckGrades(report)
	if not report or not ReportGradesNeedRefresh(report) then
		return report
	end
	return FinalizeGearCheckReport(report, true)
end

function Addon:GetGearCheckMetaSummary(report)
	local count = report and report.overall and report.overall.issues and report.overall.issues.meta or 0
	if count > 0 then
		return tostring(count)
	end
	for _, finding in ipairs(report and report.findings or {}) do
		if finding.code == "META_NOT_CHECKABLE" then
			return "Unknown"
		end
	end
	local meta = report and report.meta
	if meta and meta.present then
		if meta.active == true then return "OK" end
		if meta.active == false then return "Inactive" end
		return "Unknown"
	end
	return "None"
end

function Addon:GetLastGearCheckReport()
	if lastReport then
		self:EnsureGearCheckGrades(lastReport)
	end
	return lastReport
end

function Addon:SetLastGearCheckReport(report, status)
	if not report then
		return
	end
	if status then
		report.scanStatus = status
		if report.collection then
			report.collection.scanStatus = status
		end
	end
	self:NormalizeGearCheckReport(report)
	self:EnsureGearCheckGrades(report)
	lastReport = report
end

function Addon:CollectGearCheck(unit)
	unit = unit or self:ResolveGearCheckUnit()
	local inspectReady = unit and (UnitIsUnit(unit, "player")
		or (pendingUnit and pendingInspectReady and UnitIsUnit(unit, pendingUnit)))
	local report = self:CollectGearCheckObservation(unit, inspectReady)
	if report then lastReport = report end
	return report
end

local function MaybeResumePartyInspects()
	if Addon.IsGearCheckScanBusy and Addon:IsGearCheckScanBusy() then
		return
	end
	if Addon.QueuePartyInspects then
		Addon:QueuePartyInspects()
	end
end

local function FinishRaidScan()
	if not raidQueue then
		return
	end
	local onComplete = raidQueue.onComplete
	local results = raidQueue.results
	lastRaidResults = results
	raidQueue = nil
	if onComplete then
		onComplete(results, "ok")
	end
	MaybeResumePartyInspects()
end

local function NotifyRaidScanLive(phase)
	if not raidQueue or not raidQueue.onProgress then
		return
	end
	if raidQueue.livePhase == phase and raidQueue.liveMember == raidQueue.currentMember then
		return
	end
	raidQueue.livePhase = phase
	raidQueue.liveMember = raidQueue.currentMember
	raidQueue.onProgress({
		member = raidQueue.currentMember,
		phase = phase,
		live = true,
	}, #raidQueue.results, raidQueue.total)
end

local function AppendRaidScanResult(report, status)
	if not raidQueue or not raidQueue.active then
		return
	end
	raidQueue.livePhase = nil
	raidQueue.liveMember = nil
	local entry = {
		member = raidQueue.currentMember,
		report = report,
		status = status,
		phase = "done",
	}
	raidQueue.results[#raidQueue.results + 1] = entry
	if raidQueue.onProgress then
		raidQueue.onProgress(entry, #raidQueue.results, raidQueue.total)
	end
end

local function ScanNextRaidMember()
	if not raidQueue or not raidQueue.active then
		return
	end
	local members = raidQueue.members
	while raidQueue.index <= #members do
		local member = members[raidQueue.index]
		raidQueue.index = raidQueue.index + 1
		local unit = member and member.unit
		raidQueue.currentMember = member
		if unit and UnitExists(unit) and (not member.guid or UnitGUID(unit) == member.guid) then
			local connected = true
			if type(UnitIsConnected) == "function" and not UnitIsUnit(unit, "player") then
				connected = UnitIsConnected(unit)
			end
			if connected then
				raidQueue.currentMember = member
				NotifyRaidScanLive("inspect")
				if Addon:StartGearCheckUnitScan(unit, nil) then
					return
				end
			end
		end
		AppendRaidScanResult(nil, "skipped")
	end
	raidQueue.active = false
	FinishRaidScan()
end

local function FinishScan(report, status)
	Addon:CompleteInspectRequest("gear")
	if report then
		report.scanStatus = status
		if report.collection then
			report.collection.scanStatus = status
		end
	end
	lastReport = report
	local callback = pendingCallback
	local continueRaid = raidQueue and raidQueue.active
	pendingCallback = nil
	pendingUnit = nil
	pendingInspectReady = false
	pendingSpecRetry = false
	pendingGemRetry = false
	if callback then
		callback(report, status)
	end
	if continueRaid then
		AppendRaidScanResult(report, status)
		ScanNextRaidMember()
	elseif not pendingUnit and not (raidQueue and raidQueue.active) then
		MaybeResumePartyInspects()
	end
end

local function EquipmentHasUncertainGems(equipment)
	if type(equipment) ~= "table" then
		return false
	end
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.policy == "CHECKED" and slot.item and slot.item.sockets then
			if slot.item.sockets.gemDataUncertain then
				return true
			end
		end
	end
	return false
end

local function TryCollectPending(forceComplete)
	if not pendingUnit then
		return
	end
	local report = Addon:CollectGearCheck(pendingUnit)
	if not report then
		FinishScan(nil, "missing")
		return
	end
	if report.character and report.character.isSelf then
		FinalizeGearCheckReport(report, true)
		FinishScan(report, "ok")
		return
	end
	local filled = (report.collection and report.collection.counts and report.collection.counts.filledCheckedSlots) or 0
	local specKnown = report.character and report.character.specKnown
	-- A stripped inspect can look exactly like entirely empty sockets. Require
	-- a fresh inspect response before accepting that result as missing gems.
	local emptyItems = {}
	local hasGems = false
	for _, slot in ipairs(report.equipment or {}) do
		local item = slot.policy == "CHECKED" and slot.item
		if item then
			hasGems = hasGems or #(item.gems or {}) > 0
			if item.sockets and item.sockets.emptyConfirmed then
				emptyItems[#emptyItems + 1] = item
			end
		end
	end
	if #emptyItems > 0 and not hasGems and not (pendingGemRetry and pendingInspectReady) then
		for _, item in ipairs(emptyItems) do
			item.sockets.emptyConfirmed = false
			item.sockets.gemDataUncertain = true
			item.sockets.empty = 0
			for socketIndex in pairs(item.sockets.states or {}) do
				item.sockets.states[socketIndex] = "unresolved"
			end
		end
	end
	local gemsReady = not EquipmentHasUncertainGems(report.equipment)
	if filled > 0 and specKnown and pendingInspectReady and gemsReady then
		FinalizeGearCheckReport(report, true)
		FinishScan(report, "ok")
		return
	end
	if raidQueue and raidQueue.active then
		if not pendingInspectReady then
			NotifyRaidScanLive("inspect")
		elseif not specKnown then
			NotifyRaidScanLive("spec")
		elseif not gemsReady then
			NotifyRaidScanLive("gems")
		else
			NotifyRaidScanLive("evaluate")
		end
	end
	if forceComplete then
		if filled > 0 and not specKnown and not pendingSpecRetry then
			pendingSpecRetry = true
			pendingInspectReady = false
			Addon:RetryInspectRequest("gear")
			return
		end
		-- One more inspect pulse when gems still look stripped.
		if filled > 0 and pendingInspectReady and not gemsReady and not pendingGemRetry then
			pendingGemRetry = true
			pendingInspectReady = false
			Addon:RetryInspectRequest("gear")
			return
		end
		FinalizeGearCheckReport(report, filled > 0 and specKnown and pendingInspectReady and gemsReady)
		if filled > 0 and (not specKnown or not pendingInspectReady or not gemsReady) then
			FinishScan(report, "timeout")
			return
		end
		FinishScan(report, filled > 0 and "ok" or "empty")
	end
end

function Addon:StartGearCheckUnitScan(unit, callback)
	if pendingUnit then
		return false
	end
	if callback and raidQueue and raidQueue.active then
		return false
	end
	pendingCallback = callback
	local report = self:CollectGearCheck(unit)
	if not report then
		FinishScan(nil, "missing")
		return true
	end

	if report.character and report.character.isSelf then
		FinalizeGearCheckReport(report, true)
		FinishScan(report, "ok")
		return true
	end

	local inspect = report.inspect or {}
	if not inspect.canInspect then
		FinalizeGearCheckReport(report, false)
		FinishScan(report, inspect.tooFar and "too_far" or "cannot_inspect")
		return true
	end

	pendingUnit = unit
	pendingInspectReady = false
	pendingSpecRetry = false
	pendingGemRetry = false
	if Addon.ClearCachedSpecForUnit then
		Addon:ClearCachedSpecForUnit(unit)
	end
	if Addon.ClearPartyInspectForGearCheck then
		Addon:ClearPartyInspectForGearCheck()
	end
	local started = self:StartInspectRequest("gear", unit, {
		onReady = function() pendingInspectReady = true; TryCollectPending(false) end,
		onPoll = function() TryCollectPending(false) end,
		onTimeout = function() TryCollectPending(true) end,
		onStop = function(status) FinishScan(nil, status) end,
	})
	if not started then FinishScan(nil, "cannot_inspect") end
	return true
end

-- Cancel the active target or raid scan; completed raid entries are retained.
function Addon:CancelGearCheckScan()
	if not pendingUnit and not raidQueue then return false end
	local queue = raidQueue
	raidQueue = nil
	if queue then lastRaidResults = queue.results end
	self:CancelInspectRequest("gear")
	if queue and queue.onComplete then queue.onComplete(queue.results, "cancelled") end
	return true
end

function Addon:StartGearCheckScan(callback)
	return self:StartGearCheckUnitScan(self:ResolveGearCheckUnit(), function(report, status)
		self:RecordTargetScanHistory(report)
		if callback then
			callback(report, status)
		end
	end)
end

function Addon:GetGearCheckRaidEntryStatusLabel(entry)
	if entry and entry.report then
		return nil
	end
	if entry and entry.status == "too_far" then
		return self:T("GEAR_CHECK_RAID_STATUS_TOO_FAR")
	end
	if entry and entry.status == "cannot_inspect" then
		return self:T("GEAR_CHECK_RAID_STATUS_NO_INSPECT")
	end
	if entry and entry.status == "timeout" then
		return self:T("GEAR_CHECK_RAID_STATUS_TIMEOUT")
	end
	if entry and entry.status == "empty" then
		return self:T("GEAR_CHECK_RAID_CELL_EMPTY")
	end
	if entry then
		return self:T("GEAR_CHECK_RAID_ROW_FAIL")
	end
	return self:T("GEAR_CHECK_RAID_NOT_SCANNED")
end

function Addon:StartGearCheckRaidScan(onProgress, onComplete)
	if pendingUnit or (raidQueue and raidQueue.active) then
		return false
	end
	local members = (self.CompositionMembers and self:CompositionMembers(false)) or {}
	if #members == 0 then
		lastRaidResults = {}
		if onComplete then
			onComplete({}, "empty")
		end
		return true
	end
	raidQueue = {
		members = members,
		index = 1,
		total = #members,
		results = {},
		onProgress = onProgress,
		onComplete = onComplete,
		active = true,
	}
	ScanNextRaidMember()
	return true
end

-- Print a report mode; scan first when no cached report exists.
function Addon:RunGearCheckChatReport(mode, openUi)
	mode = mode or "summary"
	if openUi ~= false and self.OpenGearCheckTarget then
		self:ShowMainFrame()
		self:SelectTab("geartarget")
	end
	local report = self:GetLastGearCheckReport()
	if report then
		self:PrintGearCheckReport(mode, report)
		if openUi ~= false and self.RefreshGearCheckTargetView then
			self:RefreshGearCheckTargetView(false)
		end
		return
	end
	if not self.StartGearCheckScan then
		self:Print(self:T("GEAR_CHECK_STATUS_FAIL"))
		return
	end
	self:Print(self:T("CHAT_GEARCHECK_SCANNING"))
	self:StartGearCheckScan(function(scanned)
		if openUi ~= false and self.RefreshGearCheckTargetView then
			self:RefreshGearCheckTargetView(false)
		end
		if scanned then
			self:PrintGearCheckReport(mode, scanned)
		else
			self:Print(self:T("CHAT_GEARCHECK_NO_REPORT"))
		end
	end)
end
