# Planned Features

**Status:** In progress — §1, §2, §3, §4 done.
**Updated:** 2026-07-20

This document captures every planned feature and fix agreed upon in the design session of 2026-07-18.
Items are numbered for reference. Each section describes *what* the feature is, *why* it exists, and *how* it should behave. Implementation details (files, providers, widgets) are left for a separate plan doc.

> **Addition (2026-07-18):** cross-session **reading-position persistence** was implemented alongside §2 — the reader reopens at the last centered translation + book + chapter (SharedPreferences keys `reading_position.*` via `StorageService`, `readingPositionProvider` in `database_provider.dart`). Switching translations via the §2 pill updates only the translation component of the persisted key; book/chapter are preserved.

---

## 1. Chapter Indicator — Unification & Scroll Accuracy ✅ Done

### Problem

There are currently two separate chapter indicators visible in the reader:

1. The interactive indicator (used to change the chapter via tap/picker).
2. A scroll-tracking indicator (updates as new chapters are loaded into the lazy list).

These must be the same element. The scroll-tracking indicator moves independently of the interactive one, which is confusing.

Additionally, the scroll-tracking logic is updating the indicator based on which chapters are *loaded* in memory, not which chapter is *visually centered on screen*. This causes the indicator to jump ahead far too early.

### Expected Behaviour

- There is **one** chapter indicator. It is both interactive (tap to change chapter) and scroll-aware (updates as the user reads).
- The indicator updates to chapter N **only when chapter N's header crosses into the visible middle region of the screen** (i.e., the chapter is what the user is actively reading, not just prefetched).
- Chapters before and after the visible chapter may still be loaded and resident in memory — that is fine and desirable for smooth scrolling. The indicator does not track load state; it tracks **visible state**.
- Scrolling up into a previous chapter causes the indicator to move back to that chapter's number.

### Design Notes

- A `visibleChapterNotifier` (or equivalent) should be maintained separately from `currentChapterProvider`. `currentChapterProvider` reflects navigation intent; `visibleChapterNotifier` reflects what the user sees.
- The chapter indicator widget reads from `visibleChapterNotifier` for its display label, but writes to `currentChapterProvider` when the user taps to navigate.
- The scroll listener should use item key positions / `ScrollController` offsets mapped against chapter boundary keys to determine the topmost fully-visible chapter header.

---

## 2. Translation Pill — Grid Dropdown ✅ Done

### Feature

A pill-shaped button in the **top-right of the reader header** displays the abbreviation of the currently active translation (e.g., `KJV`, `NIV`, `NLT`).

Tapping the pill opens a **dropdown that is a grid**, not a list. The grid contains all currently installed translations.

### Layout & Behaviour
 
- The pill shows the short code of the active translation (e.g. `KJV`).
- Tapping the pill opens the grid dropdown, anchored below-left of the pill.
- The grid is a **box** (not a scrolling list). Each cell shows:
  - Translation abbreviation (large, bold)
  - Full name (small, secondary)
- The grid adapts its column count to fit content — it is not a fixed 2- or 3-column grid. Use `Wrap` or an adaptive grid so cells are sized to content and the overall box grows/shrinks accordingly.
- The currently active translation is highlighted within the grid.
- Tapping a cell activates that translation and closes the dropdown.
- If there is only one installed translation, the pill is still present but tapping it opens an empty/single-item grid with a prompt to install more.
- The dropdown closes on tap-outside.

### Accessibility

- The pill has a semantic label: "Active translation: [name]. Tap to switch."
- Each grid cell is individually focusable.

---

## 3. Chapter / Book Dropdown — Current Item Highlight & Positioning ✅ Done

### Problem

When the user opens the chapter or book picker dropdown, the dropdown currently **covers the very item that was tapped** to open it. This obscures context and feels disorienting.

### Expected Behaviour

- The dropdown opens **adjacent to** (not on top of) the tapped indicator.
- The **currently selected chapter / book is visually highlighted** inside the dropdown (distinct background or border) so the user can immediately see where they are before navigating.
- The highlight should be consistent with the design system's selection/active state styles.

### Notes

- On mobile, the dropdown may open as a bottom sheet rather than an inline dropdown — the highlight requirement applies to both.
- The entry animation should not obscure the tapped element during its open sequence.

---

## 4. Collapsible Sidebar (Desktop) ✅ Done

### Feature

The desktop sidebar (navigation rail) can be collapsed. When collapsed, it shows **only the icons** — no labels, no expanded state. Icons remain fully tappable in the collapsed state.

### Behaviour

- A **toggle icon** (e.g., a chevron or hamburger) is present in the sidebar header area. Tapping it collapses or expands the sidebar.
- **Expanded state:** icons + labels, standard rail width.
- **Collapsed state:** icons only, narrow width (sufficient for icon + padding). Labels are hidden. Tooltips appear on hover to compensate for missing labels.
- The collapsed/expanded preference is persisted across sessions (local settings).
- The main content area expands to fill the space freed by collapsing.
- No animation is required in v1, but a width transition is acceptable.

