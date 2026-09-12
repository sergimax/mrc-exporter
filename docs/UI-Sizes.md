# Raidwise UI sizes

Reference for the main window and pages. All units are WoW UI pixels. Shared theme and widgets live in `UIWidgets.lua`; shell sizes in `ExporterWindow.lua`; page-specific columns in each `Page*.lua`. Values here must stay in sync with those tables.

View layouts (ASCII schemes) live in [`UI-Views.md`](UI-Views.md). Architecture: [`Architecture.md`](Architecture.md).

## Shell

| Element | Size | Notes |
|---------|------|-------|
| Content frame (`RaidwiseFrame`) | **890 × 940** | Movable, `DIALOG` strata, Esc-close via `UISpecialFrames` |
| Menu panel (`RaidwiseMenu`) | **170 × 940** | Flush against content left edge (no gap) |
| Menu title bar | height **20** | Top of menu; drag handle; centered **Raidwise** + dim addon semver (same fonts/colors as content title + page `vN`) |
| Menu title gap | 8 px | Between name and version (matches content title bar) |
| Title bar | height **20** | Top of content; drag handle; **active menu name** + page `vN` + close **X** |
| Close button | **16 × 16** | Right side of content title bar |
| Page layout badge | in title bar | `v` + page `LAYOUT_VERSION`, immediately right of the menu name |
| Panel fill | **#12121c** ≈ RGB **0.07, 0.07, 0.11** | Classic theme; alpha 0.98; flat fill (no border edges) |
| Title / status fill | **#1c1c2a** ≈ RGB **0.11, 0.11, 0.165** | Same texture |
| Gear Check gradation | S gold → A green → D red | `GEAR_S` / `GEAR_GOOD` / `GEAR_OK` / `GEAR_REPLACE` / `GEAR_BAD` — grades S…D and spec ranks (preferred…forbidden) |
| Idle text | **#ffeebb** ≈ RGB **1.00, 0.93, 0.73** | Body / menu idle |

## Left menu

| Element | Size | Notes |
|---------|------|-------|
| Menu button | **158 × 28** | Width is `MENU_WIDTH - 12`; **18×18** icon left, label to the right |
| Menu icon | **18 × 18** | `Interface\Icons\…` per tab; TexCoord crop `0.07–0.93` |
| Gap between buttons | 3 px | Inside a group |
| First button offset | 8 px below menu title | Then group heading, then buttons |
| Group heading | height **16** | Dim gold (`GOLD_DIM`); 2 px gap above the first button in the group |
| Gap around separator | 8 px | Extra space above and below the split (in addition to the 3 px button gap) |
| Group separator | height **1** | Gold-dim line, 10 px inset from menu edges |
| Idle fill | **0.125, 0.110, 0.165** | Menu + action buttons |
| Hover fill | **0.180, 0.150, 0.200** | Label `{1.00, 0.91, 0.55}` |
| Selected fill | **0.230, 0.188, 0.125** | Gold label `{1.00, 0.82, 0.00}` |
| Disabled fill | **0.055, 0.055, 0.078** | Label `{0.69, 0.63, 0.44}` |

Groups (top to bottom): **Personal** — Character cooldowns (watch), Export gear and CDs (note); **Raiding** — Raid roster (Glory of the Raider), Raid composition (Greater Blessing of Kings), Gear check (target) (spyglass), History (book); **Other** — Settings (gear), Info (question mark).

## Content padding

| Element | Size | Notes |
|---------|------|-------|
| Page padding | 10 px | Inside content, below title bar |
| Page inner width | **870** | `890 - 10 - 10` |

## Export tab

See [`UI-Views.md`](UI-Views.md) for the ASCII scheme.

