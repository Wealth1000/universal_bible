# UI_OVERHAUL.md — the design authority for the 2026-07 UI overhaul

**Status:** ACTIVE — while this overhaul is in progress, this document supersedes
DESIGN SYSTEM.md / SCREEN MAP.md / UI_UX.md wherever they disagree. When the
overhaul completes, final decisions here get backfilled into those docs.
**Direction chosen by owner:** "Calm study" — warm paper-like reading surfaces,
deep ink accents, serif-forward, generous whitespace. The UI recedes; scripture
is the object. Dark mode is warm charcoal, never pure black.
**Scope:** every desktop screen + shell + shared widgets. Mobile files only kept
compiling (mobile paused per DECISIONS.md).

---

## 1. Principles

1. **Paper, not panels.** The reading surface is a warm off-white sheet; chrome
   sits on slightly cooler/darker surfaces so the page visually lifts.
2. **Ink, not color.** One deep ink accent (the existing #2E434C family,
   promoted from ad-hoc override to real token). Color is reserved for meaning:
   red-letter text, highlight swatches, destructive actions.
3. **Serif reads, sans works.** Literata for scripture AND display headings;
   Inter for all functional UI (labels, buttons, metadata, nav). JetBrains Mono
   stays bundled but unused (future: verse ids / debug).
4. **Whitespace is the layout.** Fewer borders, more spacing. Dividers only
   where scanning needs them (lists, compare blocks).
5. **No decorative motion.** Transitions 150–250 ms, state-communicating only.

---

## 2. Design tokens → `lib/core/design/app_tokens.dart` (NEW)

One file, plain `abstract final class` constant holders. Everything below is
the single source; screens must not hardcode colors/sizes/spacings anymore.

### 2.1 Color — light ("paper")

