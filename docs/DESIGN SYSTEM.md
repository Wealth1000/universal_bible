# Design System

# Bible Project

Version: 1.0

---

# 1. Philosophy

The Bible Project is first and foremost a reading application.

Every design decision should improve readability, reduce distraction, and allow users to focus on Scripture.

The interface should feel:

- Calm
- Clean
- Modern
- Spacious
- Predictable

Avoid making the application feel like a social media app.

---

# 2. Design Principles

## Readability First

Scripture is the primary content.

Everything else is secondary.

---

## Content Over Chrome

The interface should disappear while reading.

Navigation should never compete with the text.

---

## Minimalism

Every UI element must justify its existence.

If removing a component improves focus, remove it.

---

## Consistency

Identical actions should always look and behave the same.

---

## Accessibility

Every feature should remain usable with:

- large fonts
- keyboard navigation
- touch input
- mouse input

---

# 3. Color Philosophy

Colors should communicate purpose—not decoration.

Recommended semantic colors:

Primary
- Reading accent
- Active buttons

Secondary
- Supporting actions

Background
- Reading surface

Surface
- Cards
- Panels
- Dialogs

Error
- Invalid operations

Success
- Completed operations

Warning
- Confirmation prompts

Information
- Neutral notifications

Avoid overly saturated colors.

---

# 4. Theme Support

The application supports:

- Light Theme
- Dark Theme

Future:

- AMOLED Theme
- Sepia Reading Theme

Theme switching should be instantaneous.

---

# 5. Typography

Typography is the most important design element.

Priorities:

1. Readability
2. Comfortable spacing
3. Consistency

Scripture should always be easier to read than interface labels.

---

## Hierarchy

Large Heading

Screen titles

Medium Heading

Section titles

Body

Bible verses

Caption

Metadata

Small

Secondary information

---

# 6. Font Scaling

Users should control:

- font size
- line spacing (future)
- paragraph spacing (future)

Scaling should affect:

- Bible text
- Notes
- Devotionals
- Search results

Not:

Navigation icons

---

# 7. Spacing

Use consistent spacing throughout the application.

Suggested spacing scale

4

8

12

16

24

32

48

64

Avoid arbitrary spacing values.

---

# 8. Corners

Rounded corners should be subtle.

Avoid excessive rounding.

Cards should appear modern without becoming playful.

---

# 9. Shadows

Use minimal elevation.

Reading screens should appear flat.

Only dialogs and floating elements require shadows.

---

# 10. Icons

Use a single icon family throughout the application.

Icons should be:

simple

recognizable

consistent

Never mix icon packs.

---

# 11. Buttons

Primary Button

Main action.

Examples

Import Translation

Save Note

Login

Secondary Button

Supporting actions.

Text Button

Low emphasis actions.

Icon Button

Toolbar actions.

Buttons should never compete with Scripture.

---

# 12. Inputs

Input fields should support:

clear labels

validation

error states

helper text

Password fields should support visibility toggle.

---

# 13. Cards

Cards are used sparingly.

Examples

Settings

Downloads

Bookmarks

Search Results

Avoid putting Bible text inside decorative cards.

Reading should remain immersive.

---

# 14. Lists

Lists should support:

smooth scrolling

keyboard navigation

touch interaction

lazy loading

Long lists should remain performant.

---

# 15. Navigation

Desktop

Navigation Rail

or

Sidebar

Mobile

Bottom Navigation

or

Navigation Drawer

Navigation should remain consistent across platforms.

---

# 16. Reader Layout

Reading mode receives the highest design priority.

The reader should maximize:

- text width
- whitespace
- readability

Desktop

Centered reading column.

Mobile

Full-width reading.

Future:

Dual-column desktop mode.

---

# 17. Highlight Appearance

Highlights should remain subtle.

Avoid fluorescent colors.

Future:

Multiple highlight colors.

---

# 18. Notes

Notes should feel lightweight.

Quick creation.

Quick editing.

Minimal interruptions.

---

# 19. Animations

Animations should communicate state changes.

Examples

page transitions

dialogs

theme switching

Avoid decorative animations.

Target duration:

150–250 ms

---

# 20. Responsive Design

The application should adapt naturally.

Phone

Single-column interface.

Tablet

Expanded reading width.

Desktop

Sidebar

Resizable panels

Keyboard shortcuts

---

# 21. Empty States

Every empty page should provide:

simple explanation

primary action

Examples

"No bookmarks yet."

"No notes created."

"No translations installed."

---

# 22. Loading States

Use:

progress indicators

skeleton placeholders (future)

Never leave blank screens.

---

# 23. Error States

Errors should explain:

what happened

how to recover

Avoid technical language.

---

# 24. Accessibility

Support:

keyboard shortcuts

screen readers

high contrast

large text

focus indicators

Desktop users should be able to navigate entirely via keyboard.

---

# 25. Future Components

Potential reusable components

- Verse Widget
- Chapter Header
- Translation Selector
- Search Result Tile
- Bookmark Tile
- Note Card
- Highlight Toolbar
- Download Card
- Reading Progress Widget

Each should have a single responsibility.

---

# 26. Design Tokens

Spacing

XS

SM

MD

LG

XL

Typography

Display

Heading

Title

Body

Caption

Radius

Small

Medium

Large

Animation

Fast

Normal

Slow

These tokens should be centralized.

---

# Final Design Goal

The interface should disappear.

The user should feel like they are reading Scripture—not using software.

If a design decision improves focus, it is probably the correct one.

If it distracts from reading, reconsider it.

---