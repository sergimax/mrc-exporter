# Gear Check — implementation progress

Tracks work against the Gear Check specification (`docs/RaidWise Addon — Gear Check Specification.md`).  
Statuses: **planned** · **in progress** · **done** · **blocked** · **backlog**

Update this file when a phase starts or finishes. Prefer small, testable slices.

---

## Current module boundaries and compatibility (refactoring phase 9)

The earlier numbered phases below describe the original feature implementation.
The refactoring phases are documented in `tests/README.md`; this section describes
the current boundaries after those extractions.

| Owner | Responsibility and entry points |
|-------|---------------------------------|
| `InspectCoordinator.lua` | Exclusive inspect API/event ownership, request identity and deadlines; `StartInspectRequest`, `RetryInspectRequest`, completion/cancellation |
| `PartyRoster.lua`, `RosterRefresh.lua` | Member collection and work lists; `BuildRosterSnapshot`, `ScheduleRosterRefresh`; snapshots live for one refresh pass |
| `GearCheckCollector.lua` | Live item/gem reads and normalization; `CollectGearCheckObservation(unit, inspectReady)` returns a snapshot |
| `GearCheckReport.lua` | Canonical nested report fields with legacy alias adapters; shared complete/incomplete/unavailable scan state independent of diagnostic grades |
| `GearCheck.lua` | Scan orchestration and last-report state; `CollectGearCheck`, target/raid scan APIs, `CancelGearCheckScan` |
| `GearCheckRules.lua` | Findings, meta activation, set counts; `EvaluateGearCheck` calls grading afterward |
| `GearCheckGrades.lua` | Slot/category/overall aggregation; shares internal eligibility policy with explanations |
| `GearCheckExplanations.lua` | Tooltip lines and B-grade explanations; no live collection |
| `GearCheckReports.lua`, `ChatReports.lua` | Report wording, final message preparation, and preview/send consistency |
| `GearCheckDump.lua` | Text exports and cancellable asynchronous raid dump jobs |
| `GearCheckSavedReports.lua` | Manual snapshot storage, revision metadata, listing/deletion, 14-day retention |
| `GearCheckSelfTest.lua` | Shipped rule fixtures, retaining `/rw gearcheck test` |
| `PlayerHistory.lua`, `PlayerHistoryStore.lua` | Rating catalogs/normalization versus history storage, migration, events, and notes |
| `ProfileDraft.lua`, `RatingPresentation.lua` | Plain draft edits versus display labels, tooltips, and chat marks |
| `ProfilePanels.lua` | Profile tab construction and history-list rendering; window and edit/commit orchestration remain in `CharacterProfile.lua` |
| `UITheme.lua`, `UIWidgets.lua`, `RosterWidgets.lua` | Theme bindings, generic controls, and domain-specific rendering respectively |
| `Page*.lua`, `CharacterProfile.lua`, `ExporterWindow.lua` | Render views, invoke services, declare header report capabilities, and assemble panels |

The TOC is the authoritative load order. Load catalogs before rules, rules before
grades/explanations, theme before generic/domain widgets, and services before page
creation. Keep internal state local or on the single `Raidwise` namespace.
`GearCheckPolicy` is internal shared eligibility logic, not a saved-data format.

### Independent revisions

| Revision | Current baseline / source | Change when |
|----------|---------------------------|-------------|
| Addon semver | `1.22.0`; TOC and `Addon.version` | A release is explicitly requested |
| Report schema | `3`; `GEAR_CHECK_SCHEMA_VERSION` in collector | The normalized report contract changes; update `types/GearCheck.ts` and compatibility handling |
| Evaluation rules | `GEAR_CHECK_RULESET_VERSION` in rules | Finding, eligibility, aggregation, or unknown/incomplete-data policy changes; increment `rN` |
| Catalog data | `catalog-2026-09-10-gems3`; `GEAR_CHECK_DATA_VERSION` | Gem/enchant data, profiles, BiS/trinket pools, or set data change; assign a new catalog revision |
| UI layout | Per-shell/page/profile constants | Geometry or frame structure changes under AGENTS.md |

Mechanical refactors and UI/string-only edits do not change rule revisions.
Collector changes that only correct observations do not change grading policy;
if normalized field meanings change, review the schema too. A change affecting
both rules and catalog data must update both revisions. `r1` establishes the
independent baseline; it does not assert equivalence with every legacy release.

### Saved reports

Collection, evaluation and saving normalize through the report adapter. Canonical
`character`, `equipment`, and `collection` fields win if legacy aliases disagree;
new snapshots continue carrying aliases for schema-3 compatibility. The shared
scan-state accessor drives target/raid labels, chat, dumps and readiness counts.
Diagnostic S/A/B/C/D grades remain separate and are marked provisional when
collection is incomplete or unavailable. No existing snapshot is silently
reclassified as a fresh scan.

