-- Rating catalogs, normalization, and saved-rating access.
local Addon = Raidwise

local OPINION_ORDER = { "positive", "neutral", "negative" }

local OPINIONS = {
	positive = {
		id = "positive",
		labelKey = "RATING_OPINION_POSITIVE",
		symbol = "+",
		icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_03", -- green
		color = { 0.35, 0.90, 0.35 },
	},
	neutral = {
		id = "neutral",
		labelKey = "RATING_OPINION_NEUTRAL",
		symbol = "=",
		icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_01", -- yellow
		color = { 0.90, 0.82, 0.35 },
	},
	negative = {
		id = "negative",
		labelKey = "RATING_OPINION_NEGATIVE",
		symbol = "-",
		icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_02", -- red
		color = { 0.95, 0.35, 0.35 },
	},
}

local MAX_TAGS_PER_GROUP = 3
local MAX_PERSONAL_FACTS = 4

local TAG_GROUPS = {
	{
		id = "organization",
		labelKey = "RATING_GROUP_ORGANIZATION",
		tags = {
			{ id = "good_raid_leader", labelKey = "RATING_TAG_GOOD_RAID_LEADER", meta = "positive" },
			{ id = "well_organized", labelKey = "RATING_TAG_WELL_ORGANIZED", meta = "positive" },
			{ id = "poor_organization", labelKey = "RATING_TAG_POOR_ORGANIZATION", meta = "negative" },
			{ id = "bad_raid_leader", labelKey = "RATING_TAG_BAD_RAID_LEADER", meta = "negative" },
		},
	},
	{
		id = "behavior",
		labelKey = "RATING_GROUP_BEHAVIOR",
		tags = {
			{ id = "friendly", labelKey = "RATING_TAG_FRIENDLY", meta = "positive" },
			{ id = "helpful", labelKey = "RATING_TAG_HELPFUL", meta = "positive" },
			{ id = "respectful", labelKey = "RATING_TAG_RESPECTFUL", meta = "positive" },
			{ id = "reliable", labelKey = "RATING_TAG_RELIABLE", meta = "positive" },
			{ id = "toxic", labelKey = "RATING_TAG_TOXIC", meta = "negative" },
			{ id = "rude", labelKey = "RATING_TAG_RUDE", meta = "negative" },
			{ id = "aggressive", labelKey = "RATING_TAG_AGGRESSIVE", meta = "negative" },
			{ id = "drama", labelKey = "RATING_TAG_DRAMA", meta = "negative" },
		},
	},
	{
		id = "trust",
		labelKey = "RATING_GROUP_TRUST",
		tags = {
			{ id = "trustworthy", labelKey = "RATING_TAG_TRUSTWORTHY", meta = "positive" },
			{ id = "honest", labelKey = "RATING_TAG_HONEST", meta = "positive" },
			{ id = "fair", labelKey = "RATING_TAG_FAIR", meta = "positive" },
			{ id = "scammer", labelKey = "RATING_TAG_SCAMMER", meta = "negative" },
			{ id = "liar", labelKey = "RATING_TAG_LIAR", meta = "negative" },
			{ id = "untrustworthy", labelKey = "RATING_TAG_UNTRUSTWORTHY", meta = "negative" },
		},
	},
	{
		id = "loot",
		labelKey = "RATING_GROUP_LOOT",
		tags = {
			{ id = "fair_loot", labelKey = "RATING_TAG_FAIR_LOOT", meta = "positive" },
			{ id = "good_loot_master", labelKey = "RATING_TAG_GOOD_LOOT_MASTER", meta = "positive" },
		},
	},
	{
		id = "discipline",
		labelKey = "RATING_GROUP_DISCIPLINE",
		tags = {
			{ id = "on_time", labelKey = "RATING_TAG_ON_TIME", meta = "positive" },
			{ id = "prepared", labelKey = "RATING_TAG_PREPARED", meta = "positive" },
			{ id = "follows_instructions", labelKey = "RATING_TAG_FOLLOWS_INSTRUCTIONS", meta = "positive" },
		},
	},
	{
		id = "gameplay",
		labelKey = "RATING_GROUP_GAMEPLAY",
		tags = {
			{ id = "good_player", labelKey = "RATING_TAG_GOOD_PLAYER", meta = "positive" },
			{ id = "good_dps", labelKey = "RATING_TAG_GOOD_DPS", meta = "positive" },
			{ id = "good_tank", labelKey = "RATING_TAG_GOOD_TANK", meta = "positive" },
			{ id = "good_healer", labelKey = "RATING_TAG_GOOD_HEALER", meta = "positive" },
			{ id = "poor_performance", labelKey = "RATING_TAG_POOR_PERFORMANCE", meta = "negative" },
			{ id = "poor_mechanics", labelKey = "RATING_TAG_POOR_MECHANICS", meta = "negative" },
		},
	},
}