| Element | Size | Notes |
|---------|------|-------|
| Description | full inner width | `GameFontHighlight`; wraps via `SetWidth` |
| Gap: description → checkbox | 8 px | |
| Include-names checkbox | **24 × 24** | `UICheckButtonTemplate` |
| Options row height | 28 px | Checkbox + clickable label |
| Gap: checkbox → buttons | 10 px | |
| Export data / Select all | equal width × **28** | `(innerWidth - 8) / 2`; 8 px gap between |
| Gap: buttons → hint | 8 px | |
| Copy hint | full inner width | `GameFontNormalSmall` |
| Gap: hint → copy box | 6 px | |
| Copy box | fills remaining height | Black fill; spacing from `COPY_PAD_*` and scrollbar gap (no tooltip border) |
| Copy box insets | — | Padding via scroll anchors: **5 / 4 / 4 / 4** (`COPY_PAD_L/T/R/B`) |
| EditBox padding inside box | 5, 6, 4, 4 | left, top, right, bottom |
| Scrollbar | 20 px wide | Outside the copy host, 2 px gap; 16 px inset top/bottom |
| EditBox line height | from `ChatFontNormal` | Face size + 2, or EditBox `cursorHeight` once known; not a hardcoded 12 px |
| EditBox min height | 180 | Grows from measured wrapped text height |

## Info tab

See [`UI-Views.md`](UI-Views.md) for the ASCII scheme.

| Element | Size | Notes |
|---------|------|-------|
| Feature icon | **18 × 18** | Same `Interface\Icons\…` as left menu; TexCoord crop `0.07–0.93` |
| Feature title + `vN` | gold title **16** pt, disabled version | Version is that page’s `LAYOUT_VERSION` |
| Body / intro / repo hint | **15** pt, line spacing **2** | `GameFontHighlight` face via `ApplyFontSize`; sentences and `- ` lists |
| Gap between feature blocks | **16** px | |
| Heading → body | 8 px | About / GitHub |
| Body → next heading | 14 px | |
| URL copy box | height **28** | Black fill; internal 8 px horizontal / 4 px vertical padding |
| Select all | **130 × 28** | Right of the URL box; 8 px gap |
| Vertical scroll | **16** | Right of content when sections exceed the page |

## Character cooldowns tab

See [`UI-Views.md`](UI-Views.md) for the ASCII scheme.

| Element | Size | Notes |
|---------|------|-------|
| Toolbar row | height **28** | Hint left, Refresh right |
| Gap: toolbar → table | 8 px | Table starts below Refresh button |
| Refresh | **96 × 28** | Top-right of the page |
| Instance column | **170** | Name + type stacked |
| Character column | **90** | Spec icon **14 × 14**, class-colored name, last check (`18 Aug 23:58`), **Remove** **82 × 16** on non-current characters |
| Header row | **68** | Page-local in `PageCooldowns.lua` (taller: spec icon, name, last check, Remove) |
| Data row | **34** | Alternate fills **0.094 / 0.078** (Classic `CD_ROW_A` / `CD_ROW_B`) |
| Currency rows | **1** fixed | **Currency** / **Валюта** title + label column; ~**175** px tall; aligned icon+count chips |
| Vertical scrollbar | **16** | Right of the table; hidden if unused |
| Horizontal scrollbar | **16** | Bottom of the table; hidden if unused |

## Raid roster tab

Compact two-row header (grade chips + GS/roles + icon toolbar, then flask/food/armor/ench), then scan status + progress bar; roster table or export copy box at a fixed top offset. `LAYOUT_VERSION = 30`.

| Element | Size | Notes |
|---------|------|-------|
| Mini table | full width × **52** | Row 1 **28** + **4** px gap + row 2 **20** |
| Row 1 chips | **≥72** wide | Colored `S · A · B · C · D`; full `GEAR_CHECK_RAID_HINT` on hover |
| Row 1 GS / roles | remaining width | One line; per-role GS on hover |
| Row 1 toolbar | **4×28** icons, **4** px gaps (**124** wide) | Scan, Export all, Refresh, Back to roster (icon + tooltip) |
| Row 2 status | four equal cells, **8** px gaps, **20** tall | Gold name + compact counts, **16×16** Battle Shout report icon on the right |
| Progress status | full width × **28** | **4** px under mini table (two lines) |
| Progress bar | full width × **14** | **4** px under status; always reserved |
| Player cell | **168 × 100** | Five rows: class+name+flask/food, role+spec+GS/iLvl, compact `P:`/`C:` ratings, compact armor+ench grades, **Gear** + **Rescan** + sword/gem report icons. Raid-buff icons moved to hover tip |
| Cell buttons | **16** tall | One row: two **61** px text buttons and two **16 x 16** report icons, **2** px gaps. Gear and reports disabled until scanned; Rescan disabled while any scan/export runs |
| Cell gap | **2** | Between cells and columns |
| Group label | height **16** | Group number (gold) + **3** party-only buff icons (**14** px, 1 px gap): Heroic Presence, Vampiric Embrace, Mana Tide Totem; full color = present in group, red tint = missing; hover shows spell name and provider names |
| Block 1 | **5 × (168 + 2) − 2 = 848** | Parties 1–5 |
| Block 2 | **3 × (168 + 2) − 2 = 508** | Parties 6–8, left-aligned under block 1 |
| Gap between blocks | **12** | |
| Cell content | **20** px class/role/spec; **14** px flask/food | Class on line 1 with flask + food status icons on the right (present = full color, missing = red tint, out of range/offline = dim); role then spec on line 2; one compact rating line (`P:` Qiraji crystal + `C: 75%`) + grades; line height **14**. Raid buffs listed on card hover |
| Cell hover tooltip | — | Opinion, tags, community percent/tags, **Guild: Name (Rank)**, raid buffs, gear-check grades |

