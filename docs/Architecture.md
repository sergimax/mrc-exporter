# Raidwise architecture and task map

Lua 5.1 / WoW 3.3.5a (`Interface: 30300`). Shipped code lives in `Raidwise/` on the single `Raidwise` namespace. GearScore is optional. Rules: [AGENTS.md](../AGENTS.md). Checks: [tests/README.md](../tests/README.md).

## Find the owner first

Paths below are relative to `Raidwise/`. Search the entry point before reading its helpers or callers.

| Task | Owner files | Entry points / boundaries |
|---|---|---|
| Bootstrap, DB, slash, report transport | `Raidwise.lua` | Lifecycle, slash handlers, `SendReportChat` |
| Language | `Locale.lua` | `Addon:T`; search exact keys in both languages |
| Chat preparation and gear reports | `ChatReports.lua`, `GearCheckReports.lua` | `PrepareReportMessage`, `BuildGearCheckChatMessages` |
| Gear/bags/currency export, lockouts | `CharacterExport.lua`, `CharacterLockouts.lua` | `FormatEquippedGearExport`, `CollectCharacterCurrency`, `BuildCooldownTable` |
| Inspect timing, identity, retries | `InspectCoordinator.lua`, `GearCheck.lua`, `PartyRoster.lua` | `StartInspectRequest`, `RetryInspectRequest`, `StartGearCheckUnitScan`, `CancelGearCheckScan` |
| Item links, sockets and gems | `GearCheckCollector.lua` | `CollectGearCheckObservation`; private `ParseItemLinkParts`, `NormalizeItem` |
| Findings, grades, explanations | `GearCheckRules.lua`, `GearCheckGrades.lua`, `GearCheckExplanations.lua` | `EvaluateGearCheck`, `AggregateGearCheckOverall`; internal `GearCheckPolicy` |
| Saved reports and dumps | `GearCheckSavedReports.lua`, `GearCheckDump.lua` | `SaveGearCheckReport`, `FormatGearCheckDump`; dump module owns asynchronous raid export jobs |
| Rosters and shared refresh | `PartyRoster.lua`, `RosterRefresh.lua` | `BuildRaidGroups`, `BuildRosterSnapshot`, `ScheduleRosterRefresh` |
| Roles, consumables, composition | `RaidRoles.lua`, `RaidComposition.lua` | `UnitConsumableStatus`, `AnalyzeRaidComposition` |
| Rating catalogs/access | `PlayerHistory.lua` | `GetPersonalRating`, `GetCommunityRating`, normalization |
| History, migrations, persistence | `PlayerHistoryStore.lua` | `RecordCurrentGroupHistory`, `SavePersonalRatingForGuid`, `SaveHistoryEventsForGuid`, `SaveProfileNotesForGuid` |
| Unsaved profile edits | `ProfileDraft.lua` | `CreateProfileDraft`, `ToggleProfileDraftTag`, `AddProfileDraftEvent` |
| Profile window | `CharacterProfile.lua` | `ShowRaidCharacterWindow`, `SelectProfileTab`, `CommitProfileRating`; named tab builders |
| Rating display and unit tooltips | `RatingPresentation.lua`, `UnitTooltips.lua` | `GetTooltipSettings`, `BuildUnitTooltipRatingLinesForMember`; tooltip hooks in `UnitTooltips` |
| Theme / shared controls | `UITheme.lua`, `UIWidgets.lua`, `RosterWidgets.lua` | Stable theme tables; generic controls; roster/grade/rating controls |
| Raid and target gear views | `PageRaid.lua`, `PageGearCheckTarget.lua` | `RefreshRaidRosterView`, `RefreshGearCheckTargetView`, `ShowGearCheckReport` |
| Other pages | `PageCooldowns.lua`, `PageExport.lua`, `PageComposition.lua`, `PageHistory.lua`, `PageSettings.lua`, `PageInfo.lua` | `Addon.Pages.*` registrations |
| Shell and navigation | `ExporterWindow.lua`, `Minimap.lua` | `CreateMainFrame`, `SelectTab`, `RefreshLocalizedUI`; separate minimap entry point |

## Load order and contracts

[Raidwise.toc](../Raidwise/Raidwise.toc) is the authoritative executable load order. Read it when adding/moving modules; do not maintain a duplicate full list here.