-- Role / identity facts (not opinion tags).
local FACT_CATALOG = {
	{ id = "raid_leader", labelKey = "RATING_FACT_RAID_LEADER", meta = "fact" },
	{ id = "pug_raid_leader", labelKey = "RATING_FACT_PUG_RAID_LEADER", meta = "fact" },
	{ id = "guild_master", labelKey = "RATING_FACT_GUILD_MASTER", meta = "fact" },
	{ id = "guild_officer", labelKey = "RATING_FACT_GUILD_OFFICER", meta = "fact" },
}

local EVENT_GROUPS = {
	{
		id = "attendance",
		labelKey = "RATING_EVENT_GROUP_ATTENDANCE",
		icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
		events = {
			{ id = "same_party", labelKey = "RATING_EVENT_SAME_PARTY" },
			{ id = "left_raid", labelKey = "RATING_EVENT_LEFT_RAID" },
			{ id = "left_early", labelKey = "RATING_EVENT_LEFT_EARLY" },
			{ id = "left_group", labelKey = "RATING_EVENT_LEFT_GROUP" },
			{ id = "rage_quit", labelKey = "RATING_EVENT_RAGE_QUIT" },
			{ id = "late_arrival", labelKey = "RATING_EVENT_LATE_ARRIVAL" },
			{ id = "afk", labelKey = "RATING_EVENT_AFK" },
			{ id = "no_arrival", labelKey = "RATING_EVENT_NO_ARRIVAL" },
			{ id = "raid_abandoned", labelKey = "RATING_EVENT_RAID_ABANDONED" },
		},
	},
	{
		id = "loot",
		labelKey = "RATING_GROUP_LOOT",
		icon = "Interface\\Icons\\INV_Misc_Coin_01",
		events = {
			{ id = "ninja_loot", labelKey = "RATING_EVENT_NINJA_LOOT" },
			{ id = "loot_dispute", labelKey = "RATING_EVENT_LOOT_DISPUTE" },
			{ id = "unfair_loot_distribution", labelKey = "RATING_EVENT_UNFAIR_LOOT_DISTRIBUTION" },
			{ id = "changed_loot_rules", labelKey = "RATING_EVENT_CHANGED_LOOT_RULES" },
			{ id = "loot_reservation_violation", labelKey = "RATING_EVENT_LOOT_RESERVATION_VIOLATION" },
		},
	},
	{
		id = "help",
		labelKey = "RATING_EVENT_GROUP_HELP",
		icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
		events = {
			{ id = "helped_player", labelKey = "RATING_EVENT_HELPED_PLAYER" },
			{ id = "helped_with_gear", labelKey = "RATING_EVENT_HELPED_WITH_GEAR" },
			{ id = "explained_mechanics", labelKey = "RATING_EVENT_EXPLAINED_MECHANICS" },
		},
	},
	{
		id = "behavior",
		labelKey = "RATING_GROUP_BEHAVIOR",
		icon = "Interface\\Icons\\Spell_Shadow_PsychicScream",
		events = {
			{ id = "toxic_behavior", labelKey = "RATING_EVENT_TOXIC_BEHAVIOR" },
			{ id = "scam", labelKey = "RATING_EVENT_SCAM" },
		},
	},
}

-- Old personal.tags ids → fact / event / drop during one-shot migration.
local TAGS_BY_ID = {}
for _, group in ipairs(TAG_GROUPS) do
	for _, tag in ipairs(group.tags) do
		tag.groupId = group.id
		tag.groupLabelKey = group.labelKey
		TAGS_BY_ID[tag.id] = tag
	end
end

local FACTS_BY_ID = {}
for _, fact in ipairs(FACT_CATALOG) do
	FACTS_BY_ID[fact.id] = fact
end

