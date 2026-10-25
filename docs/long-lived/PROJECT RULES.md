# Project Rules

# Bible Project

Version: 1.0

---

# Purpose

This document defines the engineering standards, architectural principles, coding conventions, and project-wide rules for the Bible Project.

Every contributor should follow these rules to maintain consistency, scalability, and code quality.

---

# 1. Core Philosophy

The project is guided by the following principles:

- Offline First
- Simple over Clever
- Readability over Brevity
- Performance over Excessive Abstraction
- User Data Belongs to the User
- Modular Design
- Long-Term Maintainability

Every architectural decision should reinforce these principles.

---

# 2. Flutter Guidelines

## Preferred Language Features

Use:

- null safety
- immutable data where possible
- const constructors
- enums instead of magic strings
- extension methods where appropriate

Avoid:

- global mutable variables
- singleton abuse
- unnecessary inheritance
- dynamic unless absolutely required

---

# 3. Folder Structure

Every feature follows the same layout.

```
feature/

    data/
        datasource/
        models/
        repositories/

    domain/
        entities/
        repositories/
        usecases/

    presentation/
        pages/
        widgets/
        controllers/

```

Feature code must never leak into another feature.

Shared code belongs inside `/core`.

---

# 4. Naming Conventions

Classes

```
BibleRepository
TranslationImporter
ReadingPosition
```

Widgets

```
BiblePage
ReaderScreen
HighlightTile
```

Files

```
bible_repository.dart
reader_screen.dart
highlight_tile.dart
```

Variables

```
currentBook
selectedTranslation
fontSize
```

Booleans

```
isLoading
hasInternet
isSynced
```

---

# 5. State Management

The project should use a single state management solution.

Business logic must never live inside widgets.

Widgets should only:

- display data
- collect user input
- trigger actions

---

# 6. Separation of Responsibilities

Widgets

Responsible for presentation only.

Controllers/ViewModels

Responsible for UI logic.

Repositories

Responsible for retrieving and storing data.

Use Cases

Responsible for business rules.

Services

Responsible for external interactions.

---

# 7. Database Rules

The local database is the source of truth.

Cloud synchronization should never bypass local storage.

Correct flow:

```
User Action

↓

Local Database

↓

UI Update

↓

Cloud Sync
```

Never:

```
User Action

↓

Cloud

↓

Local
```

---

# 8. Sync Rules

Synchronization must:

- happen in the background
- retry failed uploads
- never block reading
- tolerate offline operation

Conflicts:

Initial strategy:

Last Write Wins

Future improvements may introduce merge logic.

---

# 9. Translation Rules

Bible translations are treated as datasets.

They must:

- be importable
- be removable
- be cached locally
- be synchronized across devices

The application must support multiple parser implementations.

Never hardcode support for a single format.

---

# 10. UI Rules

The interface should be:

- minimal
- fast
- readable
- distraction-free

Avoid:

- unnecessary animations
- excessive gradients
- decorative effects
- cluttered screens

Typography is more important than decoration.

---

# 11. Performance Rules

Reading a chapter should feel instantaneous.

Guidelines:

- lazy loading where appropriate
- pagination when required
- avoid rebuilding entire widget trees
- cache expensive operations

---

# 12. Error Handling

Every recoverable error must:

- be logged
- show useful feedback
- allow retry

Never silently ignore errors.

Never crash because of:

- missing translation
- network timeout
- failed synchronization

---

# 13. Logging

Development builds

Verbose logging allowed.

Production builds

Minimal logging.

Sensitive user information must never be logged.

---

# 14. Security

Always use:

- HTTPS
- Supabase Row-Level Security
- authenticated requests

Never expose:

- API keys
- service role keys
- private credentials

---

# 15. Accessibility

Support:

- large fonts
- dark mode
- high contrast where possible
- keyboard navigation on desktop

Text readability is the highest priority.

---

# 16. Dependencies

Before adding a package ask:

1. Is Flutter already capable?

2. Can this be implemented simply?

3. Is the dependency actively maintained?

4. Does it increase build size?

Avoid unnecessary dependencies.

---

# 17. Code Review Checklist

Every feature should satisfy:

✓ Compiles

✓ Tested

✓ Offline compatible

✓ Responsive

✓ No duplicated logic

✓ Uses existing architecture

✓ Proper naming

✓ Documentation added

---

# 18. Git Rules

Branches

```
main

develop

feature/reader

feature/search

feature/sync

bugfix/import

```

Commit examples

```
feat: add translation importer

fix: resolve bookmark sync issue

refactor: simplify repository layer

docs: update architecture

```

---

# 19. Documentation

Every module should contain:

- purpose
- responsibilities
- public API
- known limitations

Complex algorithms require comments.

Simple code should explain itself.

---

# 20. Future Expansion

Future features should integrate without changing existing modules.

Examples

- Reading Plans

- Audio Bible

- Plugins

- Cross References

- Study Tools

- AI-assisted search

Architecture should encourage extension—not modification.

---

# 21. Definition of Done

A feature is complete when:

- functionality works
- tests pass
- documentation updated
- offline support verified
- sync verified
- responsive layouts verified
- no known critical bugs remain

---

# Final Principle

Every line of code should make the application:

- simpler
- faster
- easier to maintain
- more reliable

Never sacrifice long-term quality for short-term speed.

---