Keep `RaidwiseDB.gearCheckSaved`, entry IDs, existing public methods, and slash
commands stable. The envelope stores `rulesetVersion` and `dataVersion`; the
embedded report stores `schemaVersion`. Saving currently stamps the installed
rules/catalog revisions: this is save-time metadata, not proof that an externally
provided or older report was freshly collected/evaluated. Do not use it alone to
decide whether a snapshot is safe to re-grade.

Legacy `wotlk-3.3.5a-<addon version>` strings remain opaque historical values.
Loading/listing does not rewrite them to `r1`, discard them for a revision mismatch,
or trigger a new migration. Missing installed revision constants yield `unknown`,
never a guessed value based on addon semver. Existing retention still applies.

For incompatible future schemas, add an explicit tested migration or a clear
unsupported/rescan path before consuming those fields; do not silently relabel
old snapshots. This phase does not implement a new schema migration or change
the existing lazy grade-refresh behavior. A fresh scan is the reliable way to
obtain observations evaluated under current data and rules.

## Locked product decisions

| Topic | Decision |
|-------|----------|
| Menus | **Gear check (target)** for single scan; raid-wide scan on **Raid roster** (cell **Gear check** → drill-down) |
| Specs | Full 30 WotLK specs; UI notes that rules are **being maintained** |
| Unknown spec | Class-only rules **and** a “spec unknown” banner |
| Self-check | Yes — use player when there is no friendly player target |
| Chat reports | Header **Report chat channel** (default Auto = raid in a raid, party in a party; Self = local chat) |
| Verdicts | **S / A / B / C / D** (S = item ID on published BiS lists; A = highly appropriate, not a unique BiS pick) |
| Profile ranks | **preferred / acceptable / unwanted / forbidden** (renamed from *discouraged* → *unwanted*) |
| Overall status | Worst wins (S < A < B < C < D); C/D summaries note that items have those statuses |
| Resilience (PvE) | 1 item with Resilience → overall **C**; 2+ → **D** |
| Catalogs | Seed from AtlasLoot lists + hand-built enchantId map; unknown IDs → **not-checkable** (no false D) |
| Trinkets / relics / shirt / tabard | Relics / shirt / tabard ignored; **trinkets CHECKED** vs per-spec pools (`preferred` / `allowed`) |
| Finding locale | English only for now (RU later) |
| Saved reports | Manual save only; ~14-day retention; `rulesetVersion` + `dataVersion` on each snapshot |
| Profile stat tuning | Per-spec `S_*` templates in `GearCheckProfiles.lua`; matrix editor at `gear-check-debug/stats-matrix.html` |

---

## Phase board

| Phase | Name | Status | Notes |
|-------|------|--------|-------|
| 1 | Data collection | **done** | Target/self unit, slots, item/enchant/gem IDs, class/spec; Phase 1 dump UI |
| 2 | Normalized gear model | **done** | `schemaVersion = 3`; `types/GearCheck.ts`; dump shows stats/types/gaps (v2 reports used GOOD/OK/REPLACE/BAD until rescan) |
| 3 | Rules engine | **done** | Hard/soft/info findings; catalogs + 30-spec profiles; `/rw gearcheck test` |
| 4 | Item verdicts | **done** | Per-slot S / A / B / C / D from findings (info ≠ D); S = BiS-list ID membership |
| 5 | Gear-level evaluation | **done** | Overall worst-wins; resilience 1/2+; meta activation; T9/T10 counts |
| 6 | UI | **done** | Two-column summary + filters (incl. B); **Show as a text**; `LAYOUT_VERSION = 10` |
| 7 | Chat output | **done** | Self-chat summary/items/enchants/gems/ok; UI + slash |
| 8 | Ruleset expansion | **done** | Enh intellect; gem not-checkable policy; leg/Engi/weapon catalogs |
| — | Raid-wide gear check | **done** | `PageRaid.lua` + `StartGearCheckRaidScan` queue (integrated into Raid roster) |
| — | Saved reports | **done** | Manual save/load/delete in target UI; 14-day prune |
| — | Trinket analysis | **done** | Per-spec pools in `GearCheckTrinkets.lua`: BiS **preferred** (A) + progression **allowed** (B); soft `TRINKET_NOT_PREFERRED` outside allowed |
| — | Catalog / profile false positives | **backlog** | New reports after Phase 8 polish (Rhee items addressed) |

---

## Incomplete / remaining work

Features from the spec or locked decisions that are **not done** yet (or only partial). Use this as the leftover checklist.

### Product backlog

| Item | Spec / notes |
|------|----------------|
| Finding messages in RU | Chrome localized; finding `message` strings EN only |

### Spec in-scope, only partial

