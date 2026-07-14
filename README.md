# Universal Bible

A lightweight, cross-platform, **offline-first** Bible application built with Flutter. Designed for personal use with structured cloud synchronization of translations and study data via Supabase.

This project prioritizes **clarity**, **performance**, and **long-term maintainability** over feature bloat.

---

## Table of Contents

- [Vision](#-vision)
- [Platform & Tech Stack](#-platform--tech-stack)
- [Core Features](#-core-features)
- [Translation Sync Model](#-translation-sync-model)
- [Devotional Integration](#-devotional-integration)
- [Personal Study Tools](#-personal-study-tools)
- [Synchronization Model](#-synchronization-model)
- [Offline-First Design](#-offline-first-design)
- [Backend Overview (Supabase)](#-backend-overview-supabase)
- [Design Principles](#-design-principles)
- [Project Structure](#-conceptual-project-structure)
- [Development Phases](#-development-phases)
- [Long-Term Roadmap](#-long-term-roadmap)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Status & Next Steps](#-status--next-steps)
- [License](#-license)

---

## ✨ Vision

To build a clean, modern Bible application that:

- **Works fully offline** — no reading dependency on live network access
- **Supports flexible Bible translation imports** — multiple formats, local + synced
- **Syncs translations and personal data across devices** — via Supabase
- **Integrates structured monthly devotionals** — predictable, offline-friendly
- **Remains lightweight and focused** — personal productivity, not a commercial platform

---

## 🛠 Platform & Tech Stack

### Frontend

| Area        | Choice                          |
| ----------- | ------------------------------- |
| **Framework** | Flutter                         |
| **Targets**  | Linux, Windows, Android        |
| **Future**   | macOS, Web (optional)          |

### Backend

| Area        | Choice                          |
| ----------- | ------------------------------- |
| **BaaS**    | Supabase                        |
| **Database**| PostgreSQL                      |
| **Auth**    | Supabase Authentication         |
| **Storage** | Per-user data + Storage buckets (e.g. translation files) |

---

## 📖 Core Features

### 1. Bible Reader

- Multiple translation support
- Downloadable / importable translations
- Multiple file formats (e.g. JSON, XML, structured text, **SQLite / .sqlite3**)
- Fast verse navigation
- Clean, distraction-free reading layout

Translations are **structured datasets** that:

- Can be imported locally
- Are stored offline
- **Are synced across devices via Supabase**
- Can be re-downloaded on new devices automatically

---

## 🌐 Translation Sync Model

Translations are **logically user-owned assets**, but the imported translation files themselves live in a **central shared storage bucket**. This keeps things simple for this personal, single-user setup while making reuse across accounts/devices trivial.

### How It Works

1. User imports or downloads a translation.
2. Translation **metadata** is registered in Supabase (e.g. id, language, source, checksum).
3. The translation **file** is uploaded to a **central Supabase Storage bucket** (if not already present).
4. Other devices or accounts (within this personal environment) linked to the same Supabase project:
   - Fetch translation metadata
   - Download the translation file automatically
   - Store it locally

### Goals

- No need to re-import translations on every device
- Offline availability after first download
- Efficient storage and caching
- Minimal redundant uploads

---

## 📘 Devotional Integration

### Monthly Devotional Model

- **Full monthly devotional books** are downloaded (not daily sync).
- Stored locally; browsable by date or month.
- Optional pre-download of future months.

**Benefits:** reduced network usage, reliable offline access, structured storage, fewer backend calls.

Devotionals may optionally be backed up to Supabase for cross-device continuity.

---

## ✍ Personal Study Tools

- Verse highlighting  
- Bookmarks  
- Notes attached to verses  
- Reading position tracking  
- Adjustable fonts  
- Dark / Light mode  

All user-generated data is written **locally first**, synced to Supabase, and available across devices and offline.

---

## 🔄 Synchronization Model

Sync is a core feature.

### Synced Data

| Data type           | Synced | Notes                    |
| ------------------- | ------ | ------------------------- |
| Translations        | ✅     | Files + metadata          |
| Highlights          | ✅     |                           |
| Notes               | ✅     |                           |
| Bookmarks           | ✅     |                           |
| Reading position    | ✅     |                           |
| Devotional progress | Optional | Per design             |

### Sync Strategy

- **Local-first writes** — app remains usable without immediate internet
- **Background synchronization** when connection is available
- **Conflict resolution** — last-write-wins initially; delta-based updates where possible
- **Manual re-sync** option
- No reading functionality must depend on live network access

---

## 📦 Offline-First Design

The app **must** function without internet:

- Bible translations cached locally  
- Devotionals stored locally  
- User data (highlights, notes, bookmarks) stored locally  
- Sync occurs when a connection is available  

---

## 🔐 Backend Overview (Supabase)

Supabase is used for:

- **Authentication** — user accounts and sessions  
- **PostgreSQL database** — structured user data  
- **Row-level security** — strict per-user isolation for notes, highlights, bookmarks, etc.  
- **Storage buckets** — a **central bucket for translation files** (shared within this personal project) plus any other assets  
- **API access** — typed client (e.g. Dart) for all operations  

Although translation files reside in a shared bucket for convenience, this project is designed as a **personal tool with a single real-world user**, so there are no practical privacy concerns from cross-account sharing.

---

## 🎯 Design Principles

- **Offline-first** — full functionality without network  
- **Minimal but powerful** — no unnecessary features  
- **Modular architecture** — clear separation of features and sync  
- **Clean, responsive UI** — readable and accessible  
- **Sync without bloat** — efficient and predictable  
- **Personal control over data** — user owns and can export data  

---

## 🗂 Conceptual Project Structure

```
lib/
├── core/           # Shared utilities, constants, base types
├── features/
│   ├── bible/      # Reader, translation loading, verse navigation
│   ├── devotionals/
│   ├── highlights/
│   ├── notes/
│   └── bookmarks/
├── sync/           # Supabase sync engine, conflict resolution
├── storage/        # Local persistence (e.g. SQLite / Hive)
└── ui/             # Shared widgets, themes, layout
```

---

## 🏗 Development Phases

| Phase | Focus | Deliverables |
| ----- | ----- | ------------ |
| **Phase 1 – Core Reader** | Translation import, local storage, verse rendering | Import system, local DB, basic UI |
| **Phase 2 – Devotionals** | Monthly model, date navigation | Storage model, pre-download logic |
| **Phase 3 – Study Tools** | Highlights, notes, bookmarks | CRUD + UI, customization (fonts, theme) |
| **Phase 4 – Sync Engine** | Supabase integration | Auth, DB schema, translation storage, background sync, conflict resolution |

---

## 🧠 Long-Term Roadmap

- Advanced search (cross-translation)  
- Cross-reference linking  
- Highlight color tagging  
- Reading plans  
- Encrypted local database (optional)  
- Device management for sync  
- Structured backup export (e.g. JSON)  

---

## 📋 Prerequisites

When implementation begins, expect to need:

- **Flutter** — stable channel (SDK as defined in `pubspec.yaml`)  
- **Dart** — 3.x  
- **Supabase** — account and project for auth, database, and storage  
- **Target platform SDKs** — e.g. Android SDK, Windows SDK, for chosen platforms  

---

## 🚀 Getting Started

**Current status: planning.** No application code is required to run yet.

When development starts:

1. Clone the repository and run `flutter pub get`.  
2. Configure Supabase (env vars or config file) for auth and API URL.  
3. Use the phase plan above to implement in order.  

For Flutter itself:

- [Flutter install](https://docs.flutter.dev/get-started/install)  
- [First Flutter app](https://docs.flutter.dev/get-started/codelab)  
- [Flutter documentation](https://docs.flutter.dev/)  

---

## 📌 Status & Next Steps

**Status:** Planning stage. Architecture direction defined; implementation scheduled for a later phase.

**When development begins, the next critical steps will be:**

1. **Design the translation file specification** — format, schema, and validation rules.  
2. **Define database schema** — local (e.g. SQLite) and Supabase (PostgreSQL).  
3. **Build a robust sync engine** — auth, upload/download, conflict handling.  
4. **Choose a state management solution** — e.g. Riverpod, Provider, or Bloc, and apply consistently.  

The project will grow **deliberately and structurally** — not rapidly and chaotically.

---

## 📄 License

Private / personal use. See repository or author for terms.
