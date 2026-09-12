# UI view schemes

ASCII layouts for each window and content page. Update this file when a view changes. Pixel sizes live in [`UI-Sizes.md`](UI-Sizes.md). Shared widgets: `UIWidgets.lua`. Page modules and shell: see [`Architecture.md`](Architecture.md).

Architecture overview (TOC order, SavedVariables, refresh API): [`Architecture.md`](Architecture.md).

## Shell

Classic-theme plain panels: left menu flush against content (no gap), no footer.

```text
[ Menu 170 ][ Content 890 x 940 ]
 [ Raidwise v1.x ] [ {page} vN  X ]
 [ menu tabs... ]  [ page body     ]
```

Title bar (content, left to right): **active menu item name**, that page’s layout badge **`vN`**, close **X**. Menu title bar (centered): **Raidwise** + dim addon semver (`Addon.version`, same style as page `vN`). Shell `SHELL_LAYOUT_VERSION` is rebuild-only (not shown in UI).

Menu tabs (top to bottom; each row has an **18×18** category icon + label). Pages are grouped (`PAGES[].group` + `Addon.MenuGroups`) with a dim heading and a 1 px gold split between groups — stable ids for a future module split:

```text
  Personal
[ watch ] Character cooldowns
[ note  ] Export gear and CDs
  ────────
  Raiding
[ glory ] Raid roster
[ BoK   ] Raid composition
[ scope ] Gear check (target)
[ book  ] History
  ────────
  Other
[ gear  ] Settings
[  ?    ] Info
```