| Item | Spec | Current state |
|------|------|----------------|
| Weapon combinations | §12 | Setup checks: `dw` / `2h` / `1h_shield` (empty OH, shield expected, …); still no “must have ranged” |
| Preferred / allowed enchants | §13, §19 | Catalog `maxLevel` + bad-stat checks; no per-spec preferred enchant lists |
| Preferred / allowed gems | §14, §19 | Same for gems (beyond `metaPreferred`) |
| Meta allowed / forbidden set | §16 | Soft `META_NOT_PREFERRED` vs profile list; not a full allowed/forbidden matrix |
| Set 2pc / 4pc milestones | §17 | Informational **T9/T10 X/5** counts only |
| Slot policy naming | §9 | Spec `UNSUPPORTED`; unused for trinkets (now CHECKED) |
| Unknown / not-checkable UI | §8 | Info findings exist; All-filter hides pure info → easy to miss “cannot evaluate” |
| Catalog / profile completeness | Phase 8+ | Seeded + “being maintained”; 27/30 specs use dedicated stat templates; expand on false-positive reports |
| Surface rules from BiS examples | Wired into profiles + `WEAPON_SETUP` / trinket pools; see `docs/Gear-Check-Surface-From-BiS.md` + `GearCheckTrinkets.lua` |

### Explicitly out of scope (do not treat as incomplete)

BiS / stat weights / socket-bonus optimization / build-specific gearing / 2pc vs 4pc advice / ilvl scoring / auto history / web-style optimization (spec §§4, 15, 28).

---

## Known false positives / ruleset gaps

Observed on **Rhee (Enhancement Shaman)** during Phase 3; addressed in **Phase 8**. Keep this section for future reports.

| Area | Status | Notes |
|------|--------|-------|
| Gems epic → `GEM_LOWER_LEVEL` | **fixed** | Unknown gems are `GEM_NOT_CHECKABLE` (info); expanded ICC epic purple/orange/green seeds |
| Epic purple Dreadstone stats | **fixed** | Misaligned ids (e.g. Royal `40134` was AP+stam); corrected to tooltip stats |
| Epic orange Ametrine stats | **fixed** | Misaligned ids (e.g. Veiled `40153` was AP+hit); corrected to tooltip stats |
| Epic red/green + meta naming | **fixed** | Subtle/Precise Cardinal; Misty/Turbid Eye of Zul; Effulgent/Impassive metas |
| Rare Northrend gem seeds | **fixed** | Full AtlasLoot Scarlet/Monarch/Twilight/Forest/Autumn/Sky set (`maxLevel=false`) |
| Uncommon Northrend gem seeds | **fixed** | Full AtlasLoot Bloodstone/Sun/Chalcedony/Citrine/Shadow/Dark Jade set (tooltip-verified) |
| Stormjewel fishing gems | **fixed** | All 7 Dalaran fishing Stormjewels catalogued as epic max-level (Bold `45862` + Delicate/Runed/Brilliant/Rigid/Solid/Sparkling) |
| Enhancement intellect unwanted | **fixed** | `S_ENHANCE` prefers intellect |
| LW / Tailoring leg kits | **fixed** | Frosthide/Icescale/Nerubian/Jormungar + spellthread ids; Tailoring permanent `3872`/`3873` |
| Inscription / LW bracer perks | **fixed** | Master's Inscription `3835–3838`; Fur Lining AP/Stam/SP `3756–3758` |
| Engineering feet/hands | **fixed** | Nitro / Hyperspeed / Pyro Rocket / Flexweave / Frag Belt |
| Weapon enchants unknown | **fixed** | Mongoose, Executioner, Black Magic, Accuracy, Blade Ward, Blood Draining, Spellsurge (`2674`), … |

**Policy reminder:** unknown catalog ids stay **not-checkable** (info), never false **BAD**. Report new false REPLACE cases here for catalog/profile edits.

---

## Phase 1 — Data collection

**Goal:** Obtain enough equipped-gear data for one player (target or self) to drive later phases. No suitability rules.

**Status: done** (2026-08-24)

### Checklist

- [x] Progress doc (this file)
- [x] Resolve scan unit (player target if player; else self)
- [x] Class + primary spec (inspect when needed; mark unknown)
- [x] Slot policy: CHECKED / IGNORED / PLANNED
- [x] Per checked slot: item id, link, name, ilvl (informational), enchant id, gem item ids, meta gem id if present
- [x] Relic in ranged slot detected and treated as ignored (not evaluated later)
- [x] Phase 1 dump visible on **Gear check (target)** for manual testing
- [x] `/rw gearcheck` opens that tab and runs a scan

### How to test

1. `/reload`, then `/rw gearcheck` (or open **Gear check (target)** and press **Scan**).
2. **Self:** clear target → scan → dump shows your name, class, spec, equipped slots with enchant/gem ids.
3. **Other player:** target a nearby inspectable player → scan → after inspect, dump fills (may take a moment).
4. Confirm trinkets are **CHECKED** (allowlist); shirt / tabard ignored; relics ignored.
5. Confirm empty slots are listed as empty (not invented items).

### Out of scope this phase

Rules, verdicts, chat report modes, set-bonus logic, socket-bonus matching, BiS.

### Implemented files

