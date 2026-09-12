-- Gear Check saved reports (manual save, ~14-day retention). Spec §§25–27.

local Addon = Raidwise

Addon.GEAR_CHECK_RETENTION_SECONDS = 14 * 24 * 60 * 60

local function DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for key, value in pairs(src) do
		dst[key] = DeepCopy(value)
	end
	return dst
end

local function EnsureSavedDB()
	if not Addon.db then
		return nil
	end
	if type(Addon.db.gearCheckSaved) ~= "table" then
		Addon.db.gearCheckSaved = { nextId = 0, reports = {} }
	end
	local saved = Addon.db.gearCheckSaved
	if type(saved.reports) ~= "table" then
		saved.reports = {}
	end
	if type(saved.nextId) ~= "number" then
		saved.nextId = 0
	end
	return saved
end

function Addon:GetGearCheckRulesetVersion()
	return Addon.GEAR_CHECK_RULESET_VERSION or "unknown"
end

function Addon:GetGearCheckDataVersion()
	return Addon.GEAR_CHECK_DATA_VERSION or "unknown"
end

function Addon:GearCheckCharacterKey(report)
	if not report then
		return nil
	end
	local character = report.character or {}
	if character.guid and character.guid ~= "" then
		return character.guid
	end
	local name = character.name or report.name
	if not name or name == "" then
		return nil
	end
	local realm = character.realm
	if not realm or realm == "" then
		realm = GetRealmName and GetRealmName() or "?"
	end
	return name .. "-" .. realm
end

local function PrepareReportSnapshot(report)
	local snapshot = Addon:NormalizeGearCheckReport(DeepCopy(report))
	if snapshot.character then
		snapshot.character.unit = nil
	end
	snapshot.savedSnapshot = true
	return snapshot
end

function Addon:PruneExpiredGearCheckReports(now)
	local saved = EnsureSavedDB()
	if not saved then
		return 0
	end
	now = now or time()
	local removed = 0
	for id, entry in pairs(saved.reports) do
		if not entry or (entry.expiresAt and entry.expiresAt <= now) then
			saved.reports[id] = nil
			removed = removed + 1
		end
	end
	return removed
end

function Addon:SaveGearCheckReport(report)
	if not report then
		return nil, "missing_report"
	end
	local characterKey = self:GearCheckCharacterKey(report)
	if not characterKey then
		return nil, "missing_character"
	end
	local saved = EnsureSavedDB()
	if not saved then
		return nil, "no_db"
	end

	self:PruneExpiredGearCheckReports()

	saved.nextId = (saved.nextId or 0) + 1
	local savedAt = time()
	local id = tostring(savedAt) .. "-" .. tostring(saved.nextId)
	local character = report.character or {}
	local overall = report.overall

	local entry = {
		id = id,
		savedAt = savedAt,
		expiresAt = savedAt + (Addon.GEAR_CHECK_RETENTION_SECONDS or 1209600),
		rulesetVersion = self:GetGearCheckRulesetVersion(),
		dataVersion = self:GetGearCheckDataVersion(),
		characterKey = characterKey,
		characterName = character.name or report.name,
		characterRealm = character.realm,
		classFile = character.classFile,
		specName = character.specName,
		specKnown = character.specKnown,
		overallStatus = overall and overall.status or nil,
		report = PrepareReportSnapshot(report),
	}

	saved.reports[id] = entry
	return id, nil
end

function Addon:ListGearCheckSavedReports(characterKey)
	local saved = EnsureSavedDB()
	if not saved then
		return {}
	end
	self:PruneExpiredGearCheckReports()

	local list = {}
	for id, entry in pairs(saved.reports) do
		if entry and (not characterKey or entry.characterKey == characterKey) then
			list[#list + 1] = entry
		end
	end

	table.sort(list, function(a, b)
		return (a.savedAt or 0) > (b.savedAt or 0)
	end)
	return list
end

function Addon:GetGearCheckSavedReport(id)
	if not id or id == "" then
		return nil
	end
	local saved = EnsureSavedDB()
	if not saved then
		return nil
	end
	self:PruneExpiredGearCheckReports()
	return saved.reports[id]
end

function Addon:DeleteGearCheckSavedReport(id)
	if not id or id == "" then
		return false
	end
	local saved = EnsureSavedDB()
	if not saved or not saved.reports[id] then
		return false
	end
	saved.reports[id] = nil
	return true
end

function Addon:FormatGearCheckSavedLabel(entry)
	if not entry then
		return "?"
	end
	local name = entry.characterName or "?"
	if entry.characterRealm and entry.characterRealm ~= "" then
		name = name .. "-" .. entry.characterRealm
	end
	local dateText = date("%Y-%m-%d %H:%M", entry.savedAt or 0)
	local status = entry.overallStatus or "—"
	return string.format("%s · %s · %s", dateText, name, status)
end

function Addon:GearCheckSavedReportsSelfTest()
	local results = {}
	local passed = 0
	local function Check(name, ok)
		results[#results + 1] = { name = name, ok = ok and true or false }
		if ok then
			passed = passed + 1
		end
	end

	local saved = EnsureSavedDB()
	Check("saved reports db", saved ~= nil)

	local fixture = {
		schemaVersion = 3,
		character = {
			name = "TestPlayer",
			realm = "TestRealm",
			guid = "Player-9999-00000000",
			classFile = "WARRIOR",
			specKnown = false,
		},
		equipment = {},
		overall = { status = "B", reason = "test" },
		findings = {},
	}

	local id, err = self:SaveGearCheckReport(fixture)
	Check("save report", id ~= nil and err == nil)

	local entry = id and self:GetGearCheckSavedReport(id)
	Check("get saved report", entry ~= nil and entry.report ~= nil)
	Check("saved rulesetVersion", entry and entry.rulesetVersion ~= nil and entry.rulesetVersion ~= "")
	Check("saved dataVersion", entry and entry.dataVersion ~= nil and entry.dataVersion ~= "")
	Check("saved characterKey", entry and entry.characterKey == fixture.character.guid)

	local list = self:ListGearCheckSavedReports(fixture.character.guid)
	Check("list by character", #list >= 1)

	if entry then
		entry.expiresAt = time() - 1
		local pruned = self:PruneExpiredGearCheckReports()
		Check("prune expired", pruned >= 1)
		Check("expired removed", self:GetGearCheckSavedReport(id) == nil)
	else
		Check("prune expired", false)
		Check("expired removed", false)
	end

	return results, passed, #results
end
