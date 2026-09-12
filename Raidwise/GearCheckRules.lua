-- Gear Check rules: findings, item verdicts (S / A / B / C / D), overall status.

local Addon = Raidwise

-- Evaluation revision, independent of addon releases and catalog edits.
Addon.GEAR_CHECK_RULESET_VERSION = "wotlk-3.3.5a-r3"

local ENCHANTABLE = {
	head = true,
	shoulder = true,
	back = true,
	chest = true,
	wrist = true,
	hands = true,
	legs = true,
	feet = true,
	mainHand = true,
	offHand = true,
	ranged = true,
}

-- Profession / optional enchants: evaluate when present, never flag MISSING_ENCHANT.
local ENCHANT_OPTIONAL = {
	waist = true,
	finger1 = true,
	finger2 = true,
}

local MESSAGES = {
	SPEC_UNKNOWN = "Specialization is unknown; class-only rules are applied (grades may be less accurate).",
	PROFILE_MISSING = "No Gear Check profile is available for this class.",
	INSPECT_INCOMPLETE = "Inspect data is incomplete; gem/enchant grades may be unreliable.",
	ITEM_NOT_CHECKABLE = "Cannot evaluate this item (incomplete or unknown data).",
	ARMOR_FORBIDDEN = "Forbidden armor type for this specialization.",
	ARMOR_UNWANTED = "Unwanted armor type for this specialization.",
	ARMOR_NOT_PREFERRED = "Armor type is usable but not preferred for this specialization.",
	WEAPON_FORBIDDEN = "Forbidden weapon type for this specialization.",
	WEAPON_UNWANTED = "Unwanted weapon type for this specialization.",
	WEAPON_SETUP = "Weapon setup does not match this specialization.",
	TRINKET_NOT_PREFERRED = "Trinket is not typically used for this specialization.",
	TRINKET_SITUATIONAL = "Situational DPS trinket — viable for tanks in some encounters.",
	STAT_FORBIDDEN = "Forbidden stat for this specialization.",
	STAT_UNWANTED = "Unwanted stat for this specialization.",
	RESILIENCE_PVE = "Resilience is a PvP stat and is inappropriate for PvE Gear Check.",
	MISSING_ENCHANT = "Missing enchant.",
	ENCHANT_NOT_CHECKABLE = "Enchant id is unknown to the catalog (not-checkable).",
	ENCHANT_LOWER_LEVEL = "Enchant is below the maximum Northrend level (usable, but not max).",
	ENCHANT_BAD_STAT = "Enchant provides an inappropriate stat for this specialization.",
	MISSING_GEM = "Socket is missing a gem.",
	GEM_NOT_CHECKABLE = "Gem id is unknown to the catalog (not-checkable).",
	GEM_LOWER_LEVEL = "Gem is below the maximum Northrend epic level.",
	GEM_BAD_STAT = "Gem provides an inappropriate stat for this specialization.",
	META_MISSING = "Meta socket is missing a meta gem.",
	META_NOT_META = "Meta socket does not contain a meta gem.",
	META_NOT_PREFERRED = "Meta gem is not preferred for this specialization.",
	META_INACTIVE = "Meta gem requirements are not met across equipped gems.",
	META_NOT_CHECKABLE = "Meta gem activation cannot be determined from the available gem data.",
}

local function Msg(code, detail)
	local base = MESSAGES[code] or code
	if detail and detail ~= "" then
		return base .. " (" .. detail .. ")"
	end
	return base
end

local function AddFinding(findings, code, severity, category, slotKey, message)
	findings[#findings + 1] = {
		code = code,
		severity = severity,
		category = category,
		slot = slotKey,
		message = message,
	}
end

local function RankArmor(profile, armorType)
	if not armorType or armorType == "" or armorType == "unknown" then
		return "unknown"
	end
	local a = profile.armor
	if a.forbidden[armorType] then
		return "forbidden"
	end
	if a.unwanted[armorType] then
		return "unwanted"
	end
	if a.preferred[armorType] then
		return "preferred"
	end
	if a.acceptable[armorType] then
		return "acceptable"
	end
	-- Shields / offhands: treat as weapon-side when listed in weapons.
	if armorType == "shield" or armorType == "offhand" then
		return "weaponish"
	end
	return "other"