### Notes

- The toggle icon itself must remain visible in both states.
- This replaces/updates the "Optional Collapsible Sidebar" note in `SCREEN MAP.md`.

---

## 5. Verse Selection Action Panel

### Feature

When the user **selects one or more verses** (non-contiguous selection is supported — e.g., Gen 1:3, Gen 1:7, Gen 1:20 can all be selected at once), an **action panel** appears. On mobile this is a bottom sheet or floating toolbar; on desktop this is a floating toolbar or a panel near the selection.

### Contents

The panel contains the following actions, in order:

#### Highlight Colors (row)

Four slots:

| Slot | Contents |
|------|----------|
| 1 | Color swatch — Color A |
| 2 | Color swatch — Color B |
| 3 | Color swatch — Color C |
| 4 | Multi-color swatch (rainbow/gradient icon) — opens a **full color picker** for a custom highlight color |

The first three colors are the three primary highlight presets defined in the design system. The fourth slot always opens a color picker dialog; it does not represent a fixed color.

**Divider**

#### Actions (row or list)

| Icon | Label | Action |
|------|-------|--------|
| Bookmark | Save | Bookmarks the selected verse(s) |
| Pencil | Note | Opens the Add Note sheet for the selection |
| Copy | Copy | Copies the verse text(s) to clipboard (with reference) |
| Share | Share | Opens the system share sheet with verse text + reference |

**Divider**

| Icon | Label | Action |
|------|-------|--------|
| Columns | Compare | Opens the Compare Panel (see §6) |

### Selection Behaviour

- Selected verses are visually marked (background highlight or border).
- Deselecting all verses (tap outside / close panel) dismisses the panel and clears the selection.
- Non-contiguous selections are fully supported: the user can tap individual verses to add/remove them from the current selection set.

---

## 6. Compare Panel

### Feature

Triggered by the **Compare** action in the Verse Selection Panel (§5). Opens a side-by-side split view: the existing reader on the left with the selected verse(s) still highlighted, and a **comparison column** on the right.

### Comparison Column Layout

The comparison column shows the selected verse(s) in every **installed translation**, stacked vertically:

```
KJV → King James Version
[verse text in KJV]
────────────────────────
NIV → New International Version
[verse text in NIV]
────────────────────────
NLT → New Living Translation
[verse text in NLT]
────────────────────────
… (all installed translations)
```

- The translation abbreviation and full name appear as a small header above each block.
- A horizontal rule separates each translation block.
- Non-contiguous selected verses are all shown within each translation block (each verse on its own line with its reference).

### Layout

- **Desktop:** The reader splits horizontally. The left pane is the normal reader (≈60% width), the right pane is the comparison column (≈40% width). A drag handle between panes is optional (v2).
- **Mobile:** The comparison column opens as a **modal bottom sheet** that covers roughly the bottom 60% of the screen. The reader remains visible (dimmed) in the top portion so the selected verse is still in context.
- A close button (×) dismisses the compare panel. The selection remains active until the user explicitly deselects.

### Notes

- Only installed translations appear in the comparison. If only one translation is installed, the panel still opens but shows a prompt to install more.
- The comparison column is read-only (no interaction beyond scrolling).

---

## 7. Search Icon in Reader Header

### Feature

A **search icon button** is added to the reader's top app bar / header, alongside the existing controls.

### Behaviour

- Tapping the search icon navigates to (or opens) the Search screen.
- On desktop, it may open the search panel inline if a side-panel architecture is in place; otherwise it navigates.
- The icon placement follows the existing header layout and does not crowd other controls.

### Notes

- This is consistent with the Search entry point already present in the sidebar/rail. The header icon is a secondary shortcut, not a replacement.
- The search icon should be present on **both mobile and desktop** layouts.

---

## Implementation Order (suggested, not binding)

The following order minimises rework:

1. **§1 — Chapter indicator unification + scroll accuracy** (fixes existing regression first)
2. **§3 — Chapter/book dropdown positioning + highlight** (low scope, high polish payoff)
3. **§4 — Collapsible sidebar** (desktop layout foundation — other panels depend on knowing available space)
4. **§7 — Search icon in header** (trivial addition, unblocks nothing)
5. **§2 — Translation pill grid dropdown** (self-contained new widget)
6. **§5 — Verse selection action panel** (new interaction model; needed before §6)
7. **§6 — Compare panel** (depends on §5 for selection state)

---

## Open Questions

| # | Question | Needs decision from |
|---|----------|---------------------|
| Q1 | What are the three preset highlight colors? | Design system / owner | -> R, G, B
| Q2 | On mobile, does the verse selection panel appear as a bottom sheet or a floating bar above the keyboard? | Owner | -> bottom sheet
| Q3 | Should the compare panel's translation order be alphabetical, or match a user-defined order? | Owner | -> alphabetical
| Q4 | Should the sidebar collapsed state be per-window or global? | Owner | -> global
| Q5 | On mobile, is the translation pill visible at all times, or only when the header is expanded? | Owner | -> All times

---