- Bootstrap creates the namespace; later modules attach methods before normal event-driven use.
- `InspectCoordinator` precedes roster consumers and owns inspect API calls/events. Roster and gear retain their queues and result handling.
- History catalogs, store, presentation, and drafts precede the profile window.
- `UITheme` precedes `UIWidgets`, then `RosterWidgets`, then views. Theme/color tables retain identity across theme changes.
- Gear catalogs precede rules, grades, explanations and self-tests. Saved reports and collector precede `GearCheck`; reports and dumps follow it. Pages load before the shell.

### Gear flow

`StartGearCheckUnitScan` requests inspect through the coordinator. `CollectGearCheck` supplies readiness to `CollectGearCheckObservation(unit, inspectReady)` and retains the observation. Collection does not evaluate. Finalization calls `EvaluateGearCheck`, which produces findings and invokes grade aggregation. Formatting belongs in reports, dumps and explanations.

Schema 3 retains compatibility aliases (`equipment`/`slots`, nested/top-level inspect and counts). Rule and catalog revisions are independent of addon semver; saved reports retain original metadata. See [Gear-Check-Progress.md](Gear-Check-Progress.md) for compatibility and grading details.

### Refresh and reputation flow

`ScheduleRosterRefresh` merges same-frame requests. Each pass builds one snapshot shared by history and the visible raid/composition page. Hidden views are not redrawn; history still records. Snapshots are not cached across passes. Inspect queue advancement is immediate; consumable icons have their own targeted refresh path.

Profile commands persist drafts through the store and refresh rating views. Notes have separate Save/Reset behavior. Some rating accessors normalize/migrate storage; reads are not universally pure. Community ratings include mock fallback data; opinion exchange is not implemented.

### SavedVariables and versions

`RaidwiseDB` is bound as `Addon.db`; `MrcExporterDB` is legacy migration input.

| Key | Owner / purpose |
|---|---|
| `characters` | `CharacterLockouts`: account-wide lockouts/currency |
| `history` | `PlayerHistoryStore`: GUID-keyed meetings, personal ratings, events, private notes, changes |
| `gearCheckSaved` | `GearCheckSavedReports`: snapshots and retention (~14 days) |
| `tooltip` | `RatingPresentation` / Settings: rating tooltip visibility |
| `locale`, `theme`, `startupTab`, `reportChannel`, `reportForm` | Preferences consumed by locale, theme, shell and reporting |

See [Reputation.md](Reputation.md) for reputation data. Addon semver, rule/catalog revisions, and layout versions serve different purposes. Geometry rules live in `AGENTS.md`; current layouts and dimensions live in [UI-Views.md](UI-Views.md) and [UI-Sizes.md](UI-Sizes.md).

## Focused searches

Start with named files from the task table, or `Raidwise/` and `tests/`. Examples from the repository root (PowerShell-compatible):

```powershell
rg -n 'StartGearCheckUnitScan|TryCollectPending' Raidwise/GearCheck.lua
rg -n -C 6 'gemFieldsComplete' Raidwise/GearCheckCollector.lua
rg -n 'SETTINGS_CHANGELOG' Raidwise/Locale.lua Raidwise/PageSettings.lua
rg -n '^function Addon:|^local function' Raidwise/CharacterProfile.lua
git diff --stat
git diff -- Raidwise/GearCheck.lua tests/scan.test.mts
```

Include these paths deliberately when relevant; no global search exclusion hides them:

| Path | Use |
|---|---|
| `Raidwise/GearCheckBis.lua` | Generated IDs: use `scripts/generate-gear-check-bis.js`, which reads sibling web-app presets or `RAIDWISE_BIS_PRESETS`. |
| `Raidwise/GearCheckCatalog.lua`, `GearCheckSets.lua`, `GearCheckTrinkets.lua`, `GearCheckProfiles.lua` | Runtime reference/rule data. Search the ID/spec; these are not all generated. |
| `tools/` | Catalog research scripts, scrape output and seeds; not shipped. |
| `gear-check-debug/`, `screenshots/` | Debug visualizations and UI references. |
| `____GEAR_REPORTS_TO_CHECK/`, `____EXAMPLES/` | Ignored local reports/examples; use explicit paths and `rg --no-ignore` when investigating them. |
| `node_modules/`, `package-lock.json` | Dependency/runtime investigations only. |
| `types/` | Export/report contracts; review when changing data shapes. |

Keep this map current when ownership changes. Put detailed behavior in its domain document rather than duplicating specifications here.