| Token | Value | Use |
|---|---|---|
| `inkPrimary` | `#2E434C` | primary actions, active states, headings accent |
| `inkPrimaryHover` | `#3D5563` | hover/pressed derivative |
| `paper` | `#FAF7F2` | reading/scaffold background (warm off-white) |
| `paperElevated` | `#FFFFFF` | cards, dialogs, panels |
| `chromeSurface` | `#F1EDE6` | rail, top bar, side panels (cooler than paper → page lifts) |
| `inkText` | `#2A2A26` | primary text (warm near-black) |
| `inkTextSecondary` | `#6B675F` | secondary text, metadata |
| `hairline` | `#E2DDD3` | dividers, borders |
| `selectionWash` | `#EFE9DB` | tap-selected verse background (warm parchment, replaces #FFFDE7) |
| `wordsOfChrist` | `#A63A2E` | red-letter (brick red, warmer than #B71C1C) |
| `danger` | `#B3432E` | destructive actions |
| `success` | `#4E6E58` | success snackbars (muted moss) |

### 2.2 Color — dark ("lamplight")

| Token | Value | Use |
|---|---|---|
| `inkPrimary` | `#9FB4BF` | primary accent on dark |
| `paper` | `#211F1C` | reading background (warm charcoal, NOT #121212 cold black) |
| `paperElevated` | `#2A2724` | cards, dialogs |
| `chromeSurface` | `#1B1917` | rail, top bar |
| `inkText` | `#E8E3DA` | primary text (warm off-white) |
| `inkTextSecondary` | `#9C968A` | secondary text |
| `hairline` | `#3A3630` | dividers |
| `selectionWash` | `#3B3628` | tap-selected verse background |
| `wordsOfChrist` | `#D9836F` | red-letter on dark |
| `danger` | `#D9776A` | destructive |
| `success` | `#8FAE97` | success |

Highlight presets (§5 R/G/B + custom) are UNCHANGED — user data references
them; they read fine on both palettes at 0x66/0.4 alpha.

### 2.3 Typography

| Token | Font | Size | Weight | Use |
|---|---|---|---|---|
| `display` | Literata | 34 | 700 | chapter-header book name |
| `title` | Literata | 22 | 600 | page titles (AppBars) |
| `scripture` | Literata | user setting (default 18) | 400, height 1.7 | verse text (height raised 1.6→1.7) |
| `scriptureRef` | Inter | 12 | 600, letterSpacing 0.4 | verse references, "Chapter N" |
| `uiLabel` | Inter | 14 | 500 | buttons, list titles, form labels |
| `uiBody` | Inter | 13 | 400 | descriptions, secondary content |
| `caption` | Inter | 11 | 500, letterSpacing 0.3 | metadata, counts, dates, rail labels |

Implementation: set `fontFamily: 'Inter'` app-wide in ThemeData; scripture and
display styles explicitly opt into Literata. (Today it's inverted — Literata is
the app default — which is why UI chrome looks bookish-by-accident.)

### 2.4 Spacing / radius / elevation

- Spacing scale (constants `space4 … space64`): 4, 8, 12, 16, 24, 32, 48, 64.
- Radius: `radiusSmall 6` (inputs, cells), `radiusMedium 10` (cards, panels),
  `radiusLarge 16` (floating panel, dialogs), `radiusFull` (pills).
- Elevation: 0 for everything resting; shadow only on floating surfaces
  (action panel, dialogs, dropdown overlays) — soft, large-blur, low-alpha.
- Reader column: FULL WIDTH (owner decision 2026-07-21 — no max-width
  measure; scripture spans the space available), horizontal padding 32.
- Content pages (search/bookmarks/notes/settings): max width 720, padding 24.

### 2.5 Theme plumbing

`app_theme.dart` rebuilt to construct `ColorScheme`s explicitly from tokens
(no more `fromSeed`): primary=inkPrimary, surface=paper,
surfaceContainerLowest=paperElevated, surfaceContainerLow=chromeSurface,
outlineVariant=hairline, onSurface=inkText, onSurfaceVariant=inkTextSecondary,
error=danger. Also: `textTheme` from §2.3, `dividerTheme` (hairline, 1px),
`snackBarTheme` (floating, paperElevated, inkText), input/button themes.
Screens keep reading `colorScheme.*` — most stop needing literals at all.
Delete the duplicate theme provider (`core/themes/theme_provider.dart` vs
`core/providers/theme_provider.dart` — keep the one currently imported by
main/settings, port anything missing). This debt item graduates from
"deferred" because the overhaul touches exactly these files.

---

## 3. Screen-by-screen specification

### 3.1 App shell (`core/shell/app_shell.dart`)
- Rail on `chromeSurface`, NO border — the paper/chrome color shift is the
  separation. Right hairline removed.
- Rail items: icon + `caption` label (Inter). Active: pill-shaped indicator in
  `inkPrimary` at 12% alpha, icon+label in `inkPrimary`. Inactive:
  `inkTextSecondary`.
- Logo area unchanged; collapse chevron becomes subtle (`inkTextSecondary`).
- Collapsed width 56 / expanded 84 (unchanged behavior, restyled only).
- "Coming soon" snackbar path is dead (all items route now) — leave mechanism.

### 3.2 Reader (`reader_page_desktop.dart`) — the flagship
- **Top bar**: on `chromeSurface`, height 56 (was 64), no bottom border. Book +
  chapter selectors become quiet text buttons (`uiLabel`, inkText) with a small
  chevron; hover = `selectionWash`. Search icon `inkTextSecondary`. Translation
  pill: outlined (1px hairline), `radiusFull`, `scriptureRef` styling, active
  translation abbreviation in `inkPrimary` — no filled container.
- **Chapter header**: book name in `display` (Literata 34/700, `inkText` — no
  longer primary-colored), then an em-dash-flanked "Chapter N" in
  `scriptureRef` caps style, `inkTextSecondary`. 64 above / 48 below.
- **Verse tiles**: scripture token (Literata, height 1.7). Verse number column:
  `scriptureRef`, `inkTextSecondary` at 60%, width 40. Selected verse:
  `selectionWash` + 2px `inkPrimary` left accent bar (replaces full-tile
  yellow); selected+highlighted keeps highlight color + the accent bar
  (replaces colored border). Highlight-only: highlight color fill as today.
  Radius `radiusSmall`.
- **Prev/next buttons**: quiet text buttons, `uiLabel`, hairline border,
  `radiusFull` — visually lighter than today.
- **Action panel** (`verse_action_panel.dart`): `paperElevated`, `radiusLarge`,
  soft shadow; icons `inkTextSecondary` with `inkPrimary` hover; swatches get a
  hairline ring. Structure/actions unchanged.
- **Compare split**: divider = 1px hairline; pane background `chromeSurface`
  so it reads as chrome next to the paper reader.

### 3.3 Compare column + full-screen page
- Block headers: abbreviation in `scriptureRef` caps `inkPrimary`, full name in
  `uiBody` `inkTextSecondary` (drop the "→" glyph — plain spacing).
- Verse text: scripture token at 15. References: `scriptureRef`.
- Full-screen page: paper background, reader-column width (680), title in
  `title` token.

### 3.4 Search
- Search field: `paperElevated` fill, hairline border, `radiusMedium`, Inter;
  no heavy Material underline. Results: reference in `scriptureRef`
  `inkPrimary`; verse text scripture-at-14 with matches in 700 weight
  `inkPrimary`; hairline separators; hover `selectionWash`. Footer count in
  `caption`.

### 3.5 Bookmarks
- Rows: bookmark icon `inkPrimary`, reference `uiLabel` 600, preview
  scripture-at-13 `inkTextSecondary` 2-line ellipsis; delete icon
  `inkTextSecondary` → `danger` on hover. Hairline separators, hover wash.
- Empty state: outline icon + `uiBody` copy (both `inkTextSecondary`).

### 3.6 Notes
- Cards: `paperElevated`, hairline border, `radiusMedium`, padding 16.
  Reference `scriptureRef` `inkPrimary`; date `caption`; content `uiBody` at
  14/1.5. Edit/delete icons quiet until hover.

### 3.7 Settings
- Section headers: `caption` caps `inkTextSecondary`. Cards: `paperElevated`,
  hairline, `radiusMedium`. Tile icons `inkTextSecondary` (drop
  `colorScheme.secondary` tint). Theme segmented control: `chromeSurface`
  track, `inkPrimary` active segment. Sliders/switches: `inkPrimary` active.
  Decorative verse footer stays (it's on-brand) restyled in scripture italic.

### 3.8 Translation manager
- List rows like bookmarks (title `uiLabel`, meta `caption`); active
  translation gets `inkPrimary` check + wash background. Import FAB →
  `inkPrimary`. Snackbars: success/`success`, error/`danger` via theme —
  remove `Colors.green/orange/red`.

### 3.9 Welcome
- Paper background, logo, app name in `display`, tagline in `uiBody`
  `inkTextSecondary`. Primary CTA: filled `inkPrimary`, `radiusFull`, Inter
  600. Secondary CTA: hairline outline. Version `caption`.
- Login page: leave placeholder (auth deferred), just recolor to tokens if
  trivially cheap.

### 3.10 Mobile pages
- NOT restyled. Only fix compile breaks from shared-token renames.

---

## 4. Execution order (batches)

1. **Tokens + theme**: `app_tokens.dart`, rebuild `app_theme.dart`, dedupe
   theme provider, retarget `scripture_format.dart` red-letter to tokens.
2. **Shell + reader**: app_shell, reader top bar/chapter header/verse tiles/
   nav buttons, action panel, selection treatment.
3. **Reading satellites**: compare column, compare page, translation grid.
4. **Content pages**: search, bookmarks, notes.
5. **Peripheral**: settings, translation manager, welcome.
6. **Docs backfill**: fold final values into DESIGN SYSTEM.md; mark this doc
   COMPLETED; work log + CHANGELOG; update DECISIONS.md (incl. theme-provider
   dedupe leaving the debt list).

Each batch ends analyze-clean (owner runs it) before the next.

## 5. Verification

Per batch: `flutter analyze` (owner) + visual pass on Linux in light AND dark.
Full-app check at the end: every screen visited in both themes; §5/§6 flows
re-run (selection, highlights render over new selection treatment, compare
split, full-screen compare); settings live-update still works; welcome page
(temporarily clear translations or route directly) renders.