- `Raidwise/GearCheck.lua` — collector + inspect retries + Phase 1 dump formatter
- `Raidwise/PageGearCheckTarget.lua` — Scan / Select all / copy box
- Slash: `/rw gearcheck` or `/raidwise gearcheck`

---

## Phase 2 — Normalized gear model

**Goal:** Freeze the internal table shape used by the rules engine (no WoW API calls inside rules).

**Status: done** (2026-08-24)

### Checklist

- [x] Document field list (`types/GearCheck.ts` + this section)
- [x] Collector returns only that shape (`schemaVersion = 2`)
- [x] Unknown / missing data explicit (`gaps[]` + `known` flags); never fake BAD
- [x] Dump shows category / armorType / weaponType / stats / sockets / enchant / gems / gaps

### Model (rules-facing)

```text
GearCheckReport
  schemaVersion = 2
  character { unit, isSelf, name, classFile, specTab, specKnown, gaps[] }
  equipment[]  (stable slot order)
    slot { key, slotName, policy CHECKED|IGNORED|PLANNED, policyNote?, empty, item?, gaps[] }
      item {
        itemId, name?, equipLoc?, category, armorType?, weaponType?, isRelic,
        stats{}, sockets{}, enchant{ enchantId, present, known, gaps[] },
        gems[], metaGemId?, infoKnown, pendingLink, gaps[]
      }
  gaps[]
  collection { … inspect / counts — not for rules }
```

- Stat ids: `strength`, `agility`, `stamina`, `intellect`, `spirit`, ratings, `spellPower`, `resilience`, `armor`, …
- Armor types: `cloth` / `leather` / `mail` / `plate` / `shield` / `offhand` / …
- Weapon types: `axe1h`, `sword2h`, `staff`, …
- Enchant with id but no catalog yet → `known = false` + gap `ENCHANT_UNMAPPED`
- `itemLevel` is collected for display only

### How to test

1. `/reload`, `/rw gearcheck` (self and nearby target).
2. Dump header shows `schemaVersion=2`.
3. Filled slots show `category`, `armorType` or `weaponType`, `stats: …`, `sockets: …`, `enchant: id=… present=… known=… name=…` (name when catalogued), `gems: #n=id color name=…` (name from item info when known).
4. Catalogued enchants show `known=yes` (no `ENCHANT_UNMAPPED`); unknown ids stay not-checkable.
5. Trinkets remain `PLANNED`; shirt/tabard `IGNORED`; relics `IGNORED / relic`.

### Implemented files

- `Raidwise/GearCheck.lua` — normalize + Phase 2 dump
- `types/GearCheck.ts` — TypeScript shape for consumers / fixtures
- UI copy updated for Phase 2 dump wording

---

## Phase 3 — Rules engine

**Goal:** Findings only (`code`, severity, category, slot, message). Seed catalogs from AtlasLoot + enchantId map.

**Status: done** (2026-08-24)

### Checklist

- [x] Enchant / gem seed catalogs (`GearCheckCatalog.lua`)
- [x] Class + 30-spec profiles (`GearCheckProfiles.lua`)
- [x] Rules engine emits findings only (`GearCheckRules.lua`) — no OK/REPLACE/BAD
- [x] Evaluate after collect; dump prints `Findings (N):`
- [x] Catalogued enchant ids mark `known = true` (clears `ENCHANT_UNMAPPED`)
- [x] Cloaks / jewelry skip armor-type rules
- [x] Offline fixtures: `/rw gearcheck test`
- [x] `types/GearCheck.ts` findings + profile types

### Finding shape

```text
{ code, severity: hard|soft|info, category, slot?, message }  -- message EN only
```

Common codes: `ARMOR_FORBIDDEN`, `ARMOR_UNWANTED`, `STAT_UNWANTED`, `STAT_FORBIDDEN`, `RESILIENCE_PVE`, `MISSING_ENCHANT`, `ENCHANT_NOT_CHECKABLE`, `GEM_LOWER_LEVEL`, `SPEC_UNKNOWN`, …

Profile stat ranks: **preferred / acceptable / unwanted / forbidden** (`unwanted` → soft `*_UNWANTED` → REPLACE).

### How to test

1. `/reload`, then `/rw gearcheck test` → expect **4 / 4 passed**.
2. `/rw gearcheck` (self) → dump ends with `Findings (N):` and profile line.
3. Cloth on a plate tank (or fixture) → `ARMOR_FORBIDDEN`; resilience gear → `RESILIENCE_PVE`.

### Out of scope this phase

Item verdicts, overall status, chat report modes, meta activation across full set.

### Implemented files

- `Raidwise/GearCheckCatalog.lua` — enchantId / gem itemId seeds
- `Raidwise/GearCheckProfiles.lua` — class fallbacks + 30 specs
- `Raidwise/GearCheckRules.lua` — `EvaluateGearCheck` + `GearCheckRulesSelfTest`
- `Raidwise/GearCheck.lua` — attach findings; Phase 3 dump
- TOC loads Catalog → Profiles → Rules → GearCheck

---

## Phase 4 — Item verdicts

