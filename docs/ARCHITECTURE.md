# Architecture

# Bible Project

Version: 1.0

---

# 1. Overview

Bible Project follows a clean, modular, offline-first architecture.

The application is divided into independent feature modules communicating through
well-defined interfaces. This keeps the project maintainable as it grows while
making it easy to add new features without affecting existing ones.

The guiding philosophy is:

> Local First → Sync Later

Reading the Bible should never depend on an internet connection.

---

# 2. High-Level Architecture

                    ┌────────────────────┐
                    │       Flutter      │
                    │        UI          │
                    └─────────┬──────────┘
                              │
                    Presentation Layer
                              │
                    ┌─────────▼──────────┐
                    │   State Management │
                    └─────────┬──────────┘
                              │
                     Domain / Business Layer
                              │
              ┌───────────────┼────────────────┐
              │               │                │
              ▼               ▼                ▼
        Bible Module     Notes Module    Sync Module
              │               │                │
              └───────────────┼────────────────┘
                              │
                     Repository Layer
                              │
              ┌───────────────┼────────────────┐
              ▼                                ▼
       Local Database                  Supabase Backend

---

# 3. Layers

## Presentation Layer

Responsible for:

- Screens
- Widgets
- Navigation
- User interaction
- Themes

The presentation layer should contain no business logic.

---

## State Layer

Responsible for:

- UI state
- Loading states
- Cached screen state
- User selections

Examples

- Current translation
- Current chapter
- Selected theme
- Current font size

---

## Domain Layer

Contains application rules.

Examples:

- Import Translation
- Create Highlight
- Save Bookmark
- Synchronize User
- Search Bible

This layer should not know how data is stored.

---

## Repository Layer

Acts as the bridge between the application and data sources.

Repositories decide whether data comes from:

- Local storage
- Remote storage
- Cached data

Repositories hide implementation details.

---

## Data Layer

Responsible for:

- SQLite
- Local files
- Supabase
- File imports

---

# 4. Feature Modules

The application is organized around features.

lib/

    core/
    features/
        auth/
        bible/
        bookmarks/
        highlights/
        notes/
        settings/
        search/
        sync/

Each feature owns:

- models
- repositories
- services
- UI
- state
- business logic

---

# 5. Core Module

Contains shared functionality.

Examples

core/

    constants/
    exceptions/
    extensions/
    services/
    widgets/
    themes/
    utils/

Nothing inside "features" should duplicate code from "core".

---

# 6. Bible Module

Responsibilities

- Read Bible
- Navigate books
- Navigate chapters
- Navigate verses
- Translation switching

Owns

- Bible models
- Bible repository
- Bible controllers
- Bible UI

---

# 7. Translation Module

Responsible for:

- Importing translations
- Downloading translations
- Updating translations
- Removing translations

Supported input formats should be expandable through adapters.

Importer

        File
          │
          ▼
    Format Detector
          │
          ▼
       Parser
          │
          ▼
    Internal Model
          │
          ▼
      Local Storage

Future translation formats require only a new parser.

---

# 8. Notes Module

Responsibilities

- Create notes
- Edit notes
- Delete notes
- Sync notes

Notes are attached to:

Book

Chapter

Verse

Future:

Verse ranges

---

# 9. Highlights Module

Responsibilities

Highlight verses.

Future:

Multiple highlight colors.

Future:

Highlight categories.

---

# 10. Bookmark Module

Simple module responsible for:

- Saving bookmarks
- Organizing bookmarks
- Removing bookmarks

---

# 11. Search Module

Provides

- Verse search
- Book search
- Keyword search

Future

Cross-translation search.

Search should be fully local.

---

# 12. Settings Module

Stores

Theme

Font size

Reading preferences

Sync preferences

Downloads

---

# 13. Authentication Module

Supabase Authentication

Stores

- User profile
- Session
- Authentication state

Authentication exists only for synchronization.

---

# 14. Sync Module

The Sync Module coordinates all cloud communication.

It should know nothing about the UI.

Responsibilities

Upload

Download

Conflict resolution

Retry queue

Offline queue

---

# 15. Local Storage

The application maintains a complete local copy of:

Bible translations

Highlights

Bookmarks

Notes

Settings

Reading position

The application should never require the internet to function.

---

# 16. Cloud Storage

Supabase stores

User profile

Notes

Bookmarks

Highlights

Reading position

Translation metadata

Translation files (Storage Bucket)

---

# 17. Sync Strategy

Every write operation follows:

User Action

↓

Write Local Database

↓

Update UI

↓

Queue Sync

↓

Background Upload

This keeps the interface responsive.

---

# 18. Error Handling

Errors should never crash the application.

Possible errors

Missing translation

Network unavailable

Authentication expired

Corrupted translation

Every error should produce:

- useful logs
- recoverable state
- meaningful user feedback

---

# 19. Dependency Direction

Presentation

↓

Domain

↓

Repository

↓

Storage

Never the reverse.

Lower layers must never depend on UI.

---

# 20. Scalability

Future modules should plug into the existing architecture without major refactoring.

Examples

Reading plans

Cross references

Devotionals

Audio Bible

Plugins

Community features

---

# 21. Guiding Principles

- Offline First
- Feature-Based Architecture
- Separation of Concerns
- Composition over Inheritance
- Minimal Dependencies
- Fast Startup
- Predictable State
- Modular Expansion

---

# 22. Technology Stack

Frontend

- Flutter

Backend

- Supabase

Database

- SQLite (local)
- PostgreSQL (Supabase)

Storage

- Local filesystem
- Supabase Storage

Authentication

- Supabase Auth

Target Platforms

- Linux
- Windows
- Android

Future

- macOS
- iOS
- Web