Inspect queue runs sequentially; target scan blocked while raid scan is active. Per-player **Rescan** upserts that member’s result without clearing the rest of the raid results. Export builds dumps one player per frame (progress on this page), then opens the in-page export copy box (text view) for Ctrl+C.

## Raid composition tab

Same toolbar as Character cooldowns (`CD_TOOLBAR_H`, 8 px gap). Vertical scrollbar only.

| Element | Size | Notes |
|---------|------|-------|
| Toolbar | hint left; **Report missing** **110 × 28** then **Refresh** **96 × 28** | 4 px gap between buttons |
| Top summary | full width | Roles (left) + Classes (right) on one band |
| Role chip | icon **16** + count, width **34** | Gap **6** px (same as class chips) |
| Class chip | icon **16** + count, width **34** | Gap **6** px; all 10 classes |
| Spec chip | icon **16** + count, **34 x 20** | Up to 3 detected specs stacked under each class; summary grows by **20** px per row (maximum **60** px) |
| Gap under summary | **12** px | Before 3-column checklist |
| Columns | **3** | Equal width; `COMP_COL_GAP` **12** px |
| Section heading | height **20** | Gold `GameFontNormal` |
| Effect row | height **20** | Icon **16** px, name, count width **36** (right-aligned, no wrap) |
| Gap between sections | **10** px | After packing into the shortest column |

## Gear check (target) tab

Full-width description + limitation, then **two columns** (`LEFT_W ≈ innerW − 220 − 10`, right sidebar **220** px). Left: summary (**124** px), five report buttons, five filters, breakdown scroll. Right top band (**176** px): multi-line status, **Scan**, **Character profile**, **Show as a text**, **Select all**; report row starts below the taller of summary vs top band. Lower right: **Save report**, **Delete selected report**, scrollable saved list. Text view replaces main body; top band stays. `LAYOUT_VERSION = 12`.

| Element | Size | Notes |
|---------|------|-------|
| Left column | **~670** px | `innerW − RIGHT_COL_W − COL_GAP` |
| Right column | **220** px | Top band + saved sidebar |
| Summary (left) | height **124** | Top block; report row below `max(124, right top)` |
| Class / spec icons | **18** px | On who line under Overall; tooltips show class / spec names |
| Right top band | height **~144** | Status + 3 stacked buttons |
| Report / filter rows | left width only | Five equal buttons each; report labels include 14 px icons and hover previews of the current chat output |
| Breakdown | left, fills height | Slot groups with verdict color |
| Saved list | right sidebar below delete | Scroll + vertical bar; all entries (not capped) |

Raid-wide gear check is integrated into **Raid roster** (see that section). There is no separate gear-check raid tab.

## Character profile

Popup (`RaidwiseRaidCharacterFrame`), `FULLSCREEN_DIALOG` strata. Opened from Raid roster or History; Esc-close via `UISpecialFrames`. No window scroll — tab panels fill the body below the summary. Layout rebuild gated by `PROFILE_LAYOUT_VERSION` (title-bar badge `vN`).