**Goal:** Per-slot OK / REPLACE / BAD from findings (no GOOD yet).

**Status: done** (2026-08-24)

### Checklist

- [x] Aggregate findings → slot `verdict` (`AggregateGearCheckVerdicts`)
- [x] hard → **BAD**; soft → **REPLACE**; clean preferred + max enchant/gems → **GOOD**; else **OK** (info ≠ BAD)
- [x] Dump shows `verdict=` per filled checked slot + `Item verdicts: GOOD=… OK=… REPLACE=… BAD=…`
- [x] Self-test covers verdicts (`/rw gearcheck test`)
- [x] Types: `GearCheckItemVerdict`, `verdicts` summary

### Aggregation

```text
any hard finding on slot  → BAD
else any soft finding     → REPLACE
else preferred type + max-level enchant (if required) + max-level gems → GOOD
else                      → OK   (info-only / not-checkable / acceptable type do not demote)
IGNORED / PLANNED / empty → no verdict (counted as skipped)
```

Overall gear status is **Phase 5** (worst-wins + resilience counts; all-GOOD → overall GOOD).

### How to test

1. `/rw gearcheck test` → all checks pass (findings + verdicts).
2. `/rw gearcheck` → each filled checked slot shows `verdict=OK|REPLACE|BAD`.
3. Same fixtures: cloth/prot → BAD; resilience → REPLACE; missing enchant → REPLACE; SP/fury → BAD.

### Out of scope this phase

Overall status, meta activation across full set, chat reports, catalog false-positive fixes (see backlog).

---

## Phase 5 — Gear-level evaluation

**Goal:** Overall status (worst wins), resilience 1→REPLACE / 2+→BAD, meta activation across full set, informational set counts (T9/T10…).

**Status: done** (2026-08-24)

### Checklist

- [x] Overall status from item verdicts + findings (worst wins)
- [x] Resilience: 1 unique item → overall at least REPLACE; 2+ → overall **BAD**
- [x] Meta activation vs full-set gem colors (`META_INACTIVE` / `META_NOT_CHECKABLE`)
- [x] Issue counters: items / enchants / gems / meta
- [x] T9/T10 set counts informational only (do not change verdicts)
- [x] Dump shows Overall / Issues / Meta / Sets
- [x] Self-test covers resilience pair, meta blues, T10 4/5

### Overall

```text
any BAD item (or hard finding)     → BAD
else any REPLACE item (or soft)    → REPLACE
else                               → OK
then: resilienceItems >= 2         → BAD
      resilienceItems == 1 and OK  → REPLACE
```

Set lines like `T10: 4/5` never change OK/REPLACE/BAD.

### How to test

1. `/rw gearcheck test` — includes two-ring resilience → overall BAD; Chaotic without blues → `META_INACTIVE`; two blues → active; T10 4/5.
2. `/rw gearcheck` — header shows `Overall: …` and optional `Sets (informational):`.

### Out of scope this phase

Chat reports, real UI breakdown, catalog false-positive fixes (see backlog). Socket-bonus matching. 2pc vs 4pc advice.

---

## Phase 6 — UI

**Goal:** Proper Gear Check screen (summary + item/enchant/gem breakdown + surface-level disclaimer). Phase 1 dump can be removed or moved behind a debug toggle.

**Status: done** (2026-08-24)

### Checklist

- [x] Surface-level disclaimer stays visible
- [x] Summary band: Overall, class/spec icons, who/class/spec, GS/iLvl, issue counts, meta, sets
- [x] Filters: All / Items / Enchants / Gems / **OK** with explainable findings per slot
- [x] Verdict coloring: BAD red, REPLACE gold, OK idle, GOOD green
- [x] Raw dump via **Show as a text** (Select all works in text view)
- [x] `LAYOUT_VERSION = 10` (two-column layout; text view + Select all in top band; class/spec icons)
- [x] Locale chrome (findings messages stay EN)

### How to test

1. `/reload`, `/rw gearcheck` — summary + breakdown (not the dump).
2. Switch All / Items / Enchants / Gems / OK; empty category shows “No issues…”.
3. **Show as a text** → raw Phase 5 dump + Select all; toggle off returns to UI.
4. Switch language in Settings — chrome translates; finding text stays English.

### Out of scope this phase

Chat print buttons / `/rw gearcheck summary|items|…` (Phase 7). Catalog false-positive fixes.

---

## Phase 7 — Chat output

**Goal:** Print summary / items / enchants / gems to self chat.

**Status: done** (2026-08-24)

### Checklist

- [x] Chat reports honor header report channel (`DEFAULT_CHAT_FRAME` when Self or channel unavailable; `[Rw]-gear` prefix)
- [x] Modes: summary / items / enchants / gems / **ok**
- [x] UI buttons: Report summary / items / enchants / gems / **Report OK**
- [x] Slash: `/rw gearcheck summary|items|enchants|gems|ok` (alias `report` → summary)
- [x] Scans first when no cached report
- [x] Detail lines capped (15) with “… and N more”
- [x] Layout continued on target page (see Phase 6 / Saved reports; current `LAYOUT_VERSION = 10`)

