# Routes

# Bible Project

Version: 1.0

---

# Purpose

This document defines every application route, its purpose, entry conditions, and navigation behavior.

The application should use declarative routing and support deep linking where practical.

---

# Route Naming Convention

All routes use lowercase snake_case.

Example:

```
/reader
/settings
/bookmarks
```

Dynamic routes:

```
/reader/:book/:chapter
```

---

# Route Overview

| Route | Description |
|---------|-------------|
| / | Splash Screen |
| /welcome | Welcome / Introduction |
| /login | Authentication |
| /reader | Bible Reader |
| /search | Search |
| /translations | Translation Manager |
| /bookmarks | Bookmarks |
| /notes | Notes |
| /settings | Settings |
| /about | About |
| /downloads | Downloads |
| /profile | User Profile |

---

# Splash

```
/
```

Purpose

- Initialize application
- Load local database
- Restore session
- Check installed translations

Possible navigation

↓

Welcome

↓

Reader

↓

Login

---

# Welcome

```
/welcome
```

Purpose

Introduce the application.

Actions

- Sign In
- Continue Offline
- Import Translation

---

# Login

```
/login
```

Purpose

Authenticate with Supabase.

Successful login:

↓

Restore user data

↓

Reader

---

# Reader

```
/reader
```

Primary application screen.

Responsibilities

- Display Scripture
- Navigate books
- Navigate chapters
- Select verses

Subroutes

```
/reader/:book

/reader/:book/:chapter

/reader/:book/:chapter/:verse
```

Examples

```
/reader/john/3

/reader/psalms/23

/reader/genesis/1/1
```

Deep linking should open directly to the requested location.

---

# Search

```
/search
```

Purpose

Search across installed translations.

Possible searches

Book

Verse

Keyword

Future

Phrase search

---

# Translation Manager

```
/translations
```

Purpose

Manage installed translations.

Functions

Import

Download

Delete

Update

View installed translations

---

# Downloads

```
/downloads
```

Purpose

Monitor:

Current downloads

Queued downloads

Completed downloads

Failed downloads

Future

Pause

Resume

---

# Notes

```
/notes
```

Purpose

Browse all notes.

Capabilities

Search

Edit

Delete

Sort

Filter

Selecting a note:

↓

Open corresponding verse.

---

# Bookmarks

```
/bookmarks
```

Purpose

Display saved passages.

Capabilities

Open

Delete

Sort

Filter

---

# Settings

```
/settings
```

Categories

Appearance

Reading

Synchronization

Downloads

Accessibility

About

---

# Profile

```
/profile
```

Purpose

Manage user account.

Contains

Display name

Email

Storage usage (future)

Connected devices (future)

Logout

---

# About

```
/about
```

Contains

Application version

License

Credits

Privacy

Repository link

---

# Dialog Routes

Dialogs should not replace pages.

Examples

Import Translation

Add Note

Highlight Picker

Delete Confirmation

Sync Error

---

# Bottom Navigation

Mobile

Reader

Search

Bookmarks

Notes

Settings

---

# Desktop Navigation

Navigation Rail

or

Sidebar

Items

Reader

Search

Translations

Bookmarks

Notes

Downloads

Settings

---

# Navigation Rules

Reader should always remain one interaction away.

Avoid navigation depth greater than three levels.

Example

Good

Reader

↓

Bookmarks

↓

Verse

Bad

Reader

↓

Bookmarks

↓

Folder

↓

Category

↓

Verse

---

# Back Navigation

Back should always return to the previous logical screen.

Never lose user progress.

---

# Deep Linking

Supported

Book

Chapter

Verse

Examples

```
/reader/romans/8

/reader/john/1/1
```

Future

Bookmarks

Notes

Search results

---

# Route Guards

Require Authentication

Profile

Cloud Sync

Future Device Management

Allow Offline

Reader

Search

Bookmarks

Notes

Settings

Translations

---

# Initial Route Logic

App Launch

↓

Session Exists?

↓

Yes

↓

Reader

↓

No

↓

Welcome

---

# Error Route

Unknown routes redirect to

```
/reader
```

or

Custom 404 Page

The user should never become trapped.

---

# Future Routes

```
/reading-plans

/audio

/history

/references

/plugins

/devices

/backup

/import

/export

```

---

# Routing Principles

Navigation should be:

Predictable

Minimal

Fast

Consistent

The Bible Reader is always the application's primary destination.

---