end

local function RankWeapon(profile, weaponType)
	if not weaponType or weaponType == "" or weaponType == "unknown" then
		return "unknown"
	end
	local w = profile.weapons
	if w.forbidden[weaponType] then
		return "forbidden"
	end
	if w.unwanted[weaponType] then
		return "unwanted"
	end
	if w.preferred[weaponType] then
		return "preferred"
	end
	if w.acceptable[weaponType] then
		return "acceptable"
	end
	return "other"
end

local function RankStat(profile, statId)
	local s = profile.stats
	if s.forbidden[statId] then
		return "forbidden"
	end
	if s.unwanted[statId] then
		return "unwanted"
	end
	if s.preferred[statId] then
		return "preferred"
	end
	if s.acceptable[statId] then
		return "acceptable"
	end
	return "other"
end

local function EvaluateItemArmor(findings, profile, slot)
	local item = slot.item
	if item.category ~= "armor" or item.isRelic then
		return
	end
	-- Cloaks/jewelry use armor item class but are not armor-type constrained.
	if slot.key == "back" or slot.key == "neck" or slot.key == "finger1" or slot.key == "finger2" then
		return
	end
	local armorType = item.armorType
	if not armorType or armorType == "unknown" then
		AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE", "armor type"))
		return
	end
	if armorType == "misc" then
		return
	end
	if armorType == "shield" or armorType == "offhand" then
		local rank = RankWeapon(profile, armorType)
		if rank == "forbidden" then
			AddFinding(findings, "WEAPON_FORBIDDEN", "hard", "weapon", slot.key, Msg("WEAPON_FORBIDDEN", armorType))
		elseif rank == "unwanted" then
			AddFinding(findings, "WEAPON_UNWANTED", "soft", "weapon", slot.key, Msg("WEAPON_UNWANTED", armorType))
		end
		return
	end
	local rank = RankArmor(profile, armorType)
	if rank == "forbidden" then
		AddFinding(findings, "ARMOR_FORBIDDEN", "hard", "armor", slot.key, Msg("ARMOR_FORBIDDEN", armorType))
	elseif rank == "unwanted" then
		AddFinding(findings, "ARMOR_UNWANTED", "soft", "armor", slot.key, Msg("ARMOR_UNWANTED", armorType))
	elseif rank == "other" then
		AddFinding(findings, "ARMOR_NOT_PREFERRED", "soft", "armor", slot.key, Msg("ARMOR_NOT_PREFERRED", armorType))
	elseif rank == "unknown" then
		AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE", "armor type"))
	end
end

local function EvaluateItemWeapon(findings, profile, slot)
	local item = slot.item
	if item.category ~= "weapon" then
		return
	end
	local weaponType = item.weaponType
	if not weaponType or weaponType == "unknown" then
		AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE", "weapon type"))
		return
	end
	local rank = RankWeapon(profile, weaponType)
	if rank == "forbidden" then
		AddFinding(findings, "WEAPON_FORBIDDEN", "hard", "weapon", slot.key, Msg("WEAPON_FORBIDDEN", weaponType))
	elseif rank == "unwanted" then
		AddFinding(findings, "WEAPON_UNWANTED", "soft", "weapon", slot.key, Msg("WEAPON_UNWANTED", weaponType))
	elseif rank == "unknown" then
		AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE", "weapon type"))
	end
end

local TWO_HAND = {
	sword2h = true,
	axe2h = true,
	mace2h = true,
	polearm = true,
	staff = true,
}

local function FindEquipmentSlot(equipment, key)
	for index = 1, #equipment do
		if equipment[index].key == key then
			return equipment[index]
		end
	end
	return nil
end

local function SlotHasItem(slot)
	return slot and not slot.empty and slot.item ~= nil
end

local function ItemIsTwoHand(item)
	return item and item.category == "weapon" and item.weaponType and TWO_HAND[item.weaponType]
end

local function ItemIsShield(item)
	return item and item.armorType == "shield"
end

local function ItemIsWeapon(item)
	return item and item.category == "weapon"
end

local function ItemIsHeldOffhand(item)
	return item and item.armorType == "offhand"
end