### How to test

1. Scan someone, then press **Report summary** — `[Rw]-gear Name — STATUS` goes to the header report channel (Auto = raid/party).
2. **Report items / enchants / gems / OK** — category lines only; empty category says so.
3. `/rw gearcheck summary` (and items/enchants/gems/ok) without prior scan — scans then prints.
4. Set **Slf (Self)** in the header and confirm reports stay in the local chat frame.

### Out of scope this phase

Catalog false-positive fixes; Phase 8 ruleset polish.

---

## Phase 8 — Ruleset expansion

**Goal:** All 30 specs covered; keep “being maintained” copy accurate; fix known false positives.

**Status: done** (2026-08-24)

### Checklist

- [x] Confirm 30 spec + 10 class profiles (`GetGearCheckProfileCount` = 40)
- [x] Enhancement: `S_ENHANCE` prefers intellect (Rhee false positive)
- [x] Gems: unknown → `GEM_NOT_CHECKABLE` only; expand ICC epic purple/orange/green seeds
- [x] Legs: Frosthide / Icescale / Nerubian / Jormungar / spellthread ids
- [x] Engineering: Nitro, Hyperspeed, Pyro Rocket, Flexweave, Frag Belt
- [x] Weapons: Mongoose, Executioner, Black Magic, Accuracy, Blade Ward, Blood Draining, …
- [x] Optional enchants (rings / waist): evaluate when present, never MISSING
- [x] Self-test covers Enh intellect, unknown gem, Nitro, Icescale, profile count

### How to test

1. `/rw gearcheck test` — all checks pass (incl. Phase 8 fixtures).
2. Scan **Rhee** (Enhancement): intellect should not be unwanted; epic gems / Icescale / Nitro should not soft-REPLACE for level.
3. Spot-check one tank / caster / healer if editing profiles later.

UI copy still says rules are **being maintained** — catalogs remain expandable when new ids appear.

---

## Saved reports (spec §25–27)

**Goal:** Manual Gear Check snapshots with retention and version stamps for later interpretation.

**Status: done**

### Checklist

- [x] `GearCheckSavedReports.lua` — save / list / get / delete / prune
- [x] `RaidwiseDB.gearCheckSaved` — not auto-persisted on scan
- [x] ~14-day retention; prune on load and save
- [x] `rulesetVersion` + `dataVersion` on each entry
- [x] Target UI: **Save report**, scrollable saved list (load), **Delete selected report**
- [x] Loaded snapshot is frozen (no re-evaluate with current rules)
- [x] Self-test merged into `/rw gearcheck test`

### How to test

1. Scan a player → **Save report** → chat confirms save.
2. `/reload` → open Gear check → saved row still listed → click loads snapshot.
3. **Delete selected report** removes entry; live scan unchanged.
4. `/rw gearcheck test` — saved-report checks pass.

---

## Raid-wide gear check

**Goal:** Scan party/raid roster, show per-player overall summary, drill down to target UI.

**Status: done**

### Checklist

- [x] `StartGearCheckRaidScan` — sequential inspect queue over `CompositionMembers()`
- [x] `PageRaid.lua` — Scan, summary counts, gear-check rows on roster cells (groups 1–5 / 6–8)
- [x] Shift+click cell → `ShowGearCheckReport` on **Gear check (target)** (no rescan)
- [x] `IsGearCheckScanBusy` — blocks overlapping target/raid scans
- [x] EN/RU chrome strings
- [x] Raid roster `LAYOUT_VERSION = 3`

### How to test

1. Join a party or raid (solo shows empty message).
2. Open **Raid roster** → **Scan** → status shows `Scanning N/M: …`.
3. Summary line updates; player cells show Overall / BAD / Repl. / Issues on lines 6–7.
4. Shift+click a scanned player cell → **Gear check (target)** shows that player's findings.
5. While raid scan runs, **Gear check (target)** Scan shows busy message.
6. Spec icons/names in raid cells should match that player (not the previous inspect target); Overall should match a single-target scan for the same player.

Inspect waits for **both** gear slots and talent spec (`INSPECT_TALENT_READY`) before scoring. Spec is not read from the previous inspect buffer. Party inspect queue is paused during gear scans to avoid `NotifyInspect` conflicts.

Empty sockets on inspected players are confirmed only after inspect readiness, with explicit gem fields in the item link and matching empty-socket labels from the inventory tooltip. Localized labels tolerate color markup and surrounding whitespace. Pre-inspect placeholders, incomplete links, and hyperlink-only fallbacks remain uncertain; unavailable socket data has its own explanatory text rather than claiming a gem ID is absent from the catalog. Confirmed empty sockets produce `MISSING_GEM`.

---

## Trinket pools (maintenance)

