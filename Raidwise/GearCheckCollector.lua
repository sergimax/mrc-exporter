-- Gear Check: collect equipped gear into a normalized model (schemaVersion 3).
-- Phase 2: no suitability rules. Phase 3+ must use this table only — no WoW API in rules.

local Addon = Raidwise

Addon.GEAR_CHECK_SCHEMA_VERSION = 3

-- Slot order for collection / dump. Policy drives later evaluation skips.
local SLOT_DEFS = {
	{ key = "head", slotName = "HeadSlot", policy = "CHECKED" },
	{ key = "neck", slotName = "NeckSlot", policy = "CHECKED" },
	{ key = "shoulder", slotName = "ShoulderSlot", policy = "CHECKED" },
	{ key = "back", slotName = "BackSlot", policy = "CHECKED" },
	{ key = "chest", slotName = "ChestSlot", policy = "CHECKED" },
	{ key = "shirt", slotName = "ShirtSlot", policy = "IGNORED" },
	{ key = "tabard", slotName = "TabardSlot", policy = "IGNORED" },
	{ key = "wrist", slotName = "WristSlot", policy = "CHECKED" },
	{ key = "hands", slotName = "HandsSlot", policy = "CHECKED" },
	{ key = "waist", slotName = "WaistSlot", policy = "CHECKED" },
	{ key = "legs", slotName = "LegsSlot", policy = "CHECKED" },
	{ key = "feet", slotName = "FeetSlot", policy = "CHECKED" },
	{ key = "finger1", slotName = "Finger0Slot", policy = "CHECKED" },
	{ key = "finger2", slotName = "Finger1Slot", policy = "CHECKED" },
	{ key = "trinket1", slotName = "Trinket0Slot", policy = "CHECKED" },
	{ key = "trinket2", slotName = "Trinket1Slot", policy = "CHECKED" },
	{ key = "mainHand", slotName = "MainHandSlot", policy = "CHECKED" },
	{ key = "offHand", slotName = "SecondaryHandSlot", policy = "CHECKED" },
	{ key = "ranged", slotName = "RangedSlot", policy = "CHECKED" },
}

-- GetItemStats keys → locale-independent stat ids.
local STAT_MAP = {
	ITEM_MOD_STRENGTH_SHORT = "strength",
	ITEM_MOD_AGILITY_SHORT = "agility",
	ITEM_MOD_STAMINA_SHORT = "stamina",
	ITEM_MOD_INTELLECT_SHORT = "intellect",
	ITEM_MOD_SPIRIT_SHORT = "spirit",
	ITEM_MOD_HIT_RATING_SHORT = "hitRating",
	ITEM_MOD_CRIT_RATING_SHORT = "critRating",
	ITEM_MOD_HASTE_RATING_SHORT = "hasteRating",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "expertiseRating",
	ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "armorPenetration",
	ITEM_MOD_SPELL_POWER_SHORT = "spellPower",
	ITEM_MOD_ATTACK_POWER_SHORT = "attackPower",
	ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralAttackPower",
	ITEM_MOD_SPELL_PENETRATION_SHORT = "spellPenetration",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defenseRating",
	ITEM_MOD_DODGE_RATING_SHORT = "dodgeRating",
	ITEM_MOD_PARRY_RATING_SHORT = "parryRating",
	ITEM_MOD_BLOCK_RATING_SHORT = "blockRating",
	ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
	ITEM_MOD_RESILIENCE_RATING_SHORT = "resilience",
	ITEM_MOD_MANA_REGENERATION_SHORT = "mp5",
	ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
	ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5",
	RESISTANCE0_NAME = "armor",
}

local SOCKET_MAP = {
	EMPTY_SOCKET_META = "meta",
	EMPTY_SOCKET_RED = "red",
	EMPTY_SOCKET_YELLOW = "yellow",
	EMPTY_SOCKET_BLUE = "blue",
	EMPTY_SOCKET_NO_COLOR = "prismatic",
}

-- GetAuctionItemSubClasses order on 3.3.5a (1-based).
local ARMOR_SUBCLASS_KEYS = {
	"misc", "cloth", "leather", "mail", "plate", "shield", "libram", "idol", "totem", "sigil",
}
local WEAPON_SUBCLASS_KEYS = {
	"axe1h", "axe2h", "bow", "gun", "mace1h", "mace2h", "polearm", "sword1h", "sword2h",
	"staff", "fist", "misc", "dagger", "thrown", "crossbow", "wand", "fishingPole",
}
local GEM_SUBCLASS_KEYS = {
	"red", "blue", "yellow", "purple", "green", "orange", "meta", "simple", "prismatic",
}