local function OffhandHasSpiritOrHit(item)
	if not item or type(item.stats) ~= "table" then
		return false
	end
	local spirit = tonumber(item.stats.spirit) or 0
	local hit = tonumber(item.stats.hitRating) or 0
	return spirit > 0 or hit > 0
end

-- Surface weapon-setup rules from BiS lists (not BiS scoring).
local function EvaluateWeaponSetup(findings, profile, equipment)
	local setup = profile.weaponSetup
	if not setup or setup == "any" then
		return
	end
	local mh = FindEquipmentSlot(equipment, "mainHand")
	local oh = FindEquipmentSlot(equipment, "offHand")

	if setup == "dw" then
		if not SlotHasItem(mh) or not ItemIsWeapon(mh.item) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "mainHand", Msg("WEAPON_SETUP", "dual-wield needs a main-hand weapon"))
		end
		if not SlotHasItem(oh) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "dual-wield needs an off-hand weapon"))
		elseif ItemIsShield(oh.item) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "shield is not used for dual-wield"))
		elseif not ItemIsWeapon(oh.item) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "dual-wield needs an off-hand weapon"))
		end
	elseif setup == "2h" then
		if SlotHasItem(mh) and ItemIsTwoHand(mh.item) and SlotHasItem(oh) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "two-hand setup should leave off-hand empty"))
		end
	elseif setup == "1h_shield" then
		if SlotHasItem(mh) and ItemIsTwoHand(mh.item) then
			-- Staff / other 2H is a temporary healer variant; off-hand must stay empty.
			if SlotHasItem(oh) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "two-hand setup should leave off-hand empty"))
			end
		else
			if not SlotHasItem(oh) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "expects a shield"))
			elseif not ItemIsShield(oh.item) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "expects a shield"))
			end
		end
	elseif setup == "1h_shield_or_oh" then
		-- Resto Shaman: shield preferred; SP/haste/crit held OH (no spirit/hit) also fine; 2H staff ok.
		if SlotHasItem(mh) and ItemIsTwoHand(mh.item) then
			if SlotHasItem(oh) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "two-hand setup should leave off-hand empty"))
			end
		elseif not SlotHasItem(oh) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "expects a shield or off-hand"))
		elseif ItemIsShield(oh.item) then
			-- ok
		elseif ItemIsHeldOffhand(oh.item) then
			if OffhandHasSpiritOrHit(oh.item) then
				AddFinding(
					findings,
					"WEAPON_SETUP",
					"soft",
					"weapon",
					"offHand",
					Msg("WEAPON_SETUP", "held off-hand with spirit/hit is not preferred; use shield or SP/haste/crit OH")
				)
			end
		elseif not ItemIsWeapon(oh.item) then
			AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "expects a shield or off-hand"))
		end
	elseif setup == "1h_oh" then
		-- 1H+OH preferred; 2H staff is an acceptable temporary healer/caster variant.
		if SlotHasItem(mh) and ItemIsTwoHand(mh.item) then
			if SlotHasItem(oh) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "two-hand setup should leave off-hand empty"))
			end
		else
			if not SlotHasItem(oh) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "expects an off-hand"))
			elseif ItemIsShield(oh.item) then
				AddFinding(findings, "WEAPON_SETUP", "soft", "weapon", "offHand", Msg("WEAPON_SETUP", "shield is not used for this setup"))
			end
		end
	end
end

local function TrinketInSet(setTable, itemId)
	if type(setTable) ~= "table" or not next(setTable) then
		return false
	end
	return setTable[tonumber(itemId)] == true
end

local function EvaluateTrinket(findings, profile, slot)
	if slot.key ~= "trinket1" and slot.key ~= "trinket2" then
		return
	end
	local allowed = profile.trinketsAllowed
	if type(allowed) ~= "table" or not next(allowed) then
		return
	end
	local item = slot.item
	local itemId = item and tonumber(item.itemId)
	if not itemId or itemId <= 0 then
		return
	end
	if not allowed[itemId] then
		AddFinding(
			findings,
			"TRINKET_NOT_PREFERRED",
			"soft",
			"item",
			slot.key,
			Msg("TRINKET_NOT_PREFERRED", tostring(itemId))
		)
		return
	end
	local preferred = profile.trinketsPreferred
	local situational = profile.trinketsSituational
	if type(situational) == "table" and situational[itemId]
		and (type(preferred) ~= "table" or not preferred[itemId])
	then
		AddFinding(
			findings,
			"TRINKET_SITUATIONAL",
			"info",
			"item",
			slot.key,
			Msg("TRINKET_SITUATIONAL", tostring(itemId))
		)
	end