**Goal:** Per-spec trinket allowlists from BiS examples — **preferred** (ICC/RS endgame → GOOD) and **allowed** (+ ToC/Ulduar/badge progression → OK, no soft finding).

**Status: done** (`GearCheckTrinkets.lua` + `trinketPool` on each profile)

| Pool | Specs | preferred (BiS) | allowed adds |
|------|-------|-------------------|--------------|
| `phys` | Arms/Fury, Rogue, Frost/UH DK, Feral | DBW, Sharpened Scale | ToC verdicts, Needle, Mirror, Ulduar phys, … |
| `ret` | Ret Paladin | + Tiny Abomination | same as phys allowed |
| `hunter` | BM/MM/SV | DBW, Sharpened | ToC, Needle, Mirror, Banner |
| `caster` | Ele, Shadow, Mage, Lock, Balance | Charred, Phylactery, Dislodged | Reign, Sundial, Je'Tze, … |
| `healer` | Disc/Holy Priest, Resto Shaman/Druid | Glowing, Althor's, Solace, … | Scale of Fates, … |
| `holyPaladin` | Holy Paladin | Same as healer | Healer pool + Charred Twilight Scale (normal/heroic), capped at B |
| `tank` | Prot Warrior/Pal, Blood DK | Fang, Petrified, Skeleton Key, … | Ick's Thumb, Glyph, entry tank, … |
| `enhance` | Enh Shaman | phys ICC + Herkuml + caster ICC | full phys + caster progression |

Outside **allowed** → soft `TRINKET_NOT_PREFERRED`. Inside allowed but outside preferred → **OK** (“progression pool, not endgame BiS”). Expand IDs in `GearCheckTrinkets.lua` when false positives are reported.

---

## Stat profile tuning (maintenance)

**Goal:** Per-spec stat gradation (`preferred / acceptable / unwanted / forbidden`) aligned with BiS surface rules.

**Status: done** (all classes have per-spec stat templates; class fallbacks may still use shared templates)

### Coverage

| Class | Stat templates |
|-------|------------------|
| Warrior | `S_WARRIOR_DPS`, `S_WARRIOR_PROT` |
| Paladin | `S_PALADIN_HOLY`, `S_PALADIN_PROT`, `S_PALADIN_RET` |
| Hunter | `S_HUNTER` |
| Rogue | `S_ROGUE` |
| Priest | `S_PRIEST_DISC`, `S_PRIEST_HOLY`, `S_PRIEST_SHADOW` |
| DK | `S_DK_BLOOD`, `S_DK_DPS` |
| Shaman | `S_SHAMAN_ELEMENTAL`, `S_ENHANCE`, `S_SHAMAN_RESTO` |
| Mage / Warlock | `S_DRUID_BALANCE` (shared caster DPS gradation) |
| Druid | `S_DRUID_BALANCE`, `S_DRUID_FERAL`, `S_DRUID_RESTO` |

Edit via `gear-check-debug/stats-matrix.html` → export Lua → paste into `GearCheckProfiles.lua`.

Legacy name: `S_DRUID_BALANCE` is also used for all mage/warlock specs (rename to neutral `S_CASTER_DPS` is optional cleanup).

---

## File map (expected)

| File | Role |
|------|------|
| `Raidwise/GearCheck.lua` | Scan orchestration and last-report state; see the current module boundary table above |
| `Raidwise/GearCheckCatalog.lua` | Enchant / gem seed catalogs |
| `Raidwise/GearCheckSets.lua` | T9/T10 item-id → set key (informational) |
| `Raidwise/GearCheckBis.lua` | Generated spec BiS item-ID sets (S grade); `scripts/generate-gear-check-bis.js` |
| `Raidwise/GearCheckProfiles.lua` | Class + 30-spec rule profiles |
| `Raidwise/GearCheckRules.lua` | Findings engine and independent rule revision; self-tests live in `GearCheckSelfTest.lua` |
| `Raidwise/GearCheckSavedReports.lua` | Manual save / load / prune (~14 days) |
| `types/GearCheck.ts` | Frozen TypeScript shape (report + findings) |
| `Raidwise/PageGearCheckTarget.lua` | Target/self UI (scan, save, saved list) |
| `Raidwise/PageRaid.lua` | Raid roster grid + integrated gear-check scan/report rows |
| `gear-check-debug/stats-matrix.html` | Stat rank matrix editor + Lua export |
| `docs/Gear-Check-Progress.md` | This tracker |
| `docs/RaidWise Addon — Gear Check Specification.md` | Product spec |
| `docs/Gear-Check-Surface-From-BiS.md` | Armor / weapon / trinket surface rules distilled from example BiS lists |

Scans are **not** auto-persisted; user must press **Save report** (spec §25).

### Report 1 corrections (2026-09-10)