local ARMOR_NAME_FALLBACK = {
	cloth = "cloth",
	leather = "leather",
	mail = "mail",
	plate = "plate",
	shield = "shield",
	shields = "shield",
	libram = "libram",
	librams = "libram",
	idol = "idol",
	idols = "idol",
	totem = "totem",
	totems = "totem",
	sigil = "sigil",
	sigils = "sigil",
	miscellaneous = "misc",
}

local WEAPON_NAME_FALLBACK = {
	["one-handed axes"] = "axe1h",
	["two-handed axes"] = "axe2h",
	bows = "bow",
	guns = "gun",
	["one-handed maces"] = "mace1h",
	["two-handed maces"] = "mace2h",
	polearms = "polearm",
	["one-handed swords"] = "sword1h",
	["two-handed swords"] = "sword2h",
	staves = "staff",
	["fist weapons"] = "fist",
	miscellaneous = "misc",
	daggers = "dagger",
	thrown = "thrown",
	crossbows = "crossbow",
	wands = "wand",
	["fishing poles"] = "fishingPole",
}

local GEM_NAME_FALLBACK = {
	red = "red",
	blue = "blue",
	yellow = "yellow",
	purple = "purple",
	green = "green",
	orange = "orange",
	meta = "meta",
	simple = "simple",
	prismatic = "prismatic",
}

local armorSubTypeMap = {}
local weaponSubTypeMap = {}
local gemSubTypeMap = {}
local auctionMapsReady = false

