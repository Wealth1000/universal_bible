# Screen Map

# Bible Project

Version: 1.0

---

# Purpose

This document defines every screen in the application, how they relate to one another, and the expected user navigation flow.

Unlike `ROUTES.md`, which defines navigation paths, this document focuses on the user interface hierarchy and screen relationships.

---

# Application Overview

```
Splash
   │
   ▼
Welcome
   │
   ├───────────────┐
   ▼               ▼
Login      Continue Offline
   │               │
   └───────┬───────┘
           ▼
      Bible Reader
```

The Bible Reader is the application's central hub.

---

# Primary Navigation

```
Bible Reader
│
├── Search
├── Bookmarks
├── Notes
├── Translations
├── Downloads
├── Settings
└── Profile
```

No primary screen should require navigating through another primary screen.

---

# Splash Screen

## Purpose

Initialize application.

Responsibilities

- Load local database
- Restore authentication session
- Load settings
- Check installed translations
- Prepare synchronization

Possible destinations

- Welcome
- Reader

---

# Welcome Screen

Purpose

Introduce the application.

Contains

- App logo
- Welcome message
- Sign In
- Continue Offline
- Import Translation

The welcome screen should only appear during initial setup.

---

# Login Screen

Purpose

Authenticate the user.

Components

- Email
- Password
- Sign In
- Create Account
- Forgot Password

After successful login:

↓

Reader

---

# Bible Reader

This is the application's primary screen.

Responsibilities

Display Scripture.

Navigation.

Verse interaction.

Reading experience.

---

## Reader Layout (Desktop)

```
┌─────────────────────────────────────────────┐
│ Top App Bar                                │
├──────────────┬──────────────────────────────┤
│ Navigation   │                              │
│              │                              │
│              │      Bible Reader            │
│              │                              │
│              │                              │
├──────────────┴──────────────────────────────┤
│ Optional Status Bar                         │
└─────────────────────────────────────────────┘
```

---

## Reader Layout (Mobile)

```
App Bar

↓

Bible Content

↓

Bottom Navigation
```

Maximum screen space should be dedicated to Scripture.

---

# Search Screen

Purpose

Find Scripture quickly.

Sections

Recent Searches

Search Results

Search Filters

Future

Cross-translation search.

---

# Bookmarks Screen

Displays

Saved verses

Saved chapters

Future collections

Selecting a bookmark

↓

Reader

---

# Notes Screen

Displays

All notes

Search

Sort

Filter

Selecting a note

↓

Reader

↓

Highlighted verse

---

# Translation Screen

Purpose

Manage translations.

Displays

Installed translations

Available downloads

Import option

Update status

Actions

Import

Delete

Download

Activate

---

# Downloads Screen

Displays

Current downloads

Completed downloads

Failed downloads

Future

Queued downloads

Pause

Resume

---

# Settings Screen

Categories

Appearance

Reading

Synchronization

Accessibility

Downloads

About

Settings should remain organized into logical groups.

---

# Profile Screen

Displays

User information

Synchronization status

Account actions

Future

Connected devices

Storage usage

---

# About Screen

Contains

Application version

License

Credits

Repository

Privacy

---

# Modal Screens

The following interactions should use dialogs or bottom sheets rather than full pages.

Desktop

Dialogs

Mobile

Bottom Sheets

Examples

Add Note

Import Translation

Highlight Picker

Delete Confirmation

Sync Error

---

# Context Menus

Verse Context Menu

- Highlight
- Bookmark
- Add Note
- Copy
- Share (future)

Translation Menu

- Activate
- Delete
- Update

Bookmark Menu

- Open
- Delete

---

# Screen Relationships

```
Reader
├── Verse Menu
│      ├── Highlight
│      ├── Bookmark
│      └── Note
│
├── Search
│      └── Reader
│
├── Bookmarks
│      └── Reader
│
├── Notes
│      └── Reader
│
├── Translations
│      └── Reader
│
└── Settings
```

Most screens eventually return to the Reader.

---

# Mobile Navigation

Bottom Navigation

```
Reader

Search

Bookmarks

Notes

Settings
```

Secondary screens

Downloads

Translations

About

Profile

Accessible from

Settings

or

Drawer

---

# Desktop Navigation

Navigation Rail

```
Reader

Search

Translations

Bookmarks

Notes

Downloads

Settings
```

Optional

Collapsible Sidebar

---

# Responsive Behavior

Phone

Single column

Tablet

Expanded reader

Desktop

Sidebar

Navigation rail

Large reading column

Resizable windows

---

# Empty States

Reader

No translations installed

↓

Prompt import

Bookmarks

No bookmarks yet

↓

Continue reading

Notes

No notes created

↓

Start studying

Downloads

No active downloads

↓

Browse translations

---

# Loading States

Loading should appear for

Translation import

Synchronization

Search indexing

Download progress

Avoid blocking the reader.

---

# Error States

Examples

Translation missing

Import failed

Network unavailable

Authentication expired

Every error screen should provide:

Explanation

Recovery action

Retry

---

# Accessibility Flow

Keyboard

Tab navigation

Shortcuts

Visible focus

Screen Readers

Semantic labels

Logical reading order

Large text

Dynamic layout adaptation

---

# Future Screens

Reading Plans

History

Audio Bible

Cross References

Parallel Translation

Study Workspace

Plugins

Backups

Device Management

Developer Tools

These should integrate without changing the primary navigation philosophy.

---

# Final Principle

The Bible Reader is the center of the application.

Every screen exists to support reading, studying, or managing Scripture.

If a screen distracts from that mission, it should be redesigned or removed.

---