- Meta summaries show OK only for a confirmed active meta. Unresolved inspect data shows not checkable; confirmed missing metas retain their issue count.
- Precision glove enchant (3234, +20 hit rating) is recognized as a valid Northrend enchant for physical DPS.
- Legacy socket enchants 2711 and 2752 resolve to Sovereign Shadow Draenite (23111, +3 strength/+4 stamina) and Inscribed Flame Spessarite (23098, +3 strength/+3 crit). Both produce lower-level gem findings, including when inspect cannot resolve their gem links.
- Sphere of Red Dragon's Blood (37166) and Darkmoon Card: Death (42990) are allowed starter physical DPS trinkets (B, not preferred A).
- The original report remains a captured snapshot; rescan the target to obtain updated findings.

Summary chat reports and their tooltip previews list every item grade in order (`S: 0 A: 0 B: 8 C: 3 D: 1`), including zero counts, in both Short and Full forms.

Raid roster personal report buttons and previews prefix every line with `[Rw]-raid NAME Gear: ` or `[Rw]-raid NAME Enchants/Gems: `. The latter includes enchants, gems, and meta findings. Continuation lines repeat the player and category within the chat length limit.

Target gem reports (Short and Full) group findings by warning theme, list each affected slot once per theme, and omit gem IDs. Tooltip previews use the same grouping. Detailed findings and raw dumps retain gem identities.

### Chat template constraints

- Prefer one compact chat message per report action. Group warning themes, deduplicate slots, and omit diagnostic IDs from player-facing summaries.
- Budget at most 255 UTF-8 bytes for the complete outgoing message, including the Raidwise prefix, player name, category, separators, and any other added text. Cyrillic characters consume multiple bytes. Never split a UTF-8 character when shortening a message.
- Do not treat immediate multi-message bursts as safe. Flood thresholds depend on realm configuration; there is no universal allowed burst count.
- Current limitation: split reports are still sent immediately by the existing sender. These template constraints do not implement pacing or guarantee protection from server spam filters.
- References: historical 3.3.x ChatThrottleLib enforces the 255-byte limit (https://repos.curseforge.com/wow/guilder/file/c25618699222/Libs/ChatThrottleLib/ChatThrottleLib.lua); AzerothCore exposes ChatFlood.MessageCount and ChatFlood.MessageDelay (https://github.com/azerothcore/azerothcore-wotlk/blob/master/src/server/apps/worldserver/worldserver.conf.dist).

Chat prefixes use `[Rw]` (including `[Rw]-gear` and `[Rw]-raid`). The colored Personal opinion chat mark uses `<Rw>` to distinguish it from report prefixes.

### Northrend meta-gem catalog corrections

- Relentless Earthsiege Diamond (41398) requires one red, one yellow, and one blue gem. Its requirement was already correct; the report's unknown activation was caused by unresolved socket enchant 3750. This now resolves to Enchanted Tear (42702), a +6 all-stat prismatic gem that counts toward all three colors. It remains below maximum gem strength.
- Audited all 21 Earthsiege/Skyflare meta requirements and static stats; corrected Austere, Bracing, Destructive, Eternal, Forlorn, and Invigorating requirements, plus Powerful's three-blue requirement. Added all eight lower-strength Starflare/Earthshatter vendor metas with their own requirements.
- META_NOT_CHECKABLE wording now covers unavailable gem colors as well as unknown catalog requirements. Missing inspect data is never treated as proof that a meta is active.
- Reference data: [WoWSims WotLK meta conditions](https://github.com/wowsims/wotlk/blob/master/ui/core/proto_utils/gems.ts), [gem stats](https://github.com/wowsims/wotlk/blob/master/assets/database/db.json), and [Outfitter socket enchant mapping](https://github.com/cdmichaelb/Outfitter/blob/master/Outfitter.lua). Catalog revision: catalog-2026-09-10-meta2. Rescan to replace the captured report snapshot.

### WoWSims gem comparison (2026-09-10)

Compared the existing catalog with the [WoWSims WotLK gem database](https://github.com/wowsims/wotlk/blob/master/assets/database/db.json), using its [stat/color schema](https://github.com/wowsims/wotlk/blob/master/proto/common.proto). This is an incremental Northrend catalog update, not a replacement or runtime dependency.

- Added 72 Perfect uncommon cuts, Enchanted Pearl (42701), and Kharmaa's Grace (44066). Perfect cuts and Enchanted Pearl remain below ICC epic strength; Kharmaa's Grace retains its max-strength resilience stat and existing PvE warning behavior.
- Corrected Subtle Dragon's Eye (42151) from yellow to red. All existing overlapping gem stats matched the reference.
- Preserve existing meta requirements, profession flags, grading exceptions, legacy gems, and explicit socket-enchant mappings. Older-expansion gems absent from Raidwise were outside this Northrend update.
- WoWSims stores spell/melee hit, crit, haste, and melee/ranged attack power separately. These are deduplicated into Raidwise's single corresponding in-game stat, never added together. Enchanted Pearl is an all-stat prismatic gem and counts for each meta color.
- Catalog revision: catalog-2026-09-10-gems3. New gem recognition still needs a resolved gem item ID unless an explicit socket-enchant mapping exists.