local function AddGap(gaps, code, detail)
	gaps[#gaps + 1] = { code = code, detail = detail }
end

local function BuildAuctionMap(classIndex, keys)
	local map = {}
	if type(GetAuctionItemSubClasses) ~= "function" then
		return map
	end
	local ok, names = pcall(function()
		return { GetAuctionItemSubClasses(classIndex) }
	end)
	if not ok or type(names) ~= "table" then
		return map
	end
	for index = 1, #names do
		local name = names[index]
		if type(name) == "string" and name ~= "" and keys[index] then
			map[name] = keys[index]
			map[strlower(name)] = keys[index]
		end
	end
	return map
end

local function EnsureAuctionMaps()
	if auctionMapsReady then
		return
	end
	weaponSubTypeMap = BuildAuctionMap(1, WEAPON_SUBCLASS_KEYS)
	armorSubTypeMap = BuildAuctionMap(2, ARMOR_SUBCLASS_KEYS)
	gemSubTypeMap = {}
	if type(GetAuctionItemClasses) == "function" then
		local ok, classes = pcall(function()
			return { GetAuctionItemClasses() }
		end)
		if ok and type(classes) == "table" then
			for classIndex = 1, #classes do
				local className = classes[classIndex]
				if type(className) == "string" and strlower(className) == "gem" then
					gemSubTypeMap = BuildAuctionMap(classIndex, GEM_SUBCLASS_KEYS)
					break
				end
			end
		end
	end
	auctionMapsReady = true
end

local function LookupMappedName(map, fallback, name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if map and map[name] then
		return map[name]
	end
	local lower = strlower(name)
	if map and map[lower] then
		return map[lower]
	end
	if fallback and fallback[lower] then
		return fallback[lower]
	end
	return nil
end

local function ClassifyItem(itemType, itemSubType, equipLoc)
	EnsureAuctionMaps()
	local category = "unknown"
	local armorType = nil
	local weaponType = nil
	local isRelic = false

	if equipLoc == "INVTYPE_SHIELD" then
		category = "armor"
		armorType = "shield"
	elseif equipLoc == "INVTYPE_HOLDABLE" then
		category = "armor"
		armorType = "offhand"
	elseif equipLoc == "INVTYPE_RELIC" then
		category = "relic"
		isRelic = true
	elseif equipLoc == "INVTYPE_2HWEAPON"
		or equipLoc == "INVTYPE_WEAPON"
		or equipLoc == "INVTYPE_WEAPONMAINHAND"
		or equipLoc == "INVTYPE_WEAPONOFFHAND"
		or equipLoc == "INVTYPE_RANGED"
		or equipLoc == "INVTYPE_RANGEDRIGHT"
		or equipLoc == "INVTYPE_THROWN"
	then
		category = "weapon"
		weaponType = LookupMappedName(weaponSubTypeMap, WEAPON_NAME_FALLBACK, itemSubType) or "unknown"
	else
		local armor = LookupMappedName(armorSubTypeMap, ARMOR_NAME_FALLBACK, itemSubType)
		if armor then
			category = "armor"
			armorType = armor
			if armor == "libram" or armor == "idol" or armor == "totem" or armor == "sigil" then
				category = "relic"
				isRelic = true
			end
		elseif LookupMappedName(weaponSubTypeMap, WEAPON_NAME_FALLBACK, itemSubType) then
			category = "weapon"
			weaponType = LookupMappedName(weaponSubTypeMap, WEAPON_NAME_FALLBACK, itemSubType)
		elseif type(itemType) == "string" then
			local lowerType = strlower(itemType)
			if lowerType == "armor" then
				category = "armor"
				armorType = "unknown"
			elseif lowerType == "weapon" then
				category = "weapon"
				weaponType = "unknown"
			else
				category = "other"
			end
		end
	end

	if type(itemSubType) == "string" then
		local lower = strlower(itemSubType)
		if lower:find("idol", 1, true) or lower:find("libram", 1, true)
			or lower:find("totem", 1, true) or lower:find("sigil", 1, true)
			or lower:find("relic", 1, true)
		then
			category = "relic"
			isRelic = true
		end
	end

	return category, armorType, weaponType, isRelic
end

local function MapGetItemStatsKey(rawKey)
	if type(rawKey) ~= "string" then
		return nil, nil
	end
	if SOCKET_MAP[rawKey] then
		return "socket", SOCKET_MAP[rawKey]
	end
	if STAT_MAP[rawKey] then
		return "stat", STAT_MAP[rawKey]
	end
	if type(_G) ~= "table" then
		return nil, nil
	end
	for token, color in pairs(SOCKET_MAP) do
		if _G[token] == rawKey then
			return "socket", color
		end
	end
	for token, statId in pairs(STAT_MAP) do
		if _G[token] == rawKey then
			return "stat", statId
		end
	end
	return nil, nil
end

local scanTip
local inspectGemCache = {}

-- Cache only the exact equipped hyperlink, including socket enchant fields.
-- A different link replaces the slot entry; short expiry also bounds stale reads.
local function GemCacheKey(unit, slotKey)
	local guid = unit and UnitGUID(unit)
	if not guid or not slotKey then
		return nil
	end
	return tostring(guid) .. ":" .. slotKey
end

local function MergeGemReads(gems, previous)
	local bySocket = {}
	for index = 1, #(previous or {}) do
		local gem = previous[index]
		bySocket[gem.socketIndex] = gem
	end
	for index = 1, #gems do
		local gem = gems[index]
		local old = bySocket[gem.socketIndex]
		if not old or (gem.itemId or 0) > 0 or old.enchantId ~= gem.enchantId then
			bySocket[gem.socketIndex] = gem
		end
	end
	local merged = {}
	for socketIndex = 1, 4 do
		if bySocket[socketIndex] then
			merged[#merged + 1] = bySocket[socketIndex]
		end
	end
	return merged
end

local function EnsureScanTip()
	if scanTip then
		return scanTip
	end
	scanTip = CreateFrame("GameTooltip", "RaidwiseGearCheckScanTip", nil, "GameTooltipTemplate")
	scanTip:Hide()
	return scanTip
end

local function PopulateScanTip(itemLink, unit, slotId)
	local tip = EnsureScanTip()
	if not tip then
		return false
	end
	local inventoryRead = false
	local ok = pcall(function()
		tip:SetOwner(UIParent, "ANCHOR_NONE")
		tip:ClearLines()
		if unit and slotId and type(tip.SetInventoryItem) == "function" then
			tip:SetInventoryItem(unit, slotId)
			if (tip:NumLines() or 0) > 0 then
				inventoryRead = true
				return
			end
			tip:ClearLines()
		end
		if type(itemLink) == "string" and itemLink ~= "" then
			tip:SetHyperlink(itemLink)
		end
	end)
	return ok, ok and inventoryRead
end

local function HideScanTip()
	local tip = EnsureScanTip()
	if tip then
		tip:Hide()
	end
end

local function BuildEmptySocketLabels()
	local labels = {
		["red socket"] = "red",
		["yellow socket"] = "yellow",
		["blue socket"] = "blue",
		["meta socket"] = "meta",
		["prismatic socket"] = "prismatic",
	}
	if type(_G) == "table" then
		for token, color in pairs(SOCKET_MAP) do
			local text = _G[token]
			if type(text) == "string" and text ~= "" then
				labels[strlower(text)] = color
			end
		end
	end
	return labels
end

local function CollectStatsAndSockets(itemLinkOrId)
	local stats = {}
	local sockets = { meta = 0, red = 0, yellow = 0, blue = 0, prismatic = 0, total = 0 }
	local gaps = {}
	if type(GetItemStats) ~= "function" or not itemLinkOrId then
		AddGap(gaps, "STATS_UNAVAILABLE")
		return stats, sockets, gaps
	end
	local ok, raw = pcall(GetItemStats, itemLinkOrId)
	if not ok or type(raw) ~= "table" then
		AddGap(gaps, "STATS_UNAVAILABLE")
		return stats, sockets, gaps
	end
	for rawKey, value in pairs(raw) do
		local amount = tonumber(value)
		if amount and amount ~= 0 then
			local kind, mapped = MapGetItemStatsKey(rawKey)
			if kind == "socket" then
				sockets[mapped] = (sockets[mapped] or 0) + amount
				sockets.total = sockets.total + amount
			elseif kind == "stat" then
				stats[mapped] = (stats[mapped] or 0) + amount
			end
		end
	end
	return stats, sockets, gaps
end

local function SplitColonFields(payload)
	local fields = {}
	local start = 1
	while true do
		local colon = payload:find(":", start, true)
		if not colon then
			fields[#fields + 1] = payload:sub(start)
			break
		end
		fields[#fields + 1] = payload:sub(start, colon - 1)
		start = colon + 1
	end
	return fields
end

local function ParseItemLinkParts(itemLink)
	if type(itemLink) ~= "string" or itemLink == "" then
		return nil
	end
	local payload = itemLink:match("[Hh]?item:([^|]+)")
	if not payload then
		return nil
	end
	local fields = SplitColonFields(payload)
	local itemId = tonumber(fields[1])
	if not itemId or itemId <= 0 then
		return nil
	end
	return {
		itemId = itemId,
		enchantId = tonumber(fields[2]) or 0,
		gemFieldsComplete = tonumber(fields[3]) ~= nil and tonumber(fields[4]) ~= nil
			and tonumber(fields[5]) ~= nil and tonumber(fields[6]) ~= nil,
		gemEnchantIds = {
			tonumber(fields[3]) or 0,
			tonumber(fields[4]) or 0,
			tonumber(fields[5]) or 0,
			tonumber(fields[6]) or 0,
		},
	}
end

local function CollectGemsFromItemLink(itemLink, parsed)
	local gems = {}
	for socketIndex = 1, 4 do
		local enchantId = parsed and parsed.gemEnchantIds[socketIndex] or 0
		local gemLink
		if type(GetItemGem) == "function" and itemLink then
			local _, link = GetItemGem(itemLink, socketIndex)
			gemLink = link
		end
		local itemId = type(gemLink) == "string" and tonumber(gemLink:match("item:(%d+)")) or 0
		if (itemId or 0) == 0 and Addon.GetGearCheckGemItemId then
			itemId = Addon:GetGearCheckGemItemId(enchantId) or 0
		end
		if (itemId or 0) > 0 or enchantId > 0 then
			gems[#gems + 1] = {
				socketIndex = socketIndex,
				itemId = itemId or 0,
				enchantId = enchantId,
				link = gemLink,
			}
		end
	end
	return gems
end

local function ScanInventorySocketData(itemLink, parsed, unit, slotId)
	local empty = { meta = 0, red = 0, yellow = 0, blue = 0, prismatic = 0, total = 0 }
	local gems = CollectGemsFromItemLink(itemLink, parsed)
	if not unit or not slotId then
		return gems, empty
	end
	local populated, inventoryRead = PopulateScanTip(itemLink, unit, slotId)
	if not populated then
		return gems, empty
	end
	empty.inventoryRead = inventoryRead
	-- Tooltip population can resolve more gem links. Merge only the same snapshot.
	gems = MergeGemReads(CollectGemsFromItemLink(itemLink, parsed), gems)
	local tip = EnsureScanTip()
	local tipName = tip:GetName()
	local labels = BuildEmptySocketLabels()
	local lineCount = tip:NumLines() or 0
	for index = 1, lineCount do
		local fontString = _G[tipName .. "TextLeft" .. index]
		local text = fontString and fontString:GetText()
		if type(text) == "string" and text ~= "" then
			text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
			-- Gem/enchant lines use [Name]; empty socket placeholders are plain text.
			if not text:find("[", 1, true) then
				local color = labels[strlower(text)]
				if color then
					empty[color] = (empty[color] or 0) + 1
					empty.total = empty.total + 1
				end
			end
		end
	end
	HideScanTip()
	return gems, empty
end

local function CollectGemItemIds(itemLink, parsed, unit, slotId, slotKey)
	-- Keep gems tied to the same link used for this item's stats and identity.
	local gems, fromTip = ScanInventorySocketData(itemLink, parsed, unit, slotId)
	local key = GemCacheKey(unit, slotKey)
	if key then
		local cached = inspectGemCache[key]
		local now = GetTime()
		if cached and cached.link == itemLink and now - cached.time < 10 then
			gems = MergeGemReads(gems, cached.gems)
		end
		-- Expiry is measured from the first read, not extended by cache hits.
		local cacheTime = cached and cached.link == itemLink and now - cached.time < 10 and cached.time or now
		local cacheable = {}
		for index = 1, #gems do
			if (gems[index].enchantId or 0) > 0 then
				cacheable[#cacheable + 1] = gems[index]
			end
		end
		inspectGemCache[key] = { link = itemLink, gems = cacheable, time = cacheTime }
	end
	return gems, fromTip
end

local function NormalizeEnchant(enchantId)
	enchantId = tonumber(enchantId) or 0
	local enchant = {
		enchantId = enchantId,
		present = enchantId > 0,
		known = enchantId == 0,
		name = nil,
		gaps = {},
	}
	if enchant.present then
		local info = Addon.GetGearCheckEnchantInfo and Addon:GetGearCheckEnchantInfo(enchantId)
		if info then
			enchant.known = true
			if type(info.name) == "string" and info.name ~= "" then
				enchant.name = info.name
			end
		else
			AddGap(enchant.gaps, "ENCHANT_UNMAPPED")
		end
	end
	return enchant
end

local function NormalizeGem(rawGem)
	EnsureAuctionMaps()
	local gaps = {}
	local gem = {
		socketIndex = rawGem.socketIndex,
		itemId = rawGem.itemId,
		enchantId = rawGem.enchantId,
		state = "unresolved",
		present = true,
		known = false,
		isMeta = false,
		color = "unknown",
		name = nil,
		stats = {},
		gaps = gaps,
	}
	if not rawGem.itemId or rawGem.itemId <= 0 then
		AddGap(gaps, "GEM_INFO_UNKNOWN", "socket enchant " .. tostring(rawGem.enchantId))
		return gem
	end
	local name, itemType, itemSubType
	local ok = pcall(function()
		name, _, _, _, _, itemType, itemSubType = GetItemInfo(rawGem.link or rawGem.itemId)
	end)
	local catalog = Addon.GetGearCheckGemInfo and Addon:GetGearCheckGemInfo(rawGem.itemId)
	if catalog then
		gem.known = true
		gem.name = catalog.name
		if catalog.color then
			gem.color = catalog.color
			gem.isMeta = catalog.color == "meta"
		end
		if type(catalog.stats) == "table" then
			gem.stats = catalog.stats
		end
	end
	local resolvedColor = ok and LookupMappedName(gemSubTypeMap, GEM_NAME_FALLBACK, itemSubType)
	if ok and type(name) == "string" and name ~= "" and (catalog or resolvedColor) then
		gem.name = name
		gem.known = true
		local color = resolvedColor
		if color then
			gem.color = color
			gem.isMeta = color == "meta"
		elseif type(itemSubType) == "string" and strlower(itemSubType):find("meta", 1, true) then
			gem.color = "meta"
			gem.isMeta = true
		end
		if rawGem.link then
			local stats = CollectStatsAndSockets(rawGem.link)
			if type(stats) == "table" and next(stats) then
				gem.stats = stats
			end
		end
	elseif not catalog then
		AddGap(gaps, "GEM_INFO_UNKNOWN", tostring(rawGem.itemId))
	end
	if gem.known and gem.color ~= "unknown" then
		gem.state = "resolved"
	elseif not catalog then
		-- A non-gem item returned by the client must never acquire gem stats/name.
		gem.itemId = 0
	end
	return gem
end

local function ItemInfoBundle(itemId, itemLink)
	local name, link, quality, itemLevel, _, itemType, itemSubType, _, equipLoc, texture
	local ok = pcall(function()
		name, link, quality, itemLevel, _, itemType, itemSubType, _, equipLoc, texture = GetItemInfo(itemLink or itemId)
	end)
	if not ok or not name then
		ok = pcall(function()
			name, link, quality, itemLevel, _, itemType, itemSubType, _, equipLoc, texture = GetItemInfo(itemId)
		end)
	end
	if type(itemLink) == "string" and (not name or name == "") then
		name = itemLink:match("%[(.-)%]")
	end
	return {
		name = name,
		link = link or itemLink,
		quality = tonumber(quality),
		itemLevel = tonumber(itemLevel),
		itemType = itemType,
		itemSubType = itemSubType,
		equipLoc = equipLoc,
		texture = texture,
		infoKnown = name ~= nil and name ~= "",
	}
end

local function NormalizeItem(parsed, itemLink, info, unit, slotId, slotKey, inspectReady)
	local gaps = {}
	local stats, sockets, statGaps = CollectStatsAndSockets(itemLink or parsed.itemId)
	for index = 1, #statGaps do
		gaps[#gaps + 1] = statGaps[index]
	end

	local category, armorType, weaponType, isRelic = ClassifyItem(info.itemType, info.itemSubType, info.equipLoc)
	if not info.infoKnown then
		AddGap(gaps, "ITEM_INFO_UNKNOWN", tostring(parsed.itemId))
		category = "unknown"
	elseif category == "armor" and armorType == "unknown" then
		AddGap(gaps, "ARMOR_TYPE_UNKNOWN")
	elseif category == "weapon" and weaponType == "unknown" then
		AddGap(gaps, "WEAPON_TYPE_UNKNOWN")
	end

	local rawGems, fromTip = CollectGemItemIds(itemLink, parsed, unit, slotId, slotKey)
	local gems = {}
	local metaGemId = nil
	for index = 1, #rawGems do
		local gem = NormalizeGem(rawGems[index])
		gems[#gems + 1] = gem
		if gem.isMeta then
			metaGemId = gem.itemId
		end
	end

	-- Resolve socket totals carefully:
	-- GetItemStats EMPTY_SOCKET_* is layout (still present when gemmed).
	-- When gems are detected, derive empty counts from layout minus gem count.
	-- Inspect placeholders can show the layout before gem data arrives; wait for readiness.
	local isSelf = unit and type(UnitIsUnit) == "function" and UnitIsUnit(unit, "player")
	-- Require a completed inspect, explicit gem fields, and an inventory tooltip.
	-- A hyperlink fallback or a pre-inspect placeholder cannot confirm empties.
	local canConfirmEmpty = isSelf or (inspectReady and parsed.gemFieldsComplete and fromTip.inventoryRead)
	local fromStats = sockets.total
	local layoutTotal = fromStats
	local remainingEmpty = 0
	local emptyConfirmed = false
	local gemDataUncertain = false

	if #gems > 0 then
		layoutTotal = math.max(fromStats, #gems)
		for index = 1, #gems do
			layoutTotal = math.max(layoutTotal, gems[index].socketIndex)
		end
		remainingEmpty = math.max(0, layoutTotal - #gems)
		-- Partial inspect reads do not establish empty sockets.
		emptyConfirmed = remainingEmpty > 0 and canConfirmEmpty and fromTip.total == remainingEmpty or false
		gemDataUncertain = remainingEmpty > 0 and not emptyConfirmed
	elseif fromTip.total > 0 and canConfirmEmpty and fromTip.total >= fromStats then
		remainingEmpty = fromTip.total
		layoutTotal = math.max(fromStats, fromTip.total)
		emptyConfirmed = true
	elseif fromStats > 0 then
		layoutTotal = fromStats
		remainingEmpty = 0
		emptyConfirmed = false
		-- Inspect: layout present, no gem ids yet (or tip lied about empties).
		gemDataUncertain = true
	else
		layoutTotal = fromTip.total
		remainingEmpty = fromTip.total
		emptyConfirmed = fromTip.total > 0 and canConfirmEmpty or false
		gemDataUncertain = fromTip.total > 0 and not emptyConfirmed
	end

	if fromTip.total > 0 and fromStats == 0 and #gems == 0 then
		sockets.meta = fromTip.meta
		sockets.red = fromTip.red
		sockets.yellow = fromTip.yellow
		sockets.blue = fromTip.blue
		sockets.prismatic = fromTip.prismatic
	end
	for index = 1, #gems do
		if gems[index].state ~= "resolved" then
			gemDataUncertain = true
		end
	end
	sockets.states = {}
	for socketIndex = 1, layoutTotal do
		sockets.states[socketIndex] = emptyConfirmed and "empty" or "unresolved"
	end
	for index = 1, #gems do
		sockets.states[gems[index].socketIndex] = gems[index].state
	end
	sockets.total = layoutTotal
	sockets.empty = remainingEmpty
	sockets.emptyConfirmed = emptyConfirmed
	sockets.gemDataUncertain = gemDataUncertain

	return {
		itemId = parsed.itemId,
		link = itemLink,
		name = info.name,
		quality = info.quality,
		itemLevel = info.itemLevel,
		equipLoc = info.equipLoc,
		itemType = info.itemType,
		itemSubType = info.itemSubType,
		texture = info.texture,
		category = category,
		armorType = armorType,
		weaponType = weaponType,
		isRelic = isRelic and true or false,
		stats = stats,
		sockets = sockets,
		enchant = NormalizeEnchant(parsed.enchantId),
		gems = gems,
		metaGemId = metaGemId,
		infoKnown = info.infoKnown,
		pendingLink = false,
		gaps = gaps,
	}
end

local function CollectSlot(unit, def, inspectReady)
	local slotId = GetInventorySlotInfo(def.slotName)
	local gaps = {}
	local entry = {
		key = def.key,
		slotName = def.slotName,
		slotId = slotId,
		policy = def.policy,
		policyNote = nil,
		empty = true,
		item = nil,
		gaps = gaps,
	}

	if def.policy == "PLANNED" then
		entry.policyNote = "planned"
	elseif def.policy == "IGNORED" then
		entry.policyNote = "ignored"
	end

	if not slotId or not unit then
		AddGap(gaps, "SLOT_UNAVAILABLE")
		return entry
	end

	local itemLink = GetInventoryItemLink(unit, slotId)
	if not itemLink then
		local itemId = GetInventoryItemID and GetInventoryItemID(unit, slotId)
		if itemId and itemId > 0 then
			entry.empty = false
			AddGap(gaps, "ITEM_LINK_PENDING")
			entry.item = {
				itemId = itemId,
				link = nil,
				name = nil,
				quality = nil,
				itemLevel = nil,
				equipLoc = nil,
				itemType = nil,
				itemSubType = nil,
				texture = nil,
				category = "unknown",
				armorType = nil,
				weaponType = nil,
				isRelic = false,
				stats = {},
				sockets = { meta = 0, red = 0, yellow = 0, blue = 0, prismatic = 0, total = 0 },
				enchant = NormalizeEnchant(0),
				gems = {},
				metaGemId = nil,
				infoKnown = false,
				pendingLink = true,
				gaps = { { code = "ITEM_LINK_PENDING" } },
			}
		end
		return entry
	end

	local parsed = ParseItemLinkParts(itemLink)
	if not parsed then
		AddGap(gaps, "ITEM_LINK_INVALID")
		return entry
	end

	local info = ItemInfoBundle(parsed.itemId, itemLink)
	local item = NormalizeItem(parsed, itemLink, info, unit, slotId, def.key, inspectReady)

	if entry.policy == "CHECKED" and item.isRelic then
		entry.policy = "IGNORED"
		entry.policyNote = "relic"
	end

	entry.empty = false
	entry.item = item
	return entry
end

local function CollectClassSpec(unit, inspectReady)
	local className, classFile = UnitClass(unit)
	local specName, specIcon, specTab = "", "", 0
	local specKnown = false
	local gaps = {}

	if UnitIsUnit(unit, "player") and Addon.CollectPrimarySpec then
		specName, specIcon, specTab = Addon:CollectPrimarySpec()
	elseif inspectReady then
		-- Only read inspect talent APIs after INSPECT_TALENT_READY for this unit.
		-- Calling them earlier returns the previous inspect target's tree (e.g. Prot on a Priest).
		local isInspect = true
		local talentGroup = 1
		if type(GetActiveTalentGroup) == "function" then
			talentGroup = GetActiveTalentGroup(isInspect) or 1
		end
		local tabCount = 3
		if type(GetNumTalentTabs) == "function" then
			tabCount = GetNumTalentTabs(isInspect) or 3
		end
		local bestPoints = -1
		for tab = 1, tabCount do
			local name, icon, pointsSpent = GetTalentTabInfo(tab, isInspect, nil, talentGroup)
			pointsSpent = tonumber(pointsSpent) or 0
			if pointsSpent > bestPoints then
				bestPoints = pointsSpent
				specName = name or ""
				specIcon = icon or ""
				specTab = tab
			end
		end
		if bestPoints <= 0 then
			specName, specIcon, specTab = "", "", 0
		end
	elseif Addon.GetCachedSpecForUnit then
		local cachedName, cachedIcon, cachedTab = Addon:GetCachedSpecForUnit(unit)
		if (cachedName and cachedName ~= "") or (cachedTab and cachedTab > 0) then
			specName = cachedName or ""
			specIcon = cachedIcon or ""
			specTab = cachedTab or 0
		end
	end

	if (specName and specName ~= "") or (specTab and specTab > 0) then
		specKnown = true
		if not UnitIsUnit(unit, "player") and inspectReady and Addon.StoreSpecCacheForUnit then
			Addon:StoreSpecCacheForUnit(unit, specName, specIcon, specTab)
		end
	else
		AddGap(gaps, "SPEC_UNKNOWN")
	end

	return {
		className = className,
		classFile = classFile,
		specName = specName or "",
		specIcon = specIcon or "",
		specTab = tonumber(specTab) or 0,
		specKnown = specKnown,
		gaps = gaps,
	}
end

local function CountFilledCheckedSlots(slots)
	local filled = 0
	local checked = 0
	for index = 1, #slots do
		local slot = slots[index]
		if slot.policy == "CHECKED" then
			checked = checked + 1
			if not slot.empty and slot.item and slot.item.itemId then
				filled = filled + 1
			end
		end
	end
	return filled, checked
end

-- Informational only — never used by S / A / B / C / D rules.
local function AverageItemLevelFromEquipment(equipment)
	local total = 0
	local count = 0
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.policy == "CHECKED" and slot.item and slot.item.itemLevel then
			total = total + slot.item.itemLevel
			count = count + 1
		end
	end
	if count == 0 then
		return nil
	end
	return math.floor(total / count + 0.5)
end

local function CollectGearScoreForUnit(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end
	if UnitIsUnit(unit, "player") and Addon.CollectCurrentGearScore then
		return Addon:CollectCurrentGearScore()
	end
	local name, realm = UnitName(unit)
	if not name then
		return nil
	end
	if type(GearScore_GetScore) == "function" then
		pcall(GearScore_GetScore, name, unit)
	end
	realm = realm or GetRealmName()
	local players = GS_Data and realm and GS_Data[realm] and GS_Data[realm].Players
	local record = players and players[name]
	if record and record.GearScore ~= nil then
		return tonumber(record.GearScore)
	end
	return nil
end

function Addon:CollectGearCheckObservation(unit, inspectReady)
	unit = unit or self:ResolveGearCheckUnit()
	if not unit or not UnitExists(unit) then
		return nil
	end

	inspectReady = UnitIsUnit(unit, "player") or inspectReady == true
	local name, realm = UnitName(unit)
	local identity = CollectClassSpec(unit, inspectReady)
	local equipment = {}
	for index = 1, #SLOT_DEFS do
		equipment[#equipment + 1] = CollectSlot(unit, SLOT_DEFS[index], inspectReady)
	end

	local filled, checked = CountFilledCheckedSlots(equipment)
	local averageIlvl = AverageItemLevelFromEquipment(equipment)
	local gearScore = CollectGearScoreForUnit(unit)
	local characterGaps = {}
	for index = 1, #identity.gaps do
		characterGaps[#characterGaps + 1] = identity.gaps[index]
	end

	local isSelf = UnitIsUnit(unit, "player") and true or false
	local inspect = {
		needed = not isSelf,
		canInspect = false,
		notified = false,
		complete = isSelf and true or false,
	}
	if inspect.needed then
		if type(CanInspect) == "function" then
			inspect.canInspect = CanInspect(unit) and true or false
		end
		if inspect.canInspect and type(CheckInteractDistance) == "function" then
			if not CheckInteractDistance(unit, 4) then
				inspect.canInspect = false
				inspect.tooFar = true
			end
		end
	end

	local report = {
		schemaVersion = Addon.GEAR_CHECK_SCHEMA_VERSION,
		character = {
			unit = unit,
			isSelf = isSelf,
			name = name,
			realm = realm,
			guid = UnitGUID(unit),
			className = identity.className,
			classFile = identity.classFile,
			specName = identity.specName,
			specIcon = identity.specIcon,
			specTab = identity.specTab,
			specKnown = identity.specKnown,
			gaps = characterGaps,
			gearScore = gearScore,
			averageIlvl = averageIlvl,
		},
		equipment = equipment,
		gaps = {},
		collection = {
			collectedAt = time(),
			scanStatus = nil,
			inspect = inspect,
			counts = {
				checkedSlots = checked,
				filledCheckedSlots = filled,
			},
		},
		phase = 5,
	}

	return self:NormalizeGearCheckReport(report)
end