local EVENT_TYPES = {}
local EVENTS_BY_ID = {}
for _, group in ipairs(EVENT_GROUPS) do
	for _, eventType in ipairs(group.events) do
		eventType.groupId = group.id
		eventType.groupLabelKey = group.labelKey
		eventType.groupIcon = group.icon
		eventType.lootBased = group.id == "loot"
		EVENT_TYPES[#EVENT_TYPES + 1] = eventType
		EVENTS_BY_ID[eventType.id] = eventType
	end
end

function Addon:RatingDefaultPersonal()
	return {
		opinion = "neutral",
		tags = {},
		facts = {},
		createdAt = 0,
		updatedAt = 0,
		creatorId = "",
	}
end

function Addon:NormalizePersonalOpinion(opinion)
	if OPINIONS[opinion] then
		return opinion
	end
	return "neutral"
end

function Addon:IsValidPersonalTag(tagId)
	return TAGS_BY_ID[tagId] ~= nil
end

function Addon:IsValidPersonalFact(factId)
	return FACTS_BY_ID[factId] ~= nil
end

function Addon:IsValidEventType(eventTypeId)
	return EVENTS_BY_ID[eventTypeId] ~= nil
end

function Addon:NormalizePersonalTags(tags)
	local normalized = {}
	local seen = {}
	if type(tags) ~= "table" then
		return normalized
	end
	for index = 1, #tags do
		local tagId = tags[index]
		if self:IsValidPersonalTag(tagId) and not seen[tagId] then
			seen[tagId] = true
			normalized[#normalized + 1] = tagId
		end
	end
	table.sort(normalized, function(left, right)
		local leftTag = TAGS_BY_ID[left]
		local rightTag = TAGS_BY_ID[right]
		if leftTag and rightTag and leftTag.groupId ~= rightTag.groupId then
			return leftTag.groupId < rightTag.groupId
		end
		return left < right
	end)
	return normalized
end

function Addon:NormalizePersonalFacts(facts)
	local normalized = {}
	local seen = {}
	if type(facts) ~= "table" then
		return normalized
	end
	for index = 1, #facts do
		local factId = facts[index]
		if self:IsValidPersonalFact(factId) and not seen[factId] then
			seen[factId] = true
			normalized[#normalized + 1] = factId
		end
	end
	table.sort(normalized)
	while #normalized > MAX_PERSONAL_FACTS do
		table.remove(normalized)
	end
	return normalized
end

function Addon:EnsurePersonalRating(entry)
	if type(entry) ~= "table" then
		return self:RatingDefaultPersonal()
	end
	if type(entry.rating) ~= "table" then
		entry.rating = {}
	end
	if type(entry.rating.personal) ~= "table" then
		entry.rating.personal = self:RatingDefaultPersonal()
	end
	if type(entry.events) ~= "table" then
		entry.events = {}
	end
	local personal = entry.rating.personal
	self:MigrateLegacyPersonalTags(entry, personal)
	personal.opinion = self:NormalizePersonalOpinion(personal.opinion)
	personal.tags = self:NormalizePersonalTags(personal.tags)
	personal.facts = self:NormalizePersonalFacts(personal.facts)
	personal.updatedAt = tonumber(personal.updatedAt) or 0
	personal.createdAt = tonumber(personal.createdAt) or 0
	if personal.createdAt <= 0 and personal.updatedAt > 0 then
		personal.createdAt = personal.updatedAt
	end
	if type(personal.creatorId) ~= "string" then
		personal.creatorId = ""
	end
	personal.reputationV2 = true
	return personal
end

function Addon:GetPersonalRating(entryOrMember)
	if type(entryOrMember) ~= "table" then
		return self:RatingDefaultPersonal()
	end
	-- Always prefer the live history row by GUID so profile labels are not stuck
	-- on a stale member.rating snapshot from when the window opened.
	local guid = entryOrMember.guid
	if type(guid) == "string" and guid ~= "" and self.GetHistoryEntry then
		local saved = self:GetHistoryEntry(guid)
		if type(saved) == "table" then
			entryOrMember = saved
		end
	end
	if type(entryOrMember.rating) == "table" and type(entryOrMember.rating.personal) == "table" then
		local personal = entryOrMember.rating.personal
		return {
			opinion = self:NormalizePersonalOpinion(personal.opinion),
			tags = self:NormalizePersonalTags(personal.tags),
			facts = self:NormalizePersonalFacts(personal.facts),
			createdAt = tonumber(personal.createdAt) or 0,
			updatedAt = tonumber(personal.updatedAt) or 0,
			creatorId = type(personal.creatorId) == "string" and personal.creatorId or "",
		}
	end
	return self:RatingDefaultPersonal()
end

-- True when the player has a saved personal note (not the empty default).
function Addon:HasPersonalRatingData(personal)
	if type(personal) ~= "table" then
		return false
	end
	if (tonumber(personal.updatedAt) or 0) > 0 then
		return true
	end
	if (tonumber(personal.createdAt) or 0) > 0 then
		return true
	end
	if personal.opinion and personal.opinion ~= "neutral" then
		return true
	end
	if type(personal.tags) == "table" and #personal.tags > 0 then
		return true
	end
	return false
end

-- Community note snapshot (future exchange/web). Mock preview when history exists.
local COMMUNITY_MOCK_TAGS = { "fair_loot", "good_raid_leader", "good_player" }
local COMMUNITY_MOCK_PERCENT = 0

function Addon:NormalizeCommunityRating(community)
	if type(community) ~= "table" then
		return nil
	end
	local percent = tonumber(community.positivePercent)
	local tags = self:NormalizePersonalTags(community.tags)
	if not percent and #tags == 0 then
		return nil
	end
	return {
		positivePercent = percent or 0,
		tags = tags,
		isMock = community.isMock and true or false,
	}
end

-- REFACTOR candidate: GUID lookup then name/realm scan; mock community fallback is non-obvious.
function Addon:GetCommunityRating(entryOrMember)
	local entry = nil
	local guid = nil
	if type(entryOrMember) == "table" then
		guid = entryOrMember.guid
		if type(guid) == "string" and guid ~= "" and self.GetHistoryEntry then
			local saved = self:GetHistoryEntry(guid)
			if type(saved) == "table" then
				entry = saved
			end
		end
		-- Resolved history row passed in (e.g. name lookup) — use it directly.
		if not entry and (entryOrMember.name or entryOrMember.meetCount or type(entryOrMember.rating) == "table") then
			entry = entryOrMember
		end
	elseif type(entryOrMember) == "string" and entryOrMember ~= "" and self.GetHistoryEntry then
		guid = entryOrMember
		entry = self:GetHistoryEntry(guid)
	end
	if type(entry) ~= "table" then
		return nil
	end
	if type(entry.rating) == "table" then
		local normalized = self:NormalizeCommunityRating(entry.rating.community)
		if normalized then
			return normalized
		end
	end
	-- Mock preview for players already in History (Character profile does the same).
	local inHistory = false
	if guid and self.GetHistoryEntry and self:GetHistoryEntry(guid) then
		inHistory = true
	elseif entry.meetCount or entry.metAt or entry.name then
		inHistory = true
	end
	if not inHistory then
		return nil
	end
	return {
		positivePercent = COMMUNITY_MOCK_PERCENT,
		tags = {
			COMMUNITY_MOCK_TAGS[1],
			COMMUNITY_MOCK_TAGS[2],
			COMMUNITY_MOCK_TAGS[3],
		},
		isMock = true,
	}
end

function Addon:GetHistoryEvents(entryOrMember)
	if type(entryOrMember) ~= "table" then
		return {}
	end
	local guid = entryOrMember.guid
	if type(guid) == "string" and guid ~= "" and self.GetHistoryEntry then
		local saved = self:GetHistoryEntry(guid)
		if type(saved) == "table" then
			entryOrMember = saved
		end
	end
	if type(entryOrMember.events) ~= "table" then
		return {}
	end
	local list = {}
	for index = 1, #entryOrMember.events do
		local event = entryOrMember.events[index]
		if type(event) == "table" and self:IsValidEventType(event.type) then
			list[#list + 1] = event
		end
	end
	table.sort(list, function(left, right)
		return (tonumber(left.eventAt) or 0) > (tonumber(right.eventAt) or 0)
	end)
	return list
end

function Addon:RatingOpinions()
	return OPINION_ORDER, OPINIONS
end

function Addon:RatingTagGroups()
	return TAG_GROUPS
end

function Addon:FactCatalog()
	return FACT_CATALOG
end

function Addon:EventTypeGroups()
	return EVENT_GROUPS
end

function Addon:EventTypes()
	return EVENT_TYPES
end

function Addon:MaxPersonalFacts()
	return MAX_PERSONAL_FACTS
end

-- DELETE candidate: no callers; tag limit hardcoded as 3 in CharacterProfile.
function Addon:MaxTagsPerGroup()
	return MAX_TAGS_PER_GROUP
end

function Addon:RatingTagById(tagId)
	return TAGS_BY_ID[tagId]
end

function Addon:FactById(factId)
	return FACTS_BY_ID[factId]
end

function Addon:EventTypeById(eventTypeId)
	return EVENTS_BY_ID[eventTypeId]
end