end

local function EvaluateItemStats(findings, profile, slot)
	local stats = slot.item.stats
	if type(stats) ~= "table" then
		return
	end
	for statId, amount in pairs(stats) do
		if tonumber(amount) and tonumber(amount) > 0 then
			if statId == "resilience" then
				AddFinding(findings, "RESILIENCE_PVE", "soft", "stat", slot.key, Msg("RESILIENCE_PVE"))
			else
				local rank = RankStat(profile, statId)
				if rank == "forbidden" then
					AddFinding(findings, "STAT_FORBIDDEN", "hard", "stat", slot.key, Msg("STAT_FORBIDDEN", statId))
				elseif rank == "unwanted" then
					AddFinding(findings, "STAT_UNWANTED", "soft", "stat", slot.key, Msg("STAT_UNWANTED", statId))
				end
			end
		end
	end
end

local function EnchantableSlot(slot)
	if not (ENCHANTABLE[slot.key] or ENCHANT_OPTIONAL[slot.key]) then
		return false
	end
	local item = slot.item
	if not item then
		return false
	end
	-- Wands / bows / guns / crossbows cannot be enchanted in WotLK.
	-- Only thrown weapons in the ranged slot accept enchants.
	if item.weaponType == "wand"
		or item.weaponType == "bow"
		or item.weaponType == "gun"
		or item.weaponType == "crossbow"
	then
		return false
	end
	if slot.key == "offHand" then
		-- Held-in-off-hand books/orbs (INVTYPE_HOLDABLE) cannot be enchanted; shields and weapons can.
		if item.armorType == "offhand" then
			return false
		end
		return item.category == "weapon" or item.armorType == "shield"
	end
	if slot.key == "ranged" then
		return item.weaponType == "thrown"
	end
	return true
end

local function SlotRequiresEnchantForGood(slot)
	if not ENCHANTABLE[slot.key] then
		return false
	end
	return EnchantableSlot(slot)
end

local function EvaluateEnchant(findings, profile, slot)
	if not EnchantableSlot(slot) then
		return
	end
	local enchant = slot.item.enchant
	local requirePresent = ENCHANTABLE[slot.key] == true
	if not enchant or not enchant.present then
		if requirePresent then
			AddFinding(findings, "MISSING_ENCHANT", "soft", "enchant", slot.key, Msg("MISSING_ENCHANT"))
		end
		return
	end
	local info = Addon:GetGearCheckEnchantInfo(enchant.enchantId)
	if not info then
		AddFinding(findings, "ENCHANT_NOT_CHECKABLE", "info", "enchant", slot.key, Msg("ENCHANT_NOT_CHECKABLE", tostring(enchant.enchantId)))
		return
	end
	if info.maxLevel ~= true then
		-- Below-max enchants are usable; info only so they do not demote to C.
		AddFinding(findings, "ENCHANT_LOWER_LEVEL", "info", "enchant", slot.key, Msg("ENCHANT_LOWER_LEVEL", info.name or tostring(enchant.enchantId)))
	end
	if type(info.stats) == "table" and not info.allStats then
		for statId, amount in pairs(info.stats) do
			if tonumber(amount) and tonumber(amount) > 0 then
				if statId == "resilience" then
					AddFinding(findings, "RESILIENCE_PVE", "soft", "enchant", slot.key, Msg("RESILIENCE_PVE", info.name))
				elseif RankStat(profile, statId) == "forbidden" then
					AddFinding(findings, "ENCHANT_BAD_STAT", "hard", "enchant", slot.key, Msg("ENCHANT_BAD_STAT", statId))
				elseif RankStat(profile, statId) == "unwanted" then
					AddFinding(findings, "ENCHANT_BAD_STAT", "soft", "enchant", slot.key, Msg("ENCHANT_BAD_STAT", statId))
				end
			end
		end
	end
end

