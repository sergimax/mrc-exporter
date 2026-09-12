/**
 * Normalized Gear Check model (schemaVersion 3).
 *
 * Produced by `Raidwise/GearCheck.lua`. Phase 3+ rules must consume this shape
 * only — no WoW API calls inside the rules engine.
 *
 * `itemLevel` is informational and must never affect S / A / B / C / D.
 * Unknown data uses `gaps[]` (`{ code, detail? }`); never invent a D verdict.
 *
 * Phase 3 attaches `findings[]` and `profile` after evaluate; verdicts come in Phase 4.
 * schemaVersion 2 reports used GOOD / OK / REPLACE / BAD; rescan to refresh.
 */

export type GearCheckSchemaVersion = 3;

export type SlotPolicy = "CHECKED" | "IGNORED" | "PLANNED";

export type GearCheckGapCode =
  | "SPEC_UNKNOWN"
  | "SLOT_UNAVAILABLE"
  | "ITEM_LINK_PENDING"
  | "ITEM_LINK_INVALID"
  | "ITEM_INFO_UNKNOWN"
  | "ARMOR_TYPE_UNKNOWN"
  | "WEAPON_TYPE_UNKNOWN"
  | "STATS_UNAVAILABLE"
  | "ENCHANT_UNMAPPED"
  | "GEM_INFO_UNKNOWN";

export type GearCheckGap = {
  code: GearCheckGapCode | string;
  detail?: string;
};

export type GearCheckFindingSeverity = "hard" | "soft" | "info";

export type GearCheckFindingCategory =
  | "character"
  | "item"
  | "armor"
  | "weapon"
  | "stat"
  | "enchant"
  | "gem"
  | "meta"
  | string;

export type GearCheckFindingCode =
  | "SPEC_UNKNOWN"
  | "PROFILE_MISSING"
  | "INSPECT_INCOMPLETE"
  | "ITEM_NOT_CHECKABLE"
  | "ARMOR_FORBIDDEN"
  | "ARMOR_UNWANTED"
  | "ARMOR_NOT_PREFERRED"
  | "WEAPON_FORBIDDEN"
  | "WEAPON_UNWANTED"
  | "STAT_FORBIDDEN"
  | "STAT_UNWANTED"
  | "RESILIENCE_PVE"
  | "TRINKET_NOT_PREFERRED"
  | "TRINKET_SITUATIONAL"
  | "MISSING_ENCHANT"
  | "ENCHANT_NOT_CHECKABLE"
  | "ENCHANT_LOWER_LEVEL"
  | "ENCHANT_BAD_STAT"
  | "MISSING_GEM"
  | "GEM_NOT_CHECKABLE"
  | "GEM_LOWER_LEVEL"
  | "GEM_BAD_STAT"
  | "META_MISSING"
  | "META_NOT_META"
  | "META_NOT_PREFERRED"
  | "META_INACTIVE"
  | "META_NOT_CHECKABLE"
  | string;

export type GearCheckFinding = {
  code: GearCheckFindingCode;
  severity: GearCheckFindingSeverity;
  category: GearCheckFindingCategory;
  /** Slot key when item-scoped; omitted for character-level findings. */
  slot?: string;
  /** English-only for now. */
  message: string;
};

export type GearCheckProfileRef = {
  name: string;
  source: "spec" | "class" | string;
};

/** Locale-independent stat ids from GetItemStats mapping. */
export type GearCheckStatId =
  | "strength"
  | "agility"
  | "stamina"
  | "intellect"
  | "spirit"
  | "hitRating"
  | "critRating"
  | "hasteRating"
  | "expertiseRating"
  | "armorPenetration"
  | "spellPower"
  | "attackPower"
  | "feralAttackPower"
  | "spellPenetration"
  | "defenseRating"
  | "dodgeRating"
  | "parryRating"
  | "blockRating"
  | "blockValue"
  | "resilience"
  | "mp5"
  | "hp5"
  | "armor";

export type GearCheckStats = Partial<Record<GearCheckStatId, number>>;

export type GearCheckSockets = {
  meta: number;
  red: number;
  yellow: number;
  blue: number;
  prismatic: number;
  total: number;
  empty?: number;
  emptyConfirmed?: boolean;
  gemDataUncertain?: boolean;
  /** Per-socket state; unresolved may mean occupancy itself is unavailable. */
  states?: Array<"empty" | "unresolved" | "resolved">;
};

export type GearCheckEnchant = {
  enchantId: number;
  present: boolean;
  /** True when id is 0 (no enchant) or the enchant catalog resolved the id. */
  known: boolean;
  /** Catalog display name when known (e.g. Icewalker). */
  name?: string;
  gaps: GearCheckGap[];
};

export type GearCheckGemColor =
  | "red"
  | "blue"
  | "yellow"
  | "purple"
  | "green"
  | "orange"
  | "meta"
  | "prismatic"
  | "simple"
  | "unknown";

export type GearCheckGem = {
  socketIndex: number;
  /** 0 when an occupied socket's gem item ID could not be resolved. */
  itemId: number;
  /** Raw socket enchant ID, never an item ID. */
  enchantId?: number;
  state?: "unresolved" | "resolved";
  present: true;
  known: boolean;
  isMeta: boolean;
  color: GearCheckGemColor;
  name?: string;
  stats: GearCheckStats;
  gaps: GearCheckGap[];
};

