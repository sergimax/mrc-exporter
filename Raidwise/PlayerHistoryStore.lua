-- History storage, legacy migration, encounters, and persistence.
local Addon = Raidwise

local LEGACY_TAG_TO_FACT = {
	raid_leader = "raid_leader",
	pug_leader = "pug_raid_leader",
	pug_raid_leader = "pug_raid_leader",
	guild_master = "guild_master",
	guild_officer = "guild_officer",
}

local LEGACY_TAG_TO_EVENT = {
	late = "late_arrival",
	afk = "afk",
	leaves_early = "left_early",
	rage_quit = "rage_quit",
	ninja_looter = "ninja_loot",
	loot_drama = "loot_dispute",
	unfair_loot = "unfair_loot_distribution",
}

local LEGACY_TAG_DROP = {
	raid_organizer = true,
	experienced = true,
}

local function LocalPlayerCreatorId()
	if type(UnitGUID) == "function" then
		return UnitGUID("player") or ""
	end
	return ""
end

local function AppendMigratedEvent(entry, eventTypeId, eventAt, creatorId)
	if not Addon:EventTypeById(eventTypeId) then
		return
	end
	if type(entry.events) ~= "table" then
		entry.events = {}
	end
	for index = 1, #entry.events do
		local existing = entry.events[index]
		if type(existing) == "table" and existing.type == eventTypeId and existing._migrated then
			return
		end
	end
	entry.events[#entry.events + 1] = {
		id = string.format("mig-%s-%d", eventTypeId, #entry.events + 1),
		type = eventTypeId,
		creatorId = creatorId or "",
		eventAt = tonumber(eventAt) or time(),
		context = {},
		_migrated = true,
	}
end

-- REFACTOR candidate: one-shot v1→v2 migration routing tags into facts/events/drops.
function Addon:MigrateLegacyPersonalTags(entry, personal)
	if personal.reputationV2 then
		return
	end
	local rawTags = type(personal.tags) == "table" and personal.tags or {}
	local rawFacts = type(personal.facts) == "table" and personal.facts or {}
	local keptTags = {}
	local facts = {}
	local factSeen = {}
	for index = 1, #rawFacts do
		local factId = LEGACY_TAG_TO_FACT[rawFacts[index]] or rawFacts[index]
		if Addon:FactById(factId) and not factSeen[factId] then
			factSeen[factId] = true
			facts[#facts + 1] = factId
		end
	end
	local eventAt = tonumber(personal.updatedAt) or time()
	local creatorId = personal.creatorId
	if type(creatorId) ~= "string" then
		creatorId = ""
	end
	for index = 1, #rawTags do
		local tagId = rawTags[index]
		local factId = LEGACY_TAG_TO_FACT[tagId]
		if factId then
			if not factSeen[factId] then
				factSeen[factId] = true
				facts[#facts + 1] = factId
			end
		elseif LEGACY_TAG_TO_EVENT[tagId] then
			AppendMigratedEvent(entry, LEGACY_TAG_TO_EVENT[tagId], eventAt, creatorId)
		elseif LEGACY_TAG_DROP[tagId] then
			-- dropped
		elseif Addon:RatingTagById(tagId) then
			keptTags[#keptTags + 1] = tagId
		end
	end
	personal.tags = keptTags
	personal.facts = facts
	personal.reputationV2 = true
end

function Addon:CaptureEventContext()
	local context = {
		zoneName = "",
		zoneId = nil,
		instanceId = nil,
		instanceName = "",
		difficulty = nil,
		itemId = nil,
		bossId = nil,
	}
	if type(GetRealZoneText) == "function" then
		context.zoneName = GetRealZoneText() or ""
	elseif type(GetZoneText) == "function" then
		context.zoneName = GetZoneText() or ""
	end
	if type(GetCurrentMapAreaID) == "function" then
		local zoneId = GetCurrentMapAreaID()
		if zoneId and zoneId ~= 0 then
			context.zoneId = zoneId
		end
	end
	if type(GetInstanceInfo) == "function" then
		local name, instanceType, difficultyIndex, difficultyName = GetInstanceInfo()
		if name and name ~= "" and (instanceType == "raid" or instanceType == "party") then
			context.instanceName = name
			if difficultyName and difficultyName ~= "" then
				context.difficulty = difficultyName
			elseif difficultyIndex then
				context.difficulty = difficultyIndex
			end
		end
	end
	return context
end

local function CopyIfValue(dest, src, key)
	local value = src[key]
	if value == nil or value == "" then
		return
	end
	dest[key] = value
end

local function MeetingZone()
	if type(GetInstanceInfo) == "function" then
		local name, instanceType = GetInstanceInfo()
		if name and name ~= "" and (instanceType == "raid" or instanceType == "party") then
			return name
		end
	end
	if type(GetRealZoneText) == "function" then
		local zone = GetRealZoneText()
		if zone and zone ~= "" then
			return zone
		end
	end
	if type(GetZoneText) == "function" then
		return GetZoneText() or ""
	end
	return ""
end

local function MeetingRealm()
	if type(GetRealmName) == "function" then
		return GetRealmName() or ""
	end
	return ""
end

local function CharacterRealm(member)
	if member and member.realm and member.realm ~= "" then
		return member.realm
	end
	return MeetingRealm()
end

local function GroupHistoryUnits()
	local units = {}
	local raidCount = (GetNumRaidMembers and GetNumRaidMembers()) or 0
	if raidCount > 0 then
		for index = 1, raidCount do
			local unit = "raid" .. index
			if UnitExists(unit) and not UnitIsUnit(unit, "player") then
				units[#units + 1] = unit
			end
		end
		return units
	end

	local partyCount = math.min(GetNumPartyMembers() or 0, 4)
	for index = 1, partyCount do
		local unit = "party" .. index
		if UnitExists(unit) then
			units[#units + 1] = unit
		end
	end
	return units
end

function Addon:HistoryStore()
	if not self.db then
		return {}
	end
	if type(self.db.history) ~= "table" then
		self.db.history = {}
	end
	return self.db.history
end

function Addon:FormatHistoryTime(timestamp)
	timestamp = tonumber(timestamp)
	if not timestamp or timestamp <= 0 then
		return "-"
	end
	return date("%Y-%m-%d %H:%M", timestamp)
end

local MAX_PROFILE_HISTORY_CHANGES = 50

local function TagsEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	if #left ~= #right then
		return false
	end
	local seen = {}
	for index = 1, #left do
		seen[left[index]] = (seen[left[index]] or 0) + 1
	end
	for index = 1, #right do
		local tagId = right[index]
		if not seen[tagId] or seen[tagId] <= 0 then
			return false
		end
		seen[tagId] = seen[tagId] - 1
	end
	return true
end

-- Gap since lastSeenAt before another party/raid encounter counts as a new meeting.
local GROUP_MEETING_GAP_SEC = 30 * 60
local SAME_PARTY_EVENT_TYPE = "same_party"

local function EnsureHistoryFields(entry)
	if type(entry.notes) ~= "string" then
		entry.notes = ""
	end
	if type(entry.tags) ~= "table" then
		entry.tags = {}
	end
	if type(entry.links) ~= "table" then
		entry.links = {}
	end
	if type(entry.changes) ~= "table" then
		entry.changes = {}
	end
	if type(entry.events) ~= "table" then
		entry.events = {}
	end
	local metAt = tonumber(entry.metAt) or 0
	local lastSeenAt = tonumber(entry.lastSeenAt) or 0
	if metAt > 0 and lastSeenAt <= 0 then
		entry.lastSeenAt = metAt
	end
	if type(entry.meetCount) ~= "number" or entry.meetCount < 1 then
		entry.meetCount = metAt > 0 and 1 or 0
	end
	if Addon.EnsurePersonalRating then
		Addon:EnsurePersonalRating(entry)
	end
	return entry
end

-- Explicit load boundary; getters never migrate persisted entries.
function Addon:InitializeHistoryStore()
	for _, entry in pairs(self:HistoryStore()) do
		if type(entry) == "table" then EnsureHistoryFields(entry) end
	end
end

function Addon:AppendProfileHistoryChange(entry, kind, detail)
	if type(entry) ~= "table" or not kind or kind == "" then
		return
	end
	EnsureHistoryFields(entry)
	entry.changes[#entry.changes + 1] = {
		at = time(),
		kind = kind,
		detail = detail or "",
	}
	while #entry.changes > MAX_PROFILE_HISTORY_CHANGES do
		table.remove(entry.changes, 1)
	end
end

function Addon:GetHistoryEntry(guid)
	if not guid or guid == "" then
		return nil
	end
	local store = self.db and self.db.history
	return type(store) == "table" and store[guid] or nil
end

function Addon:EnsureHistoryEntryForGuid(guid, seed)
	if not guid or guid == "" then
		return nil
	end
	local store = self:HistoryStore()
	local entry = store[guid]
	if not entry then
		entry = {
			guid = guid,
			name = (seed and seed.name) or "?",
			realm = (seed and CharacterRealm(seed)) or "",
			class = (seed and seed.class) or "",
			classLabel = (seed and seed.classLabel) or "",
			spec = (seed and seed.spec) or "",
			specIcon = (seed and seed.specIcon) or "",
			race = (seed and seed.race) or "",
			faction = (seed and seed.faction) or "",
			gender = seed and seed.gender or nil,
			gearScore = seed and seed.gearScore or nil,
			averageIlvl = seed and seed.averageIlvl or nil,
			guildName = seed and seed.guildName or nil,
			guildRank = seed and seed.guildRank or nil,
			notes = "",
			tags = {},
			links = {},
			changes = {},
			events = {},
			metZone = "",
			metAt = 0,
			metRealm = "",
			lastSeenAt = 0,
			lastSeenZone = "",
			meetCount = 0,
		}
		store[guid] = entry
	end
	return EnsureHistoryFields(entry)
end

-- Target scans create first encounters without adding a same-party event.
function Addon:RecordTargetScanHistory(report)
	local character = report and report.character
	if not character or character.isSelf or not character.guid or character.guid == "" then
		return
	end
	if self:GetHistoryEntry(character.guid) then
		return
	end
	local entry = self:EnsureHistoryEntryForGuid(character.guid, {
		name = character.name,
		realm = character.realm,
		class = character.classFile,
		classLabel = character.className,
		spec = character.specKnown and character.specName or nil,
		specIcon = character.specKnown and character.specIcon or nil,
		gearScore = character.gearScore,
		averageIlvl = character.averageIlvl,
	})
	local scannedAt = tonumber(report.collection and report.collection.collectedAt) or time()
	entry.metZone = self:T("HISTORY_TARGET_SCAN")
	entry.metAt = scannedAt
	entry.metRealm = MeetingRealm()
	entry.lastSeenAt = scannedAt
	entry.lastSeenZone = entry.metZone
	entry.meetCount = 1
	local frame = self.mainFrame
	if frame and frame:IsShown() and frame.selectedTab == "history" and self.RefreshHistoryView then
		self:RefreshHistoryView()
	end
end

function Addon:UpsertHistoryMember(member)
	if type(member) ~= "table" then
		return nil
	end

	local guid = member.guid
	if not guid or guid == "" then
		return nil
	end

	local entry = self:EnsureHistoryEntryForGuid(guid, member)
	local now = time()
	local zone = MeetingZone()
	local metRealm = MeetingRealm()

	local countedMeeting = false
	if not entry.metAt or entry.metAt <= 0 then
		entry.metZone = zone
		entry.metAt = now
		entry.metRealm = metRealm
		entry.lastSeenAt = now
		entry.lastSeenZone = zone
		entry.meetCount = 1
		countedMeeting = true
	else
		EnsureHistoryFields(entry)
		local previousSeen = tonumber(entry.lastSeenAt) or 0
		local meetCount = tonumber(entry.meetCount) or 1
		if meetCount < 1 then
			meetCount = 1
		end
		-- Count another grouping only after a quiet gap (avoids +1 on every roster refresh).
		if previousSeen <= 0 or (now - previousSeen) >= GROUP_MEETING_GAP_SEC then
			meetCount = meetCount + 1
			countedMeeting = true
		end
		entry.meetCount = meetCount
	end

	CopyIfValue(entry, member, "name")
	CopyIfValue(entry, member, "class")
	CopyIfValue(entry, member, "classLabel")
	CopyIfValue(entry, member, "spec")
	CopyIfValue(entry, member, "specIcon")
	CopyIfValue(entry, member, "race")
	CopyIfValue(entry, member, "faction")
	if member.gender then
		entry.gender = member.gender
	end
	CopyIfValue(entry, member, "guildName")
	CopyIfValue(entry, member, "guildRank")
	if CharacterRealm(member) ~= "" then
		entry.realm = CharacterRealm(member)
	end
	if member.gearScore then
		entry.gearScore = member.gearScore
	end
	if member.averageIlvl then
		entry.averageIlvl = member.averageIlvl
	end
	entry.lastSeenAt = now
	if zone ~= "" then
		entry.lastSeenZone = zone
	end
	if countedMeeting then
		self:AddHistoryEventForGuid(guid, member, SAME_PARTY_EVENT_TYPE)
	end
	return entry
end

function Addon:RecordCurrentGroupHistory(refreshGearScore, rosterSnapshot)
	if not self.db then
		return
	end

	local collect = self.CollectPartyMember or self.CollectRaidMember
	for _, unit in ipairs(GroupHistoryUnits()) do
		local member = rosterSnapshot and rosterSnapshot.byUnit[unit]
		if member and member.guid ~= UnitGUID(unit) then member = nil end
		if not member and collect then
			local ok, snapshot = pcall(collect, self, unit, refreshGearScore)
			if ok and type(snapshot) == "table" then
				member = snapshot
			end
		end
		if not member then
			local name, realm = UnitName(unit)
			local localizedClass, classToken = UnitClass(unit)
			member = {
				unit = unit,
				guid = UnitGUID(unit) or "",
				name = name or "?",
				realm = realm or "",
				class = classToken or "",
				classLabel = localizedClass or "",
			}
		end
		self:UpsertHistoryMember(member)
	end

	local frame = self.mainFrame
	if frame and frame:IsShown() and frame.selectedTab == "history" and self.RefreshHistoryView then
		self:RefreshHistoryView()
	end
end

function Addon:BuildHistoryRoster()
	local roster = {}
	local store = self.db and self.db.history or {}
	for _, entry in pairs(store) do
		if type(entry) == "table" then
			roster[#roster + 1] = entry
		end
	end

	table.sort(roster, function(left, right)
		local leftSeen = tonumber(left.lastSeenAt) or 0
		local rightSeen = tonumber(right.lastSeenAt) or 0
		if leftSeen ~= rightSeen then
			return leftSeen > rightSeen
		end
		return (left.name or "") < (right.name or "")
	end)

	return roster
end

-- REFACTOR candidate: long field-by-field merge of live roster member vs SavedVariables history.
function Addon:HistoryProfileForMember(member)
	if type(member) ~= "table" then
		return member
	end

	local guid = member.guid
	if (not guid or guid == "") and member.unit then
		guid = UnitGUID(member.unit) or ""
	end

	local saved = self:GetHistoryEntry(guid)
	local profile = {}
	for key, value in pairs(member) do
		profile[key] = value
	end
	profile.guid = guid or ""

	if saved then
		if not profile.metZone or profile.metZone == "" then
			profile.metZone = saved.metZone
		end
		if not profile.metAt then
			profile.metAt = saved.metAt
		end
		if not profile.metRealm or profile.metRealm == "" then
			profile.metRealm = saved.metRealm
		end
		if type(saved.meetCount) == "number" then
			profile.meetCount = saved.meetCount
		end
		if (not profile.spec or profile.spec == "") and saved.spec and saved.spec ~= "" then
			profile.spec = saved.spec
			profile.specIcon = saved.specIcon
		end
		if not profile.gearScore and saved.gearScore then
			profile.gearScore = saved.gearScore
		end
		if not profile.averageIlvl and saved.averageIlvl then
			profile.averageIlvl = saved.averageIlvl
		end
		if not profile.race or profile.race == "" then
			profile.race = saved.race
		end
		if not profile.faction or profile.faction == "" then
			profile.faction = saved.faction
		end
		if not profile.gender and saved.gender then
			profile.gender = saved.gender
		end
		if type(saved.notes) == "string" then
			profile.notes = saved.notes
		end
		if type(saved.tags) == "table" and #saved.tags > 0 then
			profile.tags = saved.tags
		end
		if type(saved.links) == "table" then
			profile.links = saved.links
		end
		if type(saved.changes) == "table" then
			profile.changes = saved.changes
		end
		if type(saved.events) == "table" then
			profile.events = saved.events
		end
		if saved.rating then
			profile.rating = {
				personal = self.GetPersonalRating and self:GetPersonalRating(saved) or saved.rating.personal,
			}
		end
	end

	if self.GetPersonalRating then
		profile.rating = profile.rating or {}
		profile.rating.personal = self:GetPersonalRating(profile)
	end
	if self.GetHistoryEvents then
		profile.events = self:GetHistoryEvents(profile)
	end

	return profile
end

-- REFACTOR candidate: normalize + diff logging for opinion/tags/facts in one function.
function Addon:SavePersonalRatingForGuid(guid, seed, opinion, tagIds, factIds)
	if not guid or guid == "" then
		return nil
	end
	local entry = self:EnsureHistoryEntryForGuid(guid, seed)
	if not entry then
		return nil
	end
	local personal = self:EnsurePersonalRating(entry)
	local previousOpinion = personal.opinion
	local previousTags = {}
	for index = 1, #personal.tags do
		previousTags[index] = personal.tags[index]
	end
	local previousFacts = {}
	for index = 1, #(personal.facts or {}) do
		previousFacts[index] = personal.facts[index]
	end
	if seed then
		CopyIfValue(entry, seed, "name")
		CopyIfValue(entry, seed, "class")
		CopyIfValue(entry, seed, "classLabel")
		CopyIfValue(entry, seed, "spec")
		CopyIfValue(entry, seed, "specIcon")
		CopyIfValue(entry, seed, "race")
		CopyIfValue(entry, seed, "faction")
		if seed.gender then
			entry.gender = seed.gender
		end
		CopyIfValue(entry, seed, "guildName")
		CopyIfValue(entry, seed, "guildRank")
		if CharacterRealm(seed) ~= "" then
			entry.realm = CharacterRealm(seed)
		end
	end
	local now = time()
	personal.opinion = self:NormalizePersonalOpinion(opinion)
	personal.tags = self:NormalizePersonalTags(tagIds)
	if factIds ~= nil then
		personal.facts = self:NormalizePersonalFacts(factIds)
	else
		personal.facts = self:NormalizePersonalFacts(personal.facts)
	end
	if personal.createdAt <= 0 then
		personal.createdAt = now
	end
	personal.updatedAt = now
	local creatorId = LocalPlayerCreatorId()
	if creatorId ~= "" then
		personal.creatorId = creatorId
	end
	if previousOpinion ~= personal.opinion then
		self:AppendProfileHistoryChange(entry, "opinion", personal.opinion)
	end
	if not TagsEqual(previousTags, personal.tags) then
		local tagSummary = self.RatingTagSummary and self:RatingTagSummary(personal.tags, 5) or ""
		self:AppendProfileHistoryChange(entry, "tags", tagSummary)
	end
	if factIds ~= nil and not TagsEqual(previousFacts, personal.facts) then
		local factSummary = self.FactSummary and self:FactSummary(personal.facts, 5) or ""
		self:AppendProfileHistoryChange(entry, "facts", factSummary)
	end
	return entry
end

-- REFACTOR candidate: diff draft vs stored events, assign IDs, append change log.
function Addon:SaveHistoryEventsForGuid(guid, seed, draftEvents)
	if not guid or guid == "" then
		return nil
	end
	local entry = self:EnsureHistoryEntryForGuid(guid, seed)
	if not entry then
		return nil
	end
	EnsureHistoryFields(entry)
	if seed then
		CopyIfValue(entry, seed, "name")
		CopyIfValue(entry, seed, "class")
		CopyIfValue(entry, seed, "classLabel")
	end

	local previousById = {}
	for index = 1, #entry.events do
		local event = entry.events[index]
		if type(event) == "table" and event.id and event.id ~= "" then
			previousById[event.id] = event
		end
	end

	local nextEvents = {}
	local draftById = {}
	local source = type(draftEvents) == "table" and draftEvents or {}
	for index = 1, #source do
		local event = source[index]
		if type(event) == "table" and self:IsValidEventType(event.type) then
			local eventId = event.id
			if type(eventId) ~= "string" or eventId == "" then
				eventId = string.format("%d-%d", time(), #nextEvents + 1)
			end
			local context = {}
			if type(event.context) == "table" then
				for key, value in pairs(event.context) do
					context[key] = value
				end
			end
			local stored = {
				id = eventId,
				type = event.type,
				creatorId = (type(event.creatorId) == "string" and event.creatorId ~= "") and event.creatorId or LocalPlayerCreatorId(),
				eventAt = tonumber(event.eventAt) or time(),
				context = context,
			}
			nextEvents[#nextEvents + 1] = stored
			draftById[eventId] = stored
			if not previousById[eventId] then
				self:AppendProfileHistoryChange(entry, "event_add", stored.type)
			end
		end
	end

	for eventId, previous in pairs(previousById) do
		if not draftById[eventId] then
			self:AppendProfileHistoryChange(entry, "event_remove", previous.type)
		end
	end

	entry.events = nextEvents
	return entry
end

function Addon:AddHistoryEventForGuid(guid, seed, eventTypeId)
	if not guid or guid == "" or not self:IsValidEventType(eventTypeId) then
		return nil
	end
	local entry = self:EnsureHistoryEntryForGuid(guid, seed)
	if not entry then
		return nil
	end
	EnsureHistoryFields(entry)
	local event = {
		id = string.format("%d-%d", time(), #entry.events + 1),
		type = eventTypeId,
		creatorId = LocalPlayerCreatorId(),
		eventAt = time(),
		context = self:CaptureEventContext(),
	}
	entry.events[#entry.events + 1] = event
	self:AppendProfileHistoryChange(entry, "event_add", eventTypeId)
	if self.SyncOpenProfileHistoryEvent then
		self:SyncOpenProfileHistoryEvent(entry, event)
	end
	return entry, event
end

-- DELETE candidate: no callers; removal is draft-only via RemoveProfileEvent.
function Addon:RemoveHistoryEventForGuid(guid, eventId)
	if not guid or guid == "" or not eventId or eventId == "" then
		return nil
	end
	local entry = self:GetHistoryEntry(guid)
	if not entry then
		return nil
	end
	EnsureHistoryFields(entry)
	local removedType = nil
	local nextEvents = {}
	for index = 1, #entry.events do
		local event = entry.events[index]
		if type(event) == "table" and event.id == eventId then
			removedType = event.type
		else
			nextEvents[#nextEvents + 1] = event
		end
	end
	if not removedType then
		return entry
	end
	entry.events = nextEvents
	self:AppendProfileHistoryChange(entry, "event_remove", removedType)
	return entry
end

function Addon:SaveProfileNotesForGuid(guid, seed, notes)
	if not guid or guid == "" then
		return nil
	end
	local entry = self:EnsureHistoryEntryForGuid(guid, seed)
	if not entry then
		return nil
	end
	if seed then
		CopyIfValue(entry, seed, "name")
		CopyIfValue(entry, seed, "class")
		CopyIfValue(entry, seed, "classLabel")
		CopyIfValue(entry, seed, "spec")
		CopyIfValue(entry, seed, "specIcon")
		CopyIfValue(entry, seed, "race")
		CopyIfValue(entry, seed, "faction")
		if seed.gender then
			entry.gender = seed.gender
		end
		CopyIfValue(entry, seed, "guildName")
		CopyIfValue(entry, seed, "guildRank")
		if CharacterRealm(seed) ~= "" then
			entry.realm = CharacterRealm(seed)
		end
	end
	entry.notes = type(notes) == "string" and notes or ""
	return entry
end