local function EvaluateGems(findings, profile, slot)
	local item = slot.item
	local sockets = item.sockets or {}
	local gems = item.gems or {}
	if sockets.gemDataUncertain then
		AddFinding(
			findings,
			"GEM_NOT_CHECKABLE",
			"info",
			"gem",
			slot.key,
			"Socket contents are unavailable or unresolved from inspect; empty sockets are not confirmed."
		)
		local metaResolved = false
		for index = 1, #gems do
			if gems[index].isMeta then
				metaResolved = true
			end
		end
		if (tonumber(sockets.meta) or 0) > 0 and not metaResolved then
			AddFinding(findings, "META_NOT_CHECKABLE", "info", "meta", slot.key, Msg("META_NOT_CHECKABLE", "unresolved socket data"))
		end
		return
	end
	local socketTotal = tonumber(sockets.total) or 0
	local emptySockets = tonumber(sockets.empty)
	if emptySockets == nil then
		emptySockets = math.max(0, socketTotal - #gems)
	end
	if emptySockets > 0 and sockets.emptyConfirmed then
		AddFinding(
			findings,
			"MISSING_GEM",
			"soft",
			"gem",
			slot.key,
			Msg("MISSING_GEM", string.format("%d/%d", #gems, math.max(socketTotal, #gems + emptySockets)))
		)
	end

	local metaSockets = tonumber(sockets.meta) or 0
	local hasMetaGem = false
	local hasUnknownGem = false
	for index = 1, #gems do
		local gem = gems[index]
		if gem.isMeta then
			hasMetaGem = true
		end
		local catalog = Addon:GetGearCheckGemInfo(gem.itemId)
		if not catalog and (not gem.color or gem.color == "unknown") then
			hasUnknownGem = true
		end
		local stats = gem.stats
		if catalog and type(catalog.stats) == "table" and (not stats or not next(stats)) then
			stats = catalog.stats
		end
		if not catalog then
			-- Unknown ids stay not-checkable (info). Never invent GEM_LOWER_LEVEL.
			AddFinding(findings, "GEM_NOT_CHECKABLE", "info", "gem", slot.key, Msg("GEM_NOT_CHECKABLE", tostring(gem.itemId)))
		elseif catalog.maxLevel ~= true then
			AddFinding(findings, "GEM_LOWER_LEVEL", "soft", "gem", slot.key, Msg("GEM_LOWER_LEVEL", tostring(gem.itemId)))
		end
		if type(stats) == "table" and not (catalog and catalog.allStats) then
			for statId, amount in pairs(stats) do
				if tonumber(amount) and tonumber(amount) > 0 then
					if statId == "resilience" then
						AddFinding(findings, "RESILIENCE_PVE", "soft", "gem", slot.key, Msg("RESILIENCE_PVE", tostring(gem.itemId)))
					elseif RankStat(profile, statId) == "forbidden" then
						AddFinding(findings, "GEM_BAD_STAT", "hard", "gem", slot.key, Msg("GEM_BAD_STAT", statId))
					elseif RankStat(profile, statId) == "unwanted" then
						AddFinding(findings, "GEM_BAD_STAT", "soft", "gem", slot.key, Msg("GEM_BAD_STAT", statId))
					end
				end
			end
		end
		if gem.isMeta and profile.metaPreferred and next(profile.metaPreferred) then
			if not profile.metaPreferred[gem.itemId] then
				AddFinding(findings, "META_NOT_PREFERRED", "soft", "meta", slot.key, Msg("META_NOT_PREFERRED", tostring(gem.itemId)))
			end
		end
	end

	if metaSockets > 0 then
		if not hasMetaGem then
			if hasUnknownGem then
				AddFinding(findings, "META_NOT_CHECKABLE", "info", "meta", slot.key, Msg("META_NOT_CHECKABLE", "unknown gem identity"))
			elseif sockets.emptyConfirmed and (sockets.empty or 0) > 0 then
				AddFinding(findings, "META_MISSING", "soft", "meta", slot.key, Msg("META_MISSING"))
			elseif #gems >= math.max(metaSockets, tonumber(sockets.total) or 0) then
				AddFinding(findings, "META_NOT_META", "hard", "meta", slot.key, Msg("META_NOT_META"))
			else
				AddFinding(findings, "META_NOT_CHECKABLE", "info", "meta", slot.key, Msg("META_NOT_CHECKABLE", "socket occupancy unavailable"))
			end
		end
	end
end

local function EvaluateSlot(findings, profile, slot)
	if slot.policy ~= "CHECKED" then
		return
	end
	if slot.empty or not slot.item then
		return
	end
	local item = slot.item
	if item.pendingLink then
		AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE"))
		return
	end
	local skipTypeAndStats = item.infoKnown == false
	if type(item.gaps) == "table" then
		for index = 1, #item.gaps do
			local gap = item.gaps[index]
			if gap.code == "STATS_UNAVAILABLE" or gap.code == "ITEM_INFO_UNKNOWN"
				or gap.code == "ARMOR_TYPE_UNKNOWN" or gap.code == "WEAPON_TYPE_UNKNOWN"
			then
				AddFinding(findings, "ITEM_NOT_CHECKABLE", "info", "item", slot.key, Msg("ITEM_NOT_CHECKABLE", gap.code))
				skipTypeAndStats = true
				break
			end
		end
	end

	if not skipTypeAndStats then
		if slot.key == "trinket1" or slot.key == "trinket2" then
			EvaluateTrinket(findings, profile, slot)
			EvaluateItemStats(findings, profile, slot)
		else
			EvaluateItemArmor(findings, profile, slot)
			EvaluateItemWeapon(findings, profile, slot)
			EvaluateItemStats(findings, profile, slot)
		end
	elseif slot.key == "trinket1" or slot.key == "trinket2" then
		EvaluateTrinket(findings, profile, slot)
	end
	if slot.key ~= "trinket1" and slot.key ~= "trinket2" then
		EvaluateEnchant(findings, profile, slot)
		EvaluateGems(findings, profile, slot)
	end
end

local COLOR_MATCH = {
	red = { red = true, orange = true, purple = true, prismatic = true },
	yellow = { yellow = true, orange = true, green = true, prismatic = true },
	blue = { blue = true, purple = true, green = true, prismatic = true },
}

local function GemColor(gem)
	if gem.isMeta then
		return "meta"
	end
	if gem.color and gem.color ~= "unknown" then
		return gem.color
	end
	local catalog = Addon:GetGearCheckGemInfo(gem.itemId)
	if catalog and catalog.color then
		return catalog.color
	end
	return gem.color or "unknown"
end

local function CountMatchingGems(equipment)
	local have = { red = 0, yellow = 0, blue = 0 }
	local uncertain = false
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.policy == "CHECKED" and slot.item and slot.item.gems then
			local gems = slot.item.gems
			if slot.item.sockets and slot.item.sockets.gemDataUncertain then
				uncertain = true
			end
			for g = 1, #gems do
				local gem = gems[g]
				if not gem.isMeta then
					local color = GemColor(gem)
					if color == "unknown" then
						uncertain = true
					end
					if COLOR_MATCH.red[color] then
						have.red = have.red + 1
					end
					if COLOR_MATCH.yellow[color] then
						have.yellow = have.yellow + 1
					end
					if COLOR_MATCH.blue[color] then
						have.blue = have.blue + 1
					end
				end
			end
		end
	end
	return have, uncertain
end

local function FormatRequireBrief(requires, have)
	local parts = {}
	local order = { "red", "yellow", "blue" }
	for index = 1, #order do
		local color = order[index]
		local need = requires[color]
		if need and need > 0 then
			parts[#parts + 1] = string.format("%s %d/%d", color, have[color] or 0, need)
		end
	end
	return table.concat(parts, ", ")
end

local function EvaluateMetaActivation(findings, report, equipment)
	local have, uncertain = CountMatchingGems(equipment)
	local metaInfo = {
		present = false,
		active = nil,
		known = false,
		itemId = nil,
		slot = nil,
		requires = nil,
		have = have,
	}
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.policy == "CHECKED" and slot.item and slot.item.gems then
			local gems = slot.item.gems
			for g = 1, #gems do
				local gem = gems[g]
				if gem.isMeta or GemColor(gem) == "meta" then
					metaInfo.present = true
					metaInfo.itemId = gem.itemId
					metaInfo.slot = slot.key
					local catalog = Addon:GetGearCheckGemInfo(gem.itemId)
					local requires = catalog and catalog.requires
					if type(requires) ~= "table" or not next(requires) then
						metaInfo.known = false
						AddFinding(
							findings,
							"META_NOT_CHECKABLE",
							"info",
							"meta",
							slot.key,
							Msg("META_NOT_CHECKABLE", tostring(gem.itemId))
						)
					else
						metaInfo.known = true
						metaInfo.requires = requires
						local ok = true
						for color, need in pairs(requires) do
							if (have[color] or 0) < (tonumber(need) or 0) then
								ok = false
								break
							end
						end
						metaInfo.active = ok
						if not ok and uncertain then
							metaInfo.known = false
							metaInfo.active = nil
							AddFinding(findings, "META_NOT_CHECKABLE", "info", "meta", slot.key, Msg("META_NOT_CHECKABLE", "unknown gem colors"))
						elseif not ok then
							AddFinding(
								findings,
								"META_INACTIVE",
								"soft",
								"meta",
								slot.key,
								Msg("META_INACTIVE", FormatRequireBrief(requires, have))
							)
						end
					end
				end
			end
		end
	end
	report.meta = metaInfo
end

local function CollectSetCounts(equipment)
	local counts = {}
	local seenKeys = {}
	for index = 1, #equipment do
		local slot = equipment[index]
		if slot.item and slot.item.itemId and Addon.GetGearCheckSetInfo then
			local info = Addon:GetGearCheckSetInfo(slot.item.itemId)
			if info then
				local bucket = counts[info.key]
				if not bucket then
					bucket = { key = info.key, equipped = 0, pieces = info.pieces or 5 }
					counts[info.key] = bucket
					seenKeys[#seenKeys + 1] = info.key
				end
				bucket.equipped = bucket.equipped + 1
			end
		end
	end
	table.sort(seenKeys)
	local list = {}
	for index = 1, #seenKeys do
		list[#list + 1] = counts[seenKeys[index]]
	end
	return list
end

function Addon:EvaluateGearCheck(report)
	local findings = {}
	if not report or not report.character then
		return findings
	end

	self:NormalizeGearCheckReport(report)
	local character = report.character
	local profile, source = self:GetGearCheckProfile(character.classFile, character.specTab, character.specKnown)
	if source == "class" or not character.specKnown then
		AddFinding(findings, "SPEC_UNKNOWN", "info", "character", nil, Msg("SPEC_UNKNOWN"))
	end
	local inspectIncomplete = self:GetGearCheckScanState(report) ~= "complete"
	if inspectIncomplete then
		AddFinding(findings, "INSPECT_INCOMPLETE", "info", "character", nil, Msg("INSPECT_INCOMPLETE"))
	end
	if not profile then
		AddFinding(findings, "PROFILE_MISSING", "info", "character", nil, Msg("PROFILE_MISSING"))
		report.findings = findings
		report.sets = CollectSetCounts(Addon:GetGearCheckEquipment(report))
		self:AggregateGearCheckVerdicts(report)
		self:AggregateGearCheckOverall(report)
		return findings
	end

	report.profile = {
		name = profile.name,
		source = source,
	}

	local equipment = Addon:GetGearCheckEquipment(report)
	for index = 1, #equipment do
		EvaluateSlot(findings, profile, equipment[index])
	end
	EvaluateWeaponSetup(findings, profile, equipment)
	EvaluateMetaActivation(findings, report, equipment)
	report.sets = CollectSetCounts(equipment)

	report.findings = findings
	self:AggregateGearCheckVerdicts(report)
	self:AggregateGearCheckOverall(report)
	return findings
end

-- Promote clean B slots to A when the piece meets the preferred + max ench/gems bar.
-- Then to S when the equipped item ID is on the spec's built-in BiS union (item category only).
-- Blocked by any hard/soft finding, or by info findings that mean incomplete data.


-- Internal policy shared by grading and presentation; not a SavedVariables schema.
Addon.GearCheckPolicy = {
	ENCHANT_OPTIONAL = ENCHANT_OPTIONAL,
	RankArmor = RankArmor,
	RankWeapon = RankWeapon,
	TrinketInSet = TrinketInSet,
	SlotRequiresEnchantForGood = SlotRequiresEnchantForGood,
}
