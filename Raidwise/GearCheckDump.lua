-- Gear Check text dumps and asynchronous raid export jobs.
local Addon = Raidwise

local function ResolveEnchantDumpName(enchant)
	if type(enchant) ~= "table" then
		return nil
	end
	if type(enchant.name) == "string" and enchant.name ~= "" then
		return enchant.name
	end
	local enchantId = tonumber(enchant.enchantId)
	if not enchantId or enchantId <= 0 then
		return nil
	end
	local info = Addon.GetGearCheckEnchantInfo and Addon:GetGearCheckEnchantInfo(enchantId)
	if info and type(info.name) == "string" and info.name ~= "" then
		return info.name
	end
	return nil
end

local function ResolveGemDumpName(gem)
	if type(gem) ~= "table" then
		return nil
	end
	if type(gem.name) == "string" and gem.name ~= "" then
		return gem.name
	end
	local itemId = tonumber(gem.itemId)
	if not itemId or itemId <= 0 then
		return nil
	end
	local name
	local ok = pcall(function()
		name = GetItemInfo(itemId)
	end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

local function FormatStatsBrief(stats)
	if type(stats) ~= "table" then
		return "-"
	end
	local keys = {}
	for key in pairs(stats) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	if #keys == 0 then
		return "-"
	end
	local parts = {}
	for index = 1, #keys do
		local key = keys[index]
		parts[#parts + 1] = key .. "=" .. tostring(stats[key])
	end
	return table.concat(parts, ", ")
end

local function FormatGapsBrief(gaps)
	if type(gaps) ~= "table" or #gaps == 0 then
		return nil
	end
	local parts = {}
	for index = 1, #gaps do
		local gap = gaps[index]
		if gap.detail then
			parts[#parts + 1] = tostring(gap.code) .. "(" .. tostring(gap.detail) .. ")"
		else
			parts[#parts + 1] = tostring(gap.code)
		end
	end
	return table.concat(parts, ", ")
end

function Addon:FormatGearCheckDump(report)
	if not report then
		return "No Gear Check data."
	end

	local character = report.character or {}
	local collection = report.collection or {}
	local inspect = collection.inspect or report.inspect or {}
	local counts = collection.counts or report.stats or {}
	local equipment = Addon:GetGearCheckEquipment(report)
	local findings = report.findings or {}
	local profile = report.profile
	local verdicts = report.verdicts
	local overall = report.overall
	local meta = report.meta
	local sets = report.sets

	local lines = {}
	lines[#lines + 1] = "Raidwise Gear Check — Phase 5 snapshot (overall + meta + sets)"
	lines[#lines + 1] = "schemaVersion=" .. tostring(report.schemaVersion or "?")
	lines[#lines + 1] = "Overall is worst-wins of item verdicts (S < A < B < C < D); Resilience 1→C, 2+→D. S = item ID on published BiS lists. Set counts are informational."
	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format(
		"Unit: %s (%s)%s",
		tostring(character.unit or "?"),
		tostring(character.name or report.name or "?"),
		(character.isSelf or report.isSelf) and " [self]" or ""
	)
	if character.realm and character.realm ~= "" then
		lines[#lines + 1] = "Realm: " .. tostring(character.realm)
	end
	lines[#lines + 1] = string.format(
		"Class: %s (%s)",
		tostring(character.className or "?"),
		tostring(character.classFile or "?")
	)
	if character.specKnown then
		lines[#lines + 1] = string.format(
			"Spec: %s (tab %d)",
			tostring(character.specName ~= "" and character.specName or "?"),
			tonumber(character.specTab) or 0
		)
	else
		lines[#lines + 1] = "Spec: unknown (class-only rules will apply; gap SPEC_UNKNOWN)"
	end
	if profile then
		lines[#lines + 1] = string.format(
			"Profile: %s (source=%s)",
			tostring(profile.name or "?"),
			tostring(profile.source or "?")
		)
	end
	local charGaps = FormatGapsBrief(character.gaps)
	if charGaps then
		lines[#lines + 1] = "Character gaps: " .. charGaps
	end
	lines[#lines + 1] = string.format(
		"Checked slots filled: %d / %d",
		counts.filledCheckedSlots or 0,
		counts.checkedSlots or 0
	)
	local stats = report.stats or {}
	local gearScore = stats.gearScore or character.gearScore
	local averageIlvl = stats.averageIlvl or character.averageIlvl
	lines[#lines + 1] = string.format(
		"GearScore: %s  Average iLvl: %s",
		gearScore ~= nil and tostring(gearScore) or "-",
		averageIlvl ~= nil and tostring(averageIlvl) or "-"
	)
	local scanState, scanReason = Addon:GetGearCheckScanState(report)
	lines[#lines + 1] = "Scan: " .. scanState .. (scanReason and " (" .. scanReason .. ")" or "")
	if inspect.tooFar then
		lines[#lines + 1] = "Inspect: too far"
	elseif inspect.needed and not inspect.canInspect then
		lines[#lines + 1] = "Inspect: not available"
	elseif inspect.needed and not inspect.complete then
		lines[#lines + 1] = "Inspect: pending / incomplete"
	elseif inspect.needed then
		lines[#lines + 1] = "Inspect: ok"
	end
	if verdicts then
		lines[#lines + 1] = string.format(
			"Item verdicts: S=%d  A=%d  B=%d  C=%d  D=%d  (skipped=%d)",
			verdicts.s or 0,
			verdicts.a or 0,
			verdicts.b or 0,
			verdicts.c or 0,
			verdicts.d or 0,
			verdicts.skipped or 0
		)
	end
	if overall then
		lines[#lines + 1] = string.format(
			"Overall: %s — %s",
			tostring(overall.status or "?"),
			tostring(overall.summary or "")
		)
		local issues = overall.issues or {}
		lines[#lines + 1] = string.format(
			"Issues: items=%d  enchants=%d  gems=%d  meta=%s  resilienceItems=%d",
			issues.items or 0,
			issues.enchants or 0,
			issues.gems or 0,
			self:GetGearCheckMetaSummary(report),
			overall.resilienceItems or 0
		)
	end
	if meta and meta.present then
		local activeText = "unknown"
		if meta.active == true then
			activeText = "yes"
		elseif meta.active == false then
			activeText = "no"
		end
		local metaName = ResolveGemDumpName({ itemId = meta.itemId, name = meta.name })
		if metaName then
			lines[#lines + 1] = string.format(
				"Meta: id=%s name=%s slot=%s active=%s",
				tostring(meta.itemId or "?"),
				metaName,
				tostring(meta.slot or "?"),
				activeText
			)
		else
			lines[#lines + 1] = string.format(
				"Meta: id=%s slot=%s active=%s",
				tostring(meta.itemId or "?"),
				tostring(meta.slot or "?"),
				activeText
			)
		end
	end
	if sets and #sets > 0 then
		local setParts = {}
		for index = 1, #sets do
			local row = sets[index]
			setParts[#setParts + 1] = string.format("%s: %d/%d", row.key, row.equipped or 0, row.pieces or 5)
		end
		lines[#lines + 1] = "Sets (informational): " .. table.concat(setParts, ", ")
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Equipment:"

	for index = 1, #equipment do
		local slot = equipment[index]
		local policy = slot.policy or "?"
		local note = slot.policyNote and (" / " .. slot.policyNote) or ""
		if slot.empty or not slot.item then
			lines[#lines + 1] = string.format(
				"  [%s%s] %s — empty",
				policy,
				note,
				slot.slotName
			)
		else
			local item = slot.item
			local name = item.name or (item.pendingLink and "(link pending)" or "unknown")
			local ilvl = item.itemLevel and tostring(item.itemLevel) or "-"
			local verdict = slot.verdict and ("  verdict=" .. slot.verdict) or ""
			lines[#lines + 1] = string.format(
				"  [%s%s] %s — id=%s  ilvl=%s  %s%s",
				policy,
				note,
				slot.slotName,
				tostring(item.itemId),
				ilvl,
				name,
				verdict
			)
			lines[#lines + 1] = string.format(
				"      category=%s  armorType=%s  weaponType=%s  relic=%s  equipLoc=%s",
				tostring(item.category or "-"),
				tostring(item.armorType or "-"),
				tostring(item.weaponType or "-"),
				item.isRelic and "yes" or "no",
				tostring(item.equipLoc or "-")
			)
			lines[#lines + 1] = "      stats: " .. FormatStatsBrief(item.stats)
			local sockets = item.sockets or {}
			lines[#lines + 1] = string.format(
				"      sockets: total=%s empty=%s meta=%s red=%s yellow=%s blue=%s prismatic=%s",
				tostring(sockets.total or 0),
				tostring(sockets.empty or 0),
				tostring(sockets.meta or 0),
				tostring(sockets.red or 0),
				tostring(sockets.yellow or 0),
				tostring(sockets.blue or 0),
				tostring(sockets.prismatic or 0)
			)
			lines[#lines + 1] = "      socketData: uncertain=" .. tostring(sockets.gemDataUncertain == true)
				.. " emptyConfirmed=" .. tostring(sockets.emptyConfirmed == true)
			lines[#lines + 1] = "      itemLink: " .. tostring(item.link or "-")
			local enchant = item.enchant or {}
			local enchantName = ResolveEnchantDumpName(enchant)
			if enchantName then
				lines[#lines + 1] = string.format(
					"      enchant: id=%s present=%s known=%s name=%s",
					tostring(enchant.enchantId or 0),
					enchant.present and "yes" or "no",
					enchant.known and "yes" or "no",
					enchantName
				)
			else
				lines[#lines + 1] = string.format(
					"      enchant: id=%s present=%s known=%s",
					tostring(enchant.enchantId or 0),
					enchant.present and "yes" or "no",
					enchant.known and "yes" or "no"
				)
			end
			if item.gems and #item.gems > 0 then
				local gemParts = {}
				for g = 1, #item.gems do
					local gem = item.gems[g]
					local gemName = ResolveGemDumpName(gem)
					lines[#lines + 1] = "      socket #" .. tostring(gem.socketIndex or g)
						.. ": state=" .. tostring(gem.state or "unknown")
						.. " enchantId=" .. tostring(gem.enchantId or 0)
					if gemName then
						gemParts[#gemParts + 1] = string.format(
							"#%d=%s %s%s name=%s",
							gem.socketIndex or g,
							tostring(gem.itemId),
							tostring(gem.color or "unknown"),
							gem.isMeta and " meta" or "",
							gemName
						)
					else
						gemParts[#gemParts + 1] = string.format(
							"#%d=%s %s%s",
							gem.socketIndex or g,
							tostring(gem.itemId),
							tostring(gem.color or "unknown"),
							gem.isMeta and " meta" or ""
						)
					end
				end
				lines[#lines + 1] = "      gems: " .. table.concat(gemParts, ", ")
			else
				lines[#lines + 1] = "      gems: (none detected)"
			end
			if item.metaGemId then
				lines[#lines + 1] = "      metaGemId=" .. tostring(item.metaGemId)
			end
			local itemGaps = FormatGapsBrief(item.gaps)
			if itemGaps then
				lines[#lines + 1] = "      gaps: " .. itemGaps
			end
			local slotGaps = FormatGapsBrief(slot.gaps)
			if slotGaps then
				lines[#lines + 1] = "      slotGaps: " .. slotGaps
			end
			local enchantGaps = FormatGapsBrief(enchant.gaps)
			if enchantGaps then
				lines[#lines + 1] = "      enchantGaps: " .. enchantGaps
			end
		end
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format("Findings (%d):", #findings)
	if #findings == 0 then
		lines[#lines + 1] = "  (none)"
	else
		for index = 1, #findings do
			local finding = findings[index]
			lines[#lines + 1] = string.format(
				"  [%s/%s] %s%s — %s",
				tostring(finding.severity or "?"),
				tostring(finding.category or "?"),
				tostring(finding.code or "?"),
				finding.slot and (" @" .. finding.slot) or "",
				tostring(finding.message or "")
			)
		end
	end

	return table.concat(lines, "\n")
end

function Addon:FormatGearCheckPhase1Dump(report)
	return self:FormatGearCheckDump(report)
end

local RAID_DUMP_SEPARATOR = "\n\n" .. string.rep("=", 72) .. "\n\n"
local raidDumpJob = nil
local raidDumpFrame = CreateFrame("Frame")
raidDumpFrame:Hide()

local function FormatRaidDumpEntry(entry)
	if entry and entry.report then
		return Addon:FormatGearCheckDump(entry.report), true
	end
	local member = entry and entry.member or {}
	local lines = {
		"Raidwise Gear Check — raid scan entry (no report)",
		string.format("Player: %s", tostring(member.name or "?")),
		string.format("Status: %s", tostring(entry and entry.status or "unknown")),
	}
	return table.concat(lines, "\n"), false
end

local function FinishRaidDumpJob(text)
	local onComplete = raidDumpJob and raidDumpJob.onComplete
	raidDumpJob = nil
	raidDumpFrame:Hide()
	if onComplete then
		onComplete(text or "")
	end
end

raidDumpFrame:SetScript("OnUpdate", function()
	local job = raidDumpJob
	if not job then
		raidDumpFrame:Hide()
		return
	end
	local results = job.results
	local index = job.index
	if index > #results then
		local header = string.format(
			"Raidwise Gear Check — raid scan export (%d players, %d reports, %d failed/skipped)",
			#results,
			job.scanned,
			job.failed
		)
		FinishRaidDumpJob(header .. "\n" .. string.rep("-", 72) .. "\n\n" .. table.concat(job.parts, RAID_DUMP_SEPARATOR))
		return
	end

	local entry = results[index]
	local part, ok = FormatRaidDumpEntry(entry)
	job.parts[#job.parts + 1] = part
	if ok then
		job.scanned = job.scanned + 1
	else
		job.failed = job.failed + 1
	end
	job.index = index + 1
	if job.onProgress then
		job.onProgress(index, #results, entry and entry.member)
	end
end)

function Addon:FormatGearCheckRaidDump(results)
	if type(results) ~= "table" or #results == 0 then
		return ""
	end

	local parts = {}
	local scanned = 0
	local failed = 0
	for index = 1, #results do
		local entry = results[index]
		local part, ok = FormatRaidDumpEntry(entry)
		parts[#parts + 1] = part
		if ok then
			scanned = scanned + 1
		else
			failed = failed + 1
		end
	end

	local header = string.format(
		"Raidwise Gear Check — raid scan export (%d players, %d reports, %d failed/skipped)",
		#results,
		scanned,
		failed
	)
	return header .. "\n" .. string.rep("-", 72) .. "\n\n" .. table.concat(parts, RAID_DUMP_SEPARATOR)
end

function Addon:IsGearCheckRaidDumpBusy()
	return raidDumpJob ~= nil
end

function Addon:CancelGearCheckRaidDump()
	if not raidDumpJob then
		return
	end
	local onComplete = raidDumpJob.onComplete
	raidDumpJob = nil
	raidDumpFrame:Hide()
	if onComplete then
		onComplete(nil)
	end
end

-- Builds the raid dump one player per frame to avoid freezing the UI on large rosters.
function Addon:BuildGearCheckRaidDumpAsync(results, onProgress, onComplete)
	if type(results) ~= "table" or #results == 0 then
		if onComplete then
			onComplete("")
		end
		return false
	end
	if raidDumpJob then
		return false
	end
	raidDumpJob = {
		results = results,
		index = 1,
		parts = {},
		scanned = 0,
		failed = 0,
		onProgress = onProgress,
		onComplete = onComplete,
	}
	raidDumpFrame:Show()
	return true
end

function Addon:ShowGearCheckRaidDump(results)
	results = results
		or (self.GetLastGearCheckRaidResults and self:GetLastGearCheckRaidResults())
		or {}
	local text = self:FormatGearCheckRaidDump(results)
	if text == "" then
		self:Print(self:T("GEAR_CHECK_RAID_EXPORT_EMPTY"))
		return false
	end
	if self.ShowRaidGearCheckExportText then
		self:ShowRaidGearCheckExportText(text)
	elseif self.ShowGearCheckDumpText then
		self:ShowGearCheckDumpText(text)
	else
		self:Print(self:T("GEAR_CHECK_STATUS_FAIL"))
		return false
	end
	return true
end