export type GearCheckItemCategory = "armor" | "weapon" | "relic" | "other" | "unknown";

export type GearCheckArmorType =
  | "cloth"
  | "leather"
  | "mail"
  | "plate"
  | "shield"
  | "offhand"
  | "misc"
  | "unknown";

export type GearCheckWeaponType =
  | "axe1h"
  | "axe2h"
  | "bow"
  | "gun"
  | "mace1h"
  | "mace2h"
  | "polearm"
  | "sword1h"
  | "sword2h"
  | "staff"
  | "fist"
  | "dagger"
  | "thrown"
  | "crossbow"
  | "wand"
  | "fishingPole"
  | "misc"
  | "unknown";

export type GearCheckItem = {
  itemId: number;
  link?: string;
  name?: string;
  quality?: number;
  /** Informational only — must not affect verdicts. */
  itemLevel?: number;
  /** INVTYPE_* token, locale-independent. */
  equipLoc?: string;
  itemType?: string;
  itemSubType?: string;
  texture?: string;
  category: GearCheckItemCategory;
  armorType?: GearCheckArmorType;
  weaponType?: GearCheckWeaponType;
  isRelic: boolean;
  stats: GearCheckStats;
  sockets: GearCheckSockets;
  enchant: GearCheckEnchant;
  gems: GearCheckGem[];
  metaGemId?: number;
  infoKnown: boolean;
  pendingLink: boolean;
  gaps: GearCheckGap[];
};

export type GearCheckItemVerdict = "S" | "A" | "B" | "C" | "D";

export type GearCheckSlot = {
  key: string;
  slotName: string;
  slotId?: number;
  policy: SlotPolicy;
  policyNote?: "planned" | "ignored" | "relic";
  empty: boolean;
  item?: GearCheckItem;
  gaps: GearCheckGap[];
  /** Phase 4: set on CHECKED filled slots after aggregate. */
  verdict?: GearCheckItemVerdict;
};

export type GearCheckVerdictSummary = {
  s: number;
  a: number;
  b: number;
  c: number;
  d: number;
  skipped: number;
};

export type GearCheckIssueCounts = {
  items: number;
  enchants: number;
  gems: number;
  meta: number;
};

export type GearCheckOverall = {
  scanState?: "complete" | "incomplete" | "unavailable";
  scanReason?: string;
  provisional?: boolean;
  status: GearCheckItemVerdict;
  /** Armor, weapons, trinkets, stats — worst slot wins within this category. */
  gearGrade?: GearCheckItemVerdict;
  /** Enchants, gems, meta — worst slot wins within this category. */
  enchantSocketGrade?: GearCheckItemVerdict;
  reason: string;
  summary: string;
  issues: GearCheckIssueCounts;
  resilienceItems: number;
};

export type GearCheckMetaState = {
  present: boolean;
  active?: boolean | null;
  known: boolean;
  itemId?: number;
  slot?: string;
  requires?: Partial<Record<"red" | "yellow" | "blue", number>>;
  have?: Partial<Record<"red" | "yellow" | "blue", number>>;
};

export type GearCheckSetCount = {
  key: string;
  equipped: number;
  pieces: number;
};

export type GearCheckCharacter = {
  unit: string;
  isSelf: boolean;
  name?: string;
  realm?: string;
  guid?: string;
  className?: string;
  /** English class token, e.g. `"WARRIOR"`. */
  classFile?: string;
  specName?: string;
  specIcon?: string;
  specTab: number;
  specKnown: boolean;
  gaps: GearCheckGap[];
  /** From GearScore addon when available; informational only. */
  gearScore?: number;
  /** Mean itemLevel of filled CHECKED slots; informational only. */
  averageIlvl?: number;
};

/** Inspect / scan metadata. Completeness gates confidence in grades. */
export type GearCheckCollection = {
  collectedAt: number;
  scanStatus?: string;
  inspect: {
    needed: boolean;
    canInspect: boolean;
    notified: boolean;
    complete: boolean;
    tooFar?: boolean;
    timedOut?: boolean;
  };
  counts: {
    checkedSlots: number;
    filledCheckedSlots: number;
  };
};

/**
 * Frozen Gear Check report.
 * Rules read `character` + `equipment` (+ top-level `gaps`); collection gates completeness.
 * After Phase 3 evaluate: `findings` + `profile`.
 * After Phase 4 aggregate: per-slot `verdict` + `verdicts` counts (S / A / B / C / D).
 * After Phase 5: `overall`, `meta` activation, informational `sets`.
 *
 * Convenience aliases (`name`, `isSelf`, `inspect`, `slots`, …) may also be present
 * for UI/inspect orchestration; prefer the nested fields in new code.
 */
export type GearCheckReport = {
  schemaVersion: GearCheckSchemaVersion;
  character: GearCheckCharacter;
  equipment: GearCheckSlot[];
  gaps: GearCheckGap[];
  collection: GearCheckCollection;
  findings?: GearCheckFinding[];
  profile?: GearCheckProfileRef;
  verdicts?: GearCheckVerdictSummary;
  overall?: GearCheckOverall;
  meta?: GearCheckMetaState;
  sets?: GearCheckSetCount[];
};
