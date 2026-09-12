# Offline addon tests

Use Node.js 24.4 or later in the 24.x series and npm. From the repository root:

```sh
npm ci --ignore-scripts
npm run check
```

`npm run check` type-checks the TypeScript test runner and runs the tests. Use
`npm test` for tests alone or `npm run test:watch` while editing. Failures return
a nonzero exit status for CI.

The runner is TypeScript (`gear-check.test.mts`) using Node's built-in `node:test`
and `node:assert/strict`. Node runs the erasable TypeScript directly; `tsc` handles
type checking separately. The existing CommonJS scripts in `scripts/` keep their
module format.

The pinned [wasmoon-lua5.1](https://github.com/JX3BOX/wasmoon-lua5.1) dependency
executes the real addon Lua through WebAssembly. Each test creates an isolated VM,
asserts `_VERSION == "Lua 5.1"`, loads the modules in addon dependency order, and
closes the VM in `finally`. Python, Lupa, and a separate system Lua installation
are not required.

## Test files

For focused iteration, run `node --test tests/scan.test.mts` (substitute the
relevant file below). Before finishing code/test changes, run `npm run check`
after the final edit. Reuse installed dependencies unless missing or the lockfile
changes; repeat successful checks only after new edits or unresolved concerns.

| Changed behavior | Start with |
|---|---|
| Scan lifecycle, retries, cancellation | `scan.test.mts` |
| Inspect ownership and roster handoff | `inspect.test.mts` |
| Collection, grades, gems, meta, report chat/header | `gear-check.test.mts` |
| Saved revision compatibility | `saved-revisions.test.mts` |
| Roster snapshot sharing | `roster-refresh.test.mts` |
| Ratings, migrations, profile drafts/saving | `history.test.mts` |
| Theme bindings | `theme.test.mts` |
| Dump jobs, cancellation, output routing | `dump.test.mts` |

Assert behavior rather than incidental version numbers: header radio tests check
exclusivity and page visibility, not the current Settings layout version. Keep
exact values for real contracts, such as Lua 5.1, schema compatibility and
protocol limits. Rebuild tests should compare frame stamps with registered
layout versions; revision tests should compare metadata across changes.

- `gear-check.test.mts`: TypeScript orchestration, runtime guard, and test cases.
- `lua/wow-stubs.lua`: minimal offline WoW API substitutes.
- `lua/gear-check-gems.lua`: gem ID, partial-read, cache, and meta regressions
  migrated from the Python harness without removing assertions.
- `../Raidwise/GearCheckSelfTest.lua`: the existing rule self-tests, also available
  in game through `/rw gearcheck test`.

Add a named `test(...)` in the TypeScript runner for a new scenario. Use Node
assertions for values returned from Lua, or a Lua fixture for cases involving
Lua tables, closures, and mocked WoW APIs. Keep the addon implementation in Lua;
tests must exercise it rather than a JavaScript reimplementation. Avoid exposing
test-only helpers on the shipped `Raidwise` namespace. The current regression
fixture finds private closures through Lua's debug API inside the test VM.

Check in the test files, `package.json`, and `package-lock.json`; ignore
`node_modules/`. These are development tools and are not shipped in the addon
folder. Offline tests cannot validate WoW's inspect event timing or real tooltip
behavior: follow collector changes with an in-game rescan.

## Revision independence (phase 9)

`saved-revisions.test.mts` verifies that changing addon semver leaves rule/catalog
metadata unchanged, new rules and catalog revisions can change independently,
legacy saved entries retain their metadata, and absent revision constants return
`unknown`. The normalized report schema and source snapshot remain unchanged.
Module ownership, revision policy, and saved-report compatibility are documented
in `docs/Gear-Check-Progress.md` under Current module boundaries and compatibility.

## Roster refresh coalescing (phase 8)

`RosterRefresh.lua` collects one fresh `BuildRosterSnapshot` per scheduled pass.
`ScheduleRosterRefresh` merges same-frame requests, retaining a forced GearScore
refresh if any caller requests one. History and the visible raid/composition view
receive that snapshot through optional arguments on their existing APIs. Direct
calls without a snapshot continue collecting fresh data. Nothing is cached across
passes; entering a view still requests fresh data.

Roster inspect completion, group/guild updates, and gear-result view refreshes
schedule rendering for the next frame. Inspect queue advancement is immediate;
no inspect settling delay is introduced. History still records while the shell
is hidden. Existing targeted consumable icon updates remain unchanged.

`roster-refresh.test.mts` verifies that eleven merged requests collect two members
exactly twice total (once per member), render one visible view once, and reuse
the same members for history. It also verifies changed identities/data on the
next pass, forced-refresh precedence, hidden-view behavior, and requests raised
during rendering. Existing scan timing tests remain unchanged. These are offline
call counts, not measured in-game CPU or raid-scan speed improvements; the manual
timing protocol below remains pending. No speculative per-card diffing is added.

## UI composition (phase 7)

`UITheme.lua` initializes stable theme/color tables and color/text bindings.
`UIWidgets.lua` supplies generic controls; `RosterWidgets.lua` supplies roster,
gear-grade, consumable, and rating renderers. Load them in that order before
pages. Existing `Raidwise.UITheme` and `Raidwise.Widgets` entry points remain.

Page registrations declare `capabilities.reportChat` and `reportForm`; the shell
reads these flags rather than checking tab IDs. Profile opinion, facts, events,
notes, and history panels now have named builders with the same construction
order, anchors, and dimensions. No layout versions change.

Header tests load the real reporting page registrations. `theme.test.mts` checks
stable palette references, bound-color updates, dark/light round trips, and
unchanged shell dimensions. Profile command regressions also cover the corrected
draft-event removal. Visual parity still needs in-game checks: both themes,
English/Russian, profile tabs, header visibility, and tooltip interactions.

## Profile and history separation (phase 6)

- `PlayerHistory.lua`: rating catalogs, normalization, and rating access.
- `PlayerHistoryStore.lua`: history persistence, encounter recording, legacy
  tag migration, events, and notes. Existing SavedVariables keys are unchanged.
- `RatingPresentation.lua`: rating labels, tooltip formatting, and chat marks.
- `ProfileDraft.lua`: plain draft creation/copying and tag, fact, and event edits.
  UI frames hold this object as `profileDraft`; mutations do not save it.
- `CharacterProfile.lua`: frames, rendering, and command wrappers that explicitly
  persist drafts and refresh views. Notes keep their separate save/reset behavior.

`history.test.mts` covers idempotent legacy migration, saved opinion/tags/facts,
event context copies, notes persistence/reset, draft discard/reopen, tag limits,
and real profile commit/add-event/notes command wrappers with a minimal frame.
It does not validate visual layout or interaction with a running WoW client.
In game, edit and close without saving, reopen, commit changes, switch players,
and exercise Notes Save/Reset in both languages. No layout version is bumped.

## Gear pipeline separation (phase 5)

- `GearCheckCollector.lua`: item/gem reads and normalization; accepts inspect
  readiness explicitly through `CollectGearCheckObservation(unit, inspectReady)`.
  It returns a snapshot without evaluating it or replacing the last report.
- `GearCheck.lua`: request orchestration and last-report state. The existing
  `CollectGearCheck` entry point supplies readiness and retains the snapshot.
- `GearCheckRules.lua`: findings, meta activation, and set counts; its existing
  `EvaluateGearCheck` entry point then invokes grade aggregation.
- `GearCheckGrades.lua`: per-slot, category, and overall grades.
- `GearCheckExplanations.lua`: category tooltip lines and B-grade explanations.
- `GearCheckSelfTest.lua`: the same rule fixtures for offline tests and the
  unchanged `/rw gearcheck test` command; it remains shipped in the TOC.

`Raidwise.GearCheckPolicy` is internal shared eligibility policy, not saved state.
Rules populate it before grades, and grades before explanations. This prevents
display explanations from duplicating the rules that determine eligibility.

The boundary regression asserts collection does not evaluate and exercises all
rule fixtures with live item/talent/identity APIs disabled. Existing gem tests
retain unknown/missing socket and meta coverage. No schema, grade semantics,
scan timing, UI geometry, or SavedVariables keys change in phase 5.

## Dump extraction (phase 3)

`GearCheckDump.lua` owns target/raid dump formatting, name resolution for dump
details, and asynchronous raid export jobs. Public methods and output are
unchanged. `dump.test.mts` covers synchronous/asynchronous output equality,
one-entry-per-frame progress, overlapping job rejection, completion cleanup,
cancellation exactly once, restart, empty results, and routing to the raid export
view or target text view. These checks passed before and after extraction.
Frame rendering and clipboard interaction still require an in-game check.

## Report preparation (phase 2)

`ChatReports.lua` owns final network-message preparation (255 UTF-8 bytes,
complete hyperlinks, and color resets). Self/unavailable-channel output remains
untruncated. `GearCheckReports.lua` owns gear report formatting; the existing
formatting APIs remain available, and `BuildGearCheckChatMessages` supplies the
final messages used by target previews and sending. Roster and composition
previews use the same finalizer as `SendReportChat`.

The final-message regression loads the real transport and verifies Cyrillic,
whole spell links, all gear report modes in Short/Full form, and local/network
preview equality. Existing grouping and composition tests remain in place.
Messages still send immediately; this phase adds no queue or pacing. Gear reports
now share the transport's existing unavailable-channel warning throttle.

## Scan refactoring baseline (phase 1)

`scan.test.mts` loads the real `GearCheck.lua` scheduler into an isolated Lua 5.1
VM for each scenario. `lua/scan-runtime.lua` supplies deterministic frames,
inspect events, unit identities, and elapsed time. `lua/scan-scenarios.lua` mocks
collection and evaluation so scheduler failures are isolated from gem rules.
Existing gem tests continue to exercise collection and normalization separately.

Passing scenarios cover consecutive target requests, rejection of overlapping
requests, idle/unrelated/duplicate inspect events, disappearance and recovery,
the four-second initial deadline, sequential raid requests, and resuming roster
inspects after completion. The roster resume callback is mocked; these tests do
not yet exercise PartyRoster.lua's queue or interference from other addons.

The three original defect scenarios (`identity`, `spec-retry`, `gem-retry`) now
pass as ordinary blocking tests after phase 4. Target and raid cancellation,
restart, and completed-result retention are covered too. `inspect.test.mts`
loads the real PartyRoster.lua queue with the coordinator and verifies timeout
release, identity validation, and roster-to-gear-to-roster handoff.

### Inspect coordination (phase 4)

`InspectCoordinator.lua` alone calls NotifyInspect/ClearInspectPlayer and owns
INSPECT_TALENT_READY. Roster and gear consumers retain their work lists; each
active request captures owner, unit, GUID, callbacks, and deadline. Requests are
polled at 0.25 seconds, initially expire after four seconds, and gear-specific
spec/gem retries each receive two seconds. Completion/cancellation clears the
active request before invoking callbacks. Successful inspect events have no
added settling delay. Roster requests now time out and release the queue.

`CancelGearCheckScan()` cancels target or raid work, returns whether work existed,
and reports `cancelled` exactly once. Completed raid entries remain available.
This is an addon API; no new UI button or slash command is added.

Events without unit identity cannot be conclusively attributed to a server
request on 3.3.5a. Captured GUID validation prevents reassigned unit tokens from
being accepted, but does not prove a no-argument event was generated by this
addon rather than an external inspect addon. Verify interference in game.

### Timing baseline and in-game verification

Simulated baseline: a request with no inspect event releases the scanner at four
seconds; a two-member raid with events supplied 0.25 seconds apart completes at
0.5 simulated seconds with no extra successful-path wait. These are scheduling
observations, not real server latency or CPU performance measurements.

**Actual in-game baseline: pending.** Before changing inspect coordination:

1. Record addon commit, client/server, group size, online/in-range count, and
   whether other inspect addons are enabled. Use the same conditions afterward.
2. Scan the same target five times: record elapsed time, result status, and
   gem/meta/weapon consistency. Keep the first cold scan separate from repeats.
3. Run three full raid scans: record each elapsed time, completed/skipped/timeout
   counts, and any inconsistent reports. Record median and range.
4. During a target scan, switch target or let it disappear. Check recovery with
   another scan. During raid scanning, test a member leaving or going offline.
5. After phase 4, repeat this protocol and compare both correctness and duration.

Do not treat offline test runtime as the in-game baseline. Phase 1's automated
coverage is ready; its manual timing gate remains open until these observations
are recorded.

## Manual CI and future automation

`.github/workflows/tests.yml` runs the same install/check commands on Windows and
Linux. It has only `workflow_dispatch`, so it does not run on pushes or PRs. Once
the workflow is on GitHub's default branch, use **Actions → Addon tests → Run
workflow**. The workflow has been prepared locally; it has not been run on GitHub.

To automate later, add `pull_request:` and the desired `push:` branch filter
under `on:`. The test files and commands do not need to change.