| Element | Size | Notes |
|---------|------|-------|
| Window | **460 × 560** | Centered, offset +40 / +20 from parent center; **2** px bronze outer border (`UI.BORDER`) |
| Title bar | height **20** | Drag handle; inset **2** px from the outer border; `{name} - Character profile`; layout badge `vN` before close |
| Close button | **16 × 16** | Right of title bar |
| Body padding | **10** | Same as main shell `PAD` |
| Content width | **440** | `460 - 10×2` |
| Header icons | **24** | Race + class in left cell; spec in right cell (`PROFILE_ICON`); column gap **12** |
| Summary | height **122** | Opinion, tags, facts, guild, GUID, realm (+ community column) |
| Profile tabs | height **26** | **History**, **Edit note**, **Facts**, **Events**, **Memo**; gap **4**; **History** opens by default |
| Tab host | fills body below tabs | Panels swap in place |
| Opinion radios | **3** equal columns × **22** | Exclusive Positive / Neutral / Negative |
| Tag checkboxes | scrolling columns by category | Max **3** tags per category; category heading gold |
| Fact checkboxes | two columns under Facts tab | Max **4** facts |
| Event type picker | scroll **140** tall | **16** px category icons + gold headings, then two-column type buttons; **Add event** top-right with heading |
| Event list | fills remaining Events tab | Fixed **20** px rows (**14** px category icon + label + Remove) |
| Memo hint | under heading | `GameFontNormalSmall`; personal-use only (not History) |
| Memo box | **440 × 96** | Multiline EditBox with inner scroll |
| Memo Save / Reset | half width × **28** | `(contentWidth - 8) / 2`; gap **8** |
| History Met / party count | first row of History tab | **Met** left-aligned; **Was in the same party** right-aligned (`meetCount`) |
| History When | below Met | First-meeting timestamp |
| History change log | fills remaining History tab | Scroll; **20** px rows with **14** px icon (event category, or note/tag/facts/memo kind) |
| Community mock block | right summary column | Gold heading + wrapped body text |

Rating editor requires a valid GUID; controls are disabled when GUID is missing. Bottom window **Save and Update** appears on **Edit note** / **Facts** / **Events** and commits those drafts (not memo). Hidden on **History** and **Memo**. Header personal note/tags/facts stay on saved values until that commit. Closing without Save discards drafts.

## History tab

Same toolbar + scroll table as Character cooldowns (`CD_TOOLBAR_H`, `UI.CD_HEADER_H` **52**, `CD_ROW_H`, scrollbars). No averages line.

| Element | Size | Notes |
|---------|------|-------|
| Header row | **52** | `UI.CD_HEADER_H` (single-line column labels) |
| Columns | **90 + 28 + 28 + 70 + 120 + 52 + 44 + 140 + 130 + 120 = 822** | Name, class, spec, Opinion, Tags, GS, iLvl, Met in, When, Guild |
| Class / spec icons | **18** px | Centered in 28 px columns |
| Opinion column | **70**, center | Qiraji crystal icon (green / yellow / red) |
| Tags column | **120** | Colored tag summary (up to 3 labels, then `+N`); `-` when none |
| Met in | **140** | First meeting instance or zone |
| When | **130** | `YYYY-MM-DD HH:MM` |
| Guild | **120** | Last stored `GuildName (Rank)` |

Rows are clickable and open Character profile. Notes are stored on the history record but edited only in Character profile.

## Settings tab

Layout v14 adds Changelog below Unit tooltips: the standard **28** px heading with **20** px section gap, a copy hint, and a URL copy box beside a **130 x 28** px Select all button with the standard **8** px gap.

Theme has its own **28** px category bar below Language, with the standard **20** px section gap. Its **160 x 28** toggle sits **10** px below the heading; Startup page follows the toggle. Light uses warm pale panels and dark text; dark retains the original palette. Choice is saved in `RaidwiseDB.theme`.

Addon labels and text inputs have no text shadow in the light theme. Switching back to dark restores each region's original shadow; shared Blizzard font objects and game tooltips are unchanged.

Language heading, hint, then two **120 × 28** locale buttons (**English**, **Русский**) with an 8 px gap. Selected button uses the same gold fill as the left menu.

