# CONTEXT

> Rewrite this file at the start of every work session. It is the AI's "what am I doing right now."
> Keep it under ~40 lines — it goes into every model prompt.

## Current objective

Start Phase 3 — Study Tools: wire up the verse context-menu actions (Highlight / Bookmark / Note / Copy) so they persist to the local Drift DB.

## Files I expect to touch

- `lib/features/bible/presentation/pages/reader_page_mobile.dart` (TODO stubs at ~535–547)
- `lib/features/bible/presentation/pages/reader_page_desktop.dart`
- `lib/database/app_database.dart` (DAO methods already exist — insertNote/insertHighlight/insertBookmark)
- possibly a new `lib/features/bible/domain/` provider for verse actions

## Known issues / constraints

- Reading position not persisted — reader always opens Genesis 1:1 (separate task, don't fix here).
- Sync is disabled; everything is local-only for now. Do NOT wire SyncService.
- Highlight color is a plain string (e.g. `'yellow'`).
- All state via Riverpod Notifier API — no StateProvider, no setState for shared state.

## Expected outcome

- Long-press / context menu on a verse → Highlight (pick color), Bookmark (optional label), Note (text dialog), Copy (formatted "Book C:V — text").
- Rows appear in Drift tables; highlights render in the reader after restart.
- `flutter analyze` clean.

---

### Session log (newest first)

- 2026-07-16 — Created AI-memory docs (GLOSSARY, DECISIONS, API, CONTEXT); reworked LocalAIUsageGuide for the 1050 Ti.
- 2026-07-15 — Scripture formatting: HTML normalization, red-letter sentinels, reader flicker fix, cross-verse selection.
- 2026-07-14 — v0.2.1: multi-file import hotfix; first successful translation import + offline reading.