Icons (`Interface\Icons\`): `INV_Misc_PocketWatch_01`, `INV_Misc_Note_01`, `Achievement_Dungeon_GloryoftheRaider`, `Spell_Magic_GreaterBlessingofKings`, `INV_Misc_Spyglass_03`, `INV_Misc_Book_11`, `INV_Misc_Gear_01`, `INV_Misc_QuestionMark`.
## Layout versions

Independent from addon semver (`Addon.version` in the menu title bar). Bump a view’s `LAYOUT_VERSION` when structure, sizes, or named frames change; open windows rebuild on next show.

| View | Constant | File | Badge location |
|------|----------|------|----------------|
| Main shell | `SHELL_LAYOUT_VERSION = 15` | `ExporterWindow.lua` | Rebuild only (not shown in UI) |
| Character profile | `PROFILE_LAYOUT_VERSION = 31` | `CharacterProfile.lua` | Title bar (left of close) |
| Cooldowns | `LAYOUT_VERSION = 8` | `PageCooldowns.lua` | Shell title bar (next to page name) |
| Export | `LAYOUT_VERSION = 1` | `PageExport.lua` | Shell title bar (next to page name) |
| Raid | `LAYOUT_VERSION = 30` | `PageRaid.lua` | Shell title bar (next to page name) |
| Composition | `LAYOUT_VERSION = 9` | `PageComposition.lua` | Shell title bar (next to page name) |
| Gear check (target) | `LAYOUT_VERSION = 12` | `PageGearCheckTarget.lua` | Shell title bar (next to page name) |
| History | `LAYOUT_VERSION = 1` | `PageHistory.lua` | Shell title bar (next to page name) |
| Settings | `LAYOUT_VERSION = 14` | `PageSettings.lua` | Shell title bar (next to page name) |
| Info | `LAYOUT_VERSION = 4` | `PageInfo.lua` | Shell title bar (next to page name) |

Rules: see `.cursor/rules/layout-versions.mdc`. Do **not** bump layout versions for locale-only string edits.

## Export gear and CDs

```text
[ short description ]
[ checkbox for including item names ]
[ export data button ] [ select all data button ]
[ short hint about copy ]
[ input for copy ]
```

| Block | In-game text / control |
|-------|------------------------|
| short description | “Export this character's gear, bags, and raid lockouts as JSON.” |
| checkbox | Include item names |
| export data button | **Export character data** — fills the copy box |
| select all data button | **Select all** — highlights JSON for Ctrl+C (disabled until export) |
| short hint | Starts as “After export, press Ctrl+C to copy.” |
| input for copy | Multiline EditBox on black fill; click selects all; Ctrl+C copies. Padding unchanged. |

## Character cooldowns

Account-wide lockout table. Columns persist in `RaidwiseDB.characters` after you log in on each character.

```text
[ short description ]                              [ Refresh ]
        8 px gap
[ Raid / Dungeon | Char (class color + spec icon) | Char | ... ]
                 | last check                     | last check |
                 |                                | [ Remove ] |
[ Icecrown Citadel                               | 10 10h 25 25h | -   ]
[ (Raid)                                         |               |     ]
[ Currency          | (title line — empty in char cols)        ]
[ Gold  12.3kg      | [icon] 645g  | ...                      ]
[ Frost  47         | [icon] 2     | ...                      ]
```

| Block | In-game text / control |
|-------|------------------------|
| short description | “Lockouts and currency for every character saved on this account.” |
| Refresh | Requests fresh raid info, then redraws the table (hover tip) |
| first column | Instance name, then kind in parentheses (`(Raid)` / `(Dungeon)`); **Currency** row at bottom |
| character columns | Name in class color with the primary spec icon; last check time (`18 Aug 23:58`) under the name; current character first; **Remove** on other columns deletes that character from `RaidwiseDB.characters` (login again restores) |
| saved cell | Compact size/mode tags (`10`, `10h`, `25`, `25h`, …); tooltip lists each variant with time until reset |
| currency cell | Title line + label column with account totals (`Gold  12kg`); character columns skip one line, then icon+count chips aligned to labels |
| empty cell | `-` (not saved) |
| empty table | “Log in on each character…” if none saved; “No current lockouts.” if columns exist but no lockouts (**Currency** row still shows) |

Rows come only from current lockouts; each instance is one row with all size/mode variants combined in character cells (10 / 10 Heroic / 25 / 25 Heroic, plus older 20 and 40). Expired lockouts are dropped.

## Raid roster

Current raid layout by group, with integrated gear-check scan. Parties 1–5 are the first block; parties 6–8 are the second. Each party has five player slots. Not in a raid: party members fill group 1 (same inspect/GS pipeline as before; no separate party tab).

```text
[ S·A·B·C·D  Average GS 6158  Tanks 2 · Healers 6 · Melee 12 · Range 5   [scan][export][refresh][back] ]
[ Flask 22/25 [shout] | Food 20/25 [shout] | Armor S·A·B·C·D [shout] | Ench … [shout] ]
[ scan / export status (reserved height)                                 ]
[ progress bar track (always reserved)                                   ]
        8 px gap
[ roster table — or export copy box when text view is on                 ]
[ (class) Rhee          (flask)(food) ]
[ (role)(spec) 6158gs 264ilvl ]
[ P: (crystal)  C: 75% ]
[ Armor A  Ench C ]
[ Gear ][ Rescan ][sword][gem]
        12 px gap
[ 6              ][ 7              ][ 8              ]
[ player cell    ] ...
```

| Block | In-game text / control |
|-------|------------------------|
| mini table | Two rows: chips + GS/roles + icon toolbar (**28**), then four status cells (**20**); **4** px between rows |
| row 1 grade chips | Colored `S · A · B · C · D`; hover shows `GEAR_CHECK_RAID_HINT` |
| row 1 GS / roles | `Average GS` plus role counts on one line; hover shows per-role count and average GS |
| row 1 toolbar | Icon buttons **Scan**, **Export all**, **Refresh**, **Back to roster** in a horizontal strip (**28×28**, **4** px gap). Hover shows the action name and tip. **Back to roster** enabled only while export text is open. Dump click (or Export all) highlights text for Ctrl+C |
| row 2 status | Four equal cells: **Flask**, **Food**, **Armor&Weap**, **Ench&Gems** — gold name + compact counts, **16×16** Battle Shout icon on the right |
| flask / food | `Flask n/total` / `Food n/total`; green when everyone in range has them, red if anyone is confirmed missing. Missing names and `(n missing)` live in the hover tip. Out of range / offline are not listed as missing |
| armor / ench | S / A / B / C / D counts (+ Failed). Dim until first scan (`Press Scan to check.`) |
| report icon | Same Battle Shout icon on every status cell; hover (cell or icon) shows the flask / food / armor / ench tip, current counts, plus a preview of the chat line(s) that will be posted |
| scan status | Below the mini table; reserved **28** px; scan/export/rescan text. After a successful full scan, shows the completion message, player count, and last full-scan date/time (local clock, including seconds). Restored when returning from export or refreshing locale; individual rescans do not change the full-scan timestamp. Before the first full scan, idle text is empty. |
| progress bar | Below status (**4** px gap); height **14**; track always reserved |
| column header | Group number (`1`–`8`) plus party-only buff icons (Heroic Presence, Vampiric Embrace, Mana Tide Totem); full color = someone in the group provides it, red tint = missing; hover shows spell and provider names. Buffing shaman totems are raid-wide within 30 yd and are not shown here. |
| line 1 | Class icon + class-colored name; **flask** and **food** status icons on the right (14 px). Full color = active buff (flask, or battle + guardian elixirs); red tint = missing; dim = out of range or offline. Hover shows the buff name or status. |
| line 2 | Role icon (same as RaidBuffStatus) + spec icon + `6158gs 264ilvl` |
| line 3 | Compact ratings `P:` + Qiraji crystal icon (green / yellow / red) and `C: {n%}` (or `C: —`); tags stay on hover |
| line 4 | Compact grades `Armor {S|A|B|C|D}  Ench {…}` on one line, or fail / not scanned (`—`) |
| line 5 | **Gear** + **Rescan** + sword and gem report icons; icons post this player's gear/weapon or gem/enchant findings grouped as `CODE - slot,slot; CODE - slot`, including unavailable checks, with chat previews on hover |
| hover | Opinion + tags + community percent/tags + **Guild: Name (Rank)** + **gear check** section + raid-buff icons and names last |
| click | Left-click card → **Character profile**; **Gear check** / **Rescan** / report buttons do their own actions |

API: `StartGearCheckRaidScan`, `GetLastGearCheckRaidResults`, `ShowGearCheckReport`, `IsGearCheckScanBusy`.

Offline characters use a muted card background, muted names, and dimmed grayscale class/role/spec icons; line 2 shows **Offline** instead of cached stats. Characters without a gear-check report use a highlighted background and an amber **Not scanned** label (or the specific scan failure). Offline styling takes priority when both apply, while the scan status remains visible on line 4. Existing reports remain accessible. Normal styling returns on roster refresh after reconnecting or receiving a report. Card geometry and layout version are unchanged.

## Raid composition

Wowhead-style checklist of the current party or raid: who is needed, and which exclusive buffs, externals, DR, debuffs, and regen are already covered. Tracking list: [`Raid-Composition.md`](Raid-Composition.md). Detected primary specs appear as icon/count rows beneath their corresponding class, in talent-tree order; hover for the spec name and players.

```text
[ short description ]                   [ Report missing ] [ Refresh ]
        8 px gap
[ Roles ]                    [ Classes ]
[ (tank)2 (heal)6 (m)12 (r)5 ] [ W2 Pa1 Hu0 Ro1 … Dr0 ]
                             [ spec icons + counts under each class ]
                             [ next detected spec + count           ]
                             [ next detected spec + count           ]
        gap
[ Aggro              ] [ Buffs              ] [ External buffs    ]
[ (icon) Misdirect 1 ] [ (icon) 10% stats 1 ] [ (icon) Focus Magic 0 ]
[ Damage reduction   ] [ Debuffs            ] [ Mana / Health regen ]
```

| Block | In-game text / control |
|-------|------------------------|
| short description | “Who is needed, and which raid buffs, debuffs, and utility are already covered.” |
| Report missing | Posts absent classes to the selected header report channel; all present → short “all classes present” line (hover tip) |
| Refresh | Re-reads the current group (same inspect/GearScore path as Raid roster) (hover tip) |
| Roles | Left of top band: role icon + count; tooltip = role name + who / Missing |
| Classes | Right of top band: all 10 WotLK class icons + count; present gold, absent dim; tooltip = class + who / Missing |
| columns | Three equal columns below; sections pack into the shortest column |
| section heading | Name left; `present/total` right-aligned above row counts; gold, or **red** when present is `0` |
| row | Spell icon, name, count of players who can provide it; **Shift-click** posts effect + class/spec — spell lines to the report chat channel (title bar) |
| present | Gold name and count (`> 0`) |
| missing | Dim name and `0` |
| tooltip | Who in the raid has it; then **Brought by:** on its own line, then one source class/spec — spell per line; hint for Shift-click |

Spec is the primary talent tree (same as Raid roster). Solo shows only your own coverage.

## Gear check (target)

Report buttons include 14 px icons and Chat preview tooltips for the displayed report, using the current Short/Full setting. With no report, the tooltip indicates that a scan is needed.

Two-column layout: **left** — summary, chat reports, filters, findings; **right** — status, Scan, Character profile, Show as a text, Select all (top band), then Save report, Delete selected report, scrollable saved list. Spec / progress: Gear Check specification + `docs/Gear-Check-Progress.md`. Types: `types/GearCheck.ts`. Stat profile editor: `gear-check-debug/stats-matrix.html`.

```text
[ short description — full width ]
[ surface-level limitation — full width ]

LEFT (~670px)                          RIGHT (~220px)
[ summary: Overall / class+spec icons / who / GS+iLvl … ]  [ status line 1 ]
                                        [ status line 2 … ]
                                        [ Scan ]
                                        [ Character profile ]
                                        [ Show as a text ]
                                        [ Select all ]

[ Report summary | … | Report B ]
[ All | Items | Enchants | Gems | B ]

[ scrollable findings by slot ]         [ Save report ]
                                        [ Delete selected report ]
                                        [ Saved reports (~14 days) — scroll ]

(Show as a text → raw dump copy box below top band; text view + Select all stay in top band)
```

| Block | In-game text / control |
|-------|------------------------|
| short description | Overall: S (on published BiS lists) / A (preferred) / B (usable·acceptable) / C (unwanted·soft) / D (forbidden·wrong for spec); surface-level PvE; S is list membership, not a unique BiS pick |
| limitation | S = published BiS-list membership, not a unique pick; no build / encounter / stat-weight optimization |
| Character profile | Opens the displayed scan character by GUID; creates a missing history entry without changing existing notes or ratings. Disabled without a report GUID. |
| summary (left) | Overall status (colored), class + spec icons + character line, GearScore / avg iLvl, issue counts, meta, sets |
| status (right) | Multi-line hint or scan result (`\n` breaks + word wrap); sits above Scan |
| Scan | Resolves target or self, inspects if needed, evaluate + refresh UI (hover tip) |
| Show as a text | Toggles raw dump (replaces main columns; stays in top band) (hover tip) |
| Select all | Enabled in text view when dump has text (hover tip) |
| report buttons | Print to the title-bar report channel (`[Rw]-gear` lines); hover previews the report |
| filters | All / Items / Enchants / Gems / **B**; hover tip per filter |
| breakdown (left) | Active filter name as gold header (except **All**); then `[VERDICT] Slot — Item` plus finding bullets |
| Save report | Stores current evaluated snapshot (~14 days); scans are **not** auto-saved (hover tip) |
| Delete selected report | Removes the currently viewed saved entry (hover tip) |
| saved panel (right) | Scrollable list of all saved entries; click loads frozen snapshot |

`LAYOUT_VERSION = 10`. Slash: `/rw gearcheck`; `/rw gearcheck summary|items|enchants|gems|ok`; `/rw gearcheck test`.

Saved snapshot fields: `rulesetVersion` (`wotlk-3.3.5a-{addonVersion}`), `dataVersion` (`GEAR_CHECK_DATA_VERSION` in catalog). Expired entries prune on load/save.

Raid-wide gear check lives on **Raid roster** (Scan button + report rows per player cell). See that section for layout and interaction.

## Character profile

Standalone window (**460 × 560**) opened from Raid roster or History (left-click a row or filled player cell). Esc or **X** closes it; drag the title bar to move it. Bronze **2** px outer border.

```text
[ Rhee - Character profile                              v31   X ]
| (race)(class) Shaman    | (spec) Enhancement                  |
| GearScore: 6158         | iLvl: 264                           |
| Personal note: Positive | Community note                      |
| Friendly, Good Tank     | mock preview text                   |
| Facts: Raid Leader      | (percentages, sample reports)       |
| Guild: MyGuild (Member) |                                     |
| GUID: 0x...              |                                    |
| Realm: Icecrown         |                                     |
[ History ] [ Edit note ] [ Facts ] [ Events ] [ Memo ]
        --- tab content (History selected by default) ---
(tab: Edit note)
[ Summary: Positive | Tags: Friendly, Good Tank, Prepared ]
( ) Positive   (*) Neutral   ( ) Negative
[ Personal tags — category checkboxes (max 3 per category) ]
(tab: Facts)
[ Facts — role checkboxes (max 4) ]
(tab: Events)
[ Pick type — (icon) category headings + type buttons, scrollable ]
[ Add event ]
[ event rows with category icon · type, Remove, newest first ]
(tab: Memo)
[ Memo ]
[ Personal memo only. Not shared and not recorded in History. ]
[ Memo — multiline edit box ]
[ Save ] [ Reset ]
(tab: History)
[ Met: Icecrown Citadel          Was in the same party: 3 ]
[ When: 2026-08-18 18:54 ]
[ (icon) change log entries, newest first ]
[ Save and Update ]```

| Block | In-game text / control |
|-------|------------------------|
| title | `{characterName} - Character profile` |
| layout version | Title-bar badge `v` + `PROFILE_LAYOUT_VERSION` (UI structure; not addon semver) |
| close | **X** (right of title bar); Esc also closes |
| class / spec | Side-by-side row: race + class icons + name (class-colored), spec icon + name (`-` until inspect) |
| GearScore / iLvl | Side-by-side row: `GearScore: {score}` and `iLvl: {average}`; `-` when unknown |
| Race icon | Character-creation race portrait on the class row (same size as class/spec icons); tooltip shows race name and faction |
| Summary (left column) | Read-only: personal note, tag summary, facts, guild, GUID, realm — reflects **saved** values only until **Save and Update** |
| Community note (right column) | Mock preview for a future addon exchange / web app feature (read-only) |
| Tabs | **History**, **Edit note**, **Facts**, **Events**, **Memo** — **History** opens by default |
| Edit note (editor tab) | Summary line (draft preview); three exclusive radio options; tag checkboxes by category (draft until **Save and Update**) |
| Facts (editor tab) | Role / identity checkboxes (draft until **Save and Update**); max **4** |
| Events tab | Pick an event type by category (icon + heading), **Add event** / **Remove** edit a draft list; **Save and Update** persists events with auto zone/instance context on add |
| Memo (editor tab) | Personal-use hint; multiline EditBox; **Save** / **Reset**. Memo is not written to History |
| History tab | **Met** (left) and **Was in the same party** count (right) on the first row, then **When**, then logged opinion/tag/facts/event changes with a kind or event-category icon (and any older memo rows if present). Joining the same party or raid logs an **In the same party** attendance event whenever the count increments (first meet, or ≥30 min since last seen) |
| Save and Update | Bottom of window on **Edit note** / **Facts** / **Events** only; saves opinion, tags, facts, and events. Hidden on **History** and **Memo** (memo uses its own **Save** / **Reset**) |
| editable | Opinion, tags, facts, events, and notes require a valid GUID; controls are disabled otherwise |
| persistence | Opinion/tags/facts in `RaidwiseDB.history[guid].rating.personal`; events in `.events`; notes in `.notes`; change log in `.changes`; `meetCount` for party/raid encounters |

Changing opinion, tags, facts, or events (via **Save and Update**) refreshes Raid roster and History when the profile closes or Save and Update is pressed. Closing without Save discards Edit note / Facts / Events drafts.

See also [Reputation.md](Reputation.md) for entity definitions and future share matrix.

## History

Players you have been in a party or raid with (not yourself). Each GUID is stored in `RaidwiseDB.history` and survives logout. First meeting zone, time, and realm are kept; later grouping updates GearScore, iLvl, spec, and last seen.

```text
[ short description ]                              [ Refresh ]
        8 px gap
[ Name | (class) | (spec) | Opinion | Tags | GS | iLvl | Met in | When | Guild (rank) ]
[ Rhee |  SH   |  Enh   |    +    | Friendly, Good Tank | 6158 | 264 | Icecrown Citadel | 2026-08-18 18:54 | MyGuild (Member) ]
```

| Block | In-game text / control |
|-------|------------------------|
| short description | “Players from your parties and raids. Saved on this account.” |
| Refresh | Records the current group again, then redraws the saved list |
| Name | Class-colored character name |
| Class | Class icon; hover shows localized class name |
| Spec | Primary talent tree icon; hover shows spec name |
| Opinion | Saved personal opinion Qiraji crystal: green / yellow / red |
| Tags | Colored tag summary (up to 3 labels, then `+N`); `-` when none |
| GS | Last stored GearScore |
| iLvl | Last stored average item level |
| Met in | Raid, dungeon, or zone at first meeting |
| When | First meeting date and time |
| Guild | Last stored `GuildName (Rank)` |
| hover | Tooltip shows full opinion label and tag summary |
| click | Left-click a row opens **Character profile** |

Notes are stored on each history record (`notes`) and edited in Character profile; they are not shown in this table.

## Settings

The Changelog section below Unit tooltips provides the repository's `CHANGELOG.md` URL and a localized Select all button. Select the address, then press Ctrl+C and paste it into a browser.

A **Theme: Dark / Theme: Light** toggle in its own **Theme** category below Language applies immediately and persists in `RaidwiseDB.theme`. Dark is the default.

Category titles use full-width shaded bars with a gold left accent and larger text. The unit-tooltip controls and live preview share one panel; the preview is a subordinate label, not another category.

```text
[ language heading ]
[ short hint ]
[ English button ] [ Русский button ]

[ Theme category bar ]
[ Theme: Dark / Theme: Light button ]

[ Startup page heading ]
[ short hint ]
( ) Cooldowns   ( ) Export      ( ) Raid        ( ) Composition
( ) Gear target ( ) History     ( ) Settings

[ Unit tooltips category bar ]
[ short hint ]
+------------------------------------------------------------------+
| [ ] Hide personal opinion   | Live tooltip preview                |
| [ ] Hide personal tags      | Compact: sample lines               |
| [ ] Hide community rating   | Stacked: sample lines               |
| [ ] Hide community tags     |                                    |
+------------------------------------------------------------------+
```

| Block | In-game text / control |
|-------|------------------------|
| language heading | Language |
| short hint | “Interface language. Saved on this account.” |
| English / Русский | Menu-style buttons; the active locale is selected. Choice is stored in `RaidwiseDB.locale` (`enUS` / `ruRU`). Default is the client locale. |
| Startup page | Exclusive radio group for left-menu pages (**Info** excluded); selected page opens on `/raidwise`. Stored in `RaidwiseDB.startupTab` (default `cooldowns`). Saved `party` / `gearraid` migrate to `raid`. |
| Report chat channel (shared title bar) | `Slf`, `Say`, `Prt`, `Rd`, `Rdw`, `Gld`, `Gof`, `Aut` exclusive radios with chat-colored labels and full-name tooltips; destination for Raid roster, Composition, and Gear check reports. Stored in `RaidwiseDB.reportChannel` (default `auto` = RAID in a raid, PARTY in a party). Unavailable channels print to the local chat frame instead. |
| Gear check report form (shared title bar) | Short (default) or Full wording for Gear check Report buttons / `/rw gearcheck …`. Stored in `RaidwiseDB.reportForm`. |
| Unit tooltips | Checkboxes stored in `RaidwiseDB.tooltip` (`hidePersonal`, `hidePersonalTags`, `hideCommunity`, `hideCommunityTags`); default all shown |
| Live tooltip preview | Inside the Unit tooltips panel, beside its checkboxes; compact and stacked sample lines update when options change |

Switching language updates the left menu, page labels, and visible tables without `/reload`. Player unit tooltips (mouseover/target) append personal opinion + top 3 tags and, for players in History, community mock percent + top 3 tags (`UnitTooltips.lua`).

## Info

```text
[ about heading ]
[ intro sentences ]
[ slash command list ]
[ menu icon ] Menu name  vN
[ section sentences ]
[ section list ]
… (one block per menu page except Info)
[ github heading ]
[ short hint about copy ]
[ input for repo URL ] [ select all button ]
```

| Block | In-game text / control |
|-------|------------------------|
| about heading | About |
| intro | Raid-prep overview, then a slash-command list (`/raidwise`, `/rw`, `close`, `gearcheck`); one sentence per line |
| feature sections | Same icons as the left menu; title = menu label; **`vN`** = that page’s `LAYOUT_VERSION`; body is sentences plus a list of what the view does |
| github heading | GitHub |
| short hint | “Select the URL, then press Ctrl+C to copy.” |
| input for repo URL | Single-line copy box with `https://github.com/sergimax/Raidwise-addon` |
| select all button | **Select all** — highlights the URL for Ctrl+C |
| scroll | Vertical scroll when sections exceed the content area |

## Adding a view

1. Add a tab in `PAGES` in `ExporterWindow.lua` (shell) with a `group` (`personal` / `raiding` / `other`) and a `Page*.lua` module under `Addon.Pages`.
2. Give the view a `LAYOUT_VERSION` constant, stamp it on the frame, and show it in the shell title bar next to the menu name (pages) or with `AttachLayoutVersionLabel` (profile popup).
3. Paste a new `## Title` scheme here (same `[ block ]` style) including the layout `vN`.
4. Implement the page and record sizes in `UI-Sizes.md`.
5. See [`Architecture.md`](Architecture.md) for load order and the two version concepts (addon semver vs layout).

> **Note:** Shell and per-page layout versions force recreate when constants bump (see Architecture). Named scroll/edit frames use a `V` + layout version suffix.

The shared header contains Short / Full exclusive report-form radios immediately before the chat channels. They retain `RaidwiseDB.reportForm` and are removed from Settings. Full form names and help remain localized in tooltips.

Header report controls are contextual: chat channels appear only on Raid roster, Raid composition, and Gear check (target); Short / Full appears only on Gear check (target), whose output uses that setting. Both groups are hidden on all other views. Switching views preserves saved selections.