Below: **Startup page** heading, hint, then an **4-column** radio group (`UIRadioButtonTemplate`, **16** px, row **22**, 8 px gaps); selected page is stored in `RaidwiseDB.startupTab`.

Report chat channel selection lives in the shared title bar: **406 x 18** px group, eight **42 x 18** px cells spaced **10** px apart. Each right-aligned **24** px label is followed by its **14** px radio with a **2** px gap; the group ends **24** px before Close. Labels: Slf / Say / Prt / Rd / Rdw / Gld / Gof / Aut. The page title is capped at **230** px, with its version immediately after it. The Settings channel section is removed (Settings layout v13; shell layout v15).

The shared header has a **132 x 18** px Short / Full radio group, **16** px before the chat-channel group. Each cell is **62 x 18** px, with **8** px between cells; a **44** px label precedes its **14** px radio by **2** px. Stored in `RaidwiseDB.reportForm`, default `short`; the Settings form section is removed.

Category bars: **28** px high, **16** pt gold text, theme-aware `TITLE_BG` fill, **3** px gold left accent, **10** px text inset; **20** px gap above each subsequent category. Hint/control content uses the same **10** px inset; radio grids use inner width minus **20** px.

Below: **Unit tooltips** category bar and hint, then one shared panel with **10** px padding. Left: **360** px options column with four **24 × 24** checkboxes and **6** px row gaps. Right: remaining width after a **20** px column gap, containing a small **Live tooltip preview** label and compact + stacked samples. Preview text wraps within the right column. Panel height follows sample text height with a **120** px minimum content height plus **20** px padding (`LAYOUT_VERSION = 10`).

## Fonts

| Role | Font object | Color |
|------|-------------|-------|
| Window / menu titles | `GameFontNormal` | Gold `{1.00, 0.82, 0.00}` |
| Menu / action buttons | `GameFontNormalSmall` | Idle `{1.00, 0.93, 0.73}`; hover `{1.00, 0.91, 0.55}`; selected gold |
| Version / status / hints | `GameFontNormalSmall` | Idle text / `TEXT_DISABLED` |
| Checkbox & section labels | `GameFontHighlight` | |
| Info headings | `GameFontNormal` at **16** pt | About / GitHub / feature titles |
| Info body | `GameFontHighlight` at **15** pt | Intro, feature bodies, repo hint |
| Export JSON / profile notes | `ChatFontNormal` | |

## Shared widgets (`UIWidgets.lua`)

Key helpers used across pages (not on `Raidwise` directly):

| Helper | Role |
|--------|------|
| `ApplyPlainPanel` / `HidePanelBorder` | Flat backdrop fill (no border edges) |
| `ApplyOuterBorder` | 2 px bronze edge on a floating window (Character profile) |
| `CreatePlainButton` / `SetPlainButtonState` / `SetMenuButtonState` | Menu and action buttons |
| `ApplyFontSize` | Change a FontString’s point size (keeps face and flags) |
| `CreateCopyBox` / `CreateLineCopyBox` | Export and URL copy areas |
| `SetSpecOrClassIcon` / `SetSpellIconTexture` / `CreateBuffIconHost` / `CreateConsumableStatusHost` | Class, spec, raid-buff, and flask/food status icons |
| `TableIconInset` / `TableIconTopOffset` | Center icons in table rows |
| `AttachLayoutVersionLabel` | Profile title-bar `vN` badge |
| `RatingOpinionIcon` / `RatingOpinionSymbol` / `RatingOpinionColor` / `ShowMemberRatingTooltip` | Opinion display in roster tables |

## Changing sizes

1. Edit the `UI` / theme constants in `UIWidgets.lua`, `ExporterWindow.lua`, or the relevant `Page*.lua`.
2. Bump that view’s `LAYOUT_VERSION` when structure or named frames change.
3. Update this document and [`UI-Views.md`](UI-Views.md) to match (include the new `vN`).
4. Reload the UI (`/reload`) and check `/raidwise` (layout rebuild should also fire when versions mismatch).

Header report controls are contextual: chat channels appear only on Raid roster, Raid composition, and Gear check (target); Short / Full appears only on Gear check (target), whose output uses that setting. Both groups are hidden on all other views. Switching views preserves saved selections.
