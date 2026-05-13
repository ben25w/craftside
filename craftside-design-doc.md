# CraftSide — Design Document v1.0

A SideNotes-style macOS sidebar app that surfaces your Craft notes without leaving your current window.

---

## What It Is

CraftSide is a native macOS menu bar app. It lives on the edge of your screen and slides in as a panel when triggered. It reads from and writes to your Craft workspace via the Craft API, giving you instant access to your notes, daily note, and the ability to create and edit content without opening Craft itself.

Think of SideNotes (apptorium.com/sidenotes) as the UX reference point: a slim panel that appears from the side, stays out of your way when you don't need it, and feels fast and light when you do.

---

## Platform

- macOS app (Swift / SwiftUI)
- Minimum macOS 13
- Menu bar icon triggers the sidebar panel
- Panel slides in from the left or right — user chooses in Settings
- Panel width: fixed, comfortable reading width (approx. 320–380pt)
- Does not appear in the Dock

---

## Authentication

The user connects CraftSide to their Craft workspace by entering their Craft API endpoint URL and API key, generated from Craft Settings → API. These are stored securely in the macOS Keychain. No login screen — just a simple one-time setup sheet on first launch.

---

## Core Layout

The sidebar panel has three main areas from top to bottom:

```
┌─────────────────────────┐
│  [Search bar]    [⚙️]   │  ← Header
├─────────────────────────┤
│  + Add Note             │  ← Add Note button
├─────────────────────────┤
│  📌 Today's Daily Note  │  ← Daily Note section (toggleable)
│  ─────────────────────  │
│  📌 Pinned Note 1       │  ← Pinned notes
│  📌 Pinned Note 2       │
│  ─────────────────────  │
│  Recent Note A          │  ← All other notes, newest first
│  Recent Note B          │
│  Recent Note C          │
│  ...                    │
└─────────────────────────┘
```

---

## Note List

### Behaviour
- On open, shows all notes from the connected Craft workspace, sorted by most recently modified, regardless of which folder or space they live in
- Each note shows its title and a one-line preview of the content
- Tapping a note opens it inline in the editor view (no separate click needed — tap and type)
- No double-click required. Single tap to open

### Pinned Notes
- Any note can be pinned via a right-click context menu or a pin icon on hover
- Pinned notes appear below the Daily Note section and above the unread stream
- Pinned notes persist across sessions

### Daily Note
- If the Daily Note toggle is on (default: on), today's Craft daily note is always shown at the top of the list, below the Add Note button and above pinned notes
- If there is no daily note yet for today, a prompt appears: "Start today's note →" which creates one via the API when tapped
- This section can be hidden entirely from Settings

---

## Add Note

Tapping "+ Add Note" opens the note editor view within the sidebar. This is not a new window — it slides or fades in within the panel itself.

The editor shows:
- A title field at the top (optional)
- A body editor below
- A formatting toolbar at the bottom or top of the editor (see Formatting section)
- A Save button and a Cancel / Back button

When Save is tapped:
- The note is created in Craft via the API
- The editor closes and the note list refreshes
- The new note appears at the top of the recent stream

---

## Note Editor (Create and Edit)

The same editor view is used for both creating and editing notes. When editing an existing note, the current content is loaded into the editor.

### Text Input
- Plain text as the minimum supported format
- Title field and body field are separate inputs

### Formatting (implement as available via API)
These should be offered in the formatting toolbar if the Craft API supports them. Research required to confirm each before implementation:

- **Bold** — wrap selected text
- *Italic* — wrap selected text
- Checklist / task item — inserts a checkbox block
- Bulleted list
- Numbered list
- Heading (H1, H2)
- Inline code

> Note to developer: Review the Craft API block types at https://www.craft.do/imagine/ to confirm which block types are writable via the API. Implement only what is confirmed. If a formatting option is not supported by the API, do not show it in the toolbar. A plain text note is the minimum viable version.

### Open in Craft
Every note in the editor view has an "Open in Craft" button. This uses Craft's URL scheme (craft://...) to deep-link directly to that note in the Craft app.

---

## Search

- A search bar is always visible at the top of the sidebar
- Typing filters the note list in real time
- Search uses the Craft API's search endpoint (supports regex and tag/folder filtering if available)
- If the API does not support live search, implement local filtering across loaded note titles and previews as a fallback

---

## Settings Panel

Accessible via the gear icon in the header. Opens as a sheet or secondary view within the panel.

Options:
- Sidebar position: Left or Right
- Daily Note section: Show / Hide
- API connection: view current endpoint, disconnect, reconnect
- Appearance: match system (light / dark)

---

## Colour Scheme

Match Craft's visual identity:

- Primary accent: Craft purple (#7C4DFF or as close as current branding uses)
- Background: system-aware (NSColor.windowBackgroundColor equivalent)
- Text: system label colours
- Subtle borders and dividers using system separator colours
- Pinned notes: a light tint or pin icon to distinguish from unpinned

Reference Craft's own UI for exact colour values when building. The sidebar should feel like a natural extension of Craft rather than a separate product.

---

## Trigger Behaviour

- Menu bar icon: single click toggles the panel open/closed
- Keyboard shortcut: user-definable global shortcut (e.g. ⌥Space by default)
- The panel slides in from the chosen side with a brief animation
- Clicking anywhere outside the panel closes it (unless a note is being edited — confirm discard if there are unsaved changes)

---

## API Capabilities Summary (to verify before building)

The following are confirmed or expected from the Craft API. Developer should review https://www.craft.do/imagine/ and the official API docs before implementing each:

| Feature | API method | Status |
|---|---|---|
| List all notes | GET /documents | Confirm |
| Get note content | GET /documents/{id} | Confirm |
| Create note | POST /documents | Confirm |
| Update note | PATCH /documents/{id} | Confirm |
| Delete note | DELETE /documents/{id} | Confirm |
| Get today's daily note | GET /daily-notes/today | Confirm |
| Create daily note | POST /daily-notes | Confirm |
| Search notes | GET /documents?search= | Confirm |
| Write block types (bold, checklist etc.) | Block schema in POST body | Confirm |
| Deep link to note in Craft app | craft:// URL scheme | Confirm |

---

## Out of Scope for v1

These are not in the first build. They can be considered for later:

- Folder / space browsing
- Tags
- Sharing or exporting notes
- Images or attachments
- iPad / iOS companion app
- Offline mode / local caching beyond session

---

## Open Questions for Developer

1. Does the Craft API support writing rich block types (checkboxes, headings, bold) or only plain text on create/update? This determines how much of the formatting toolbar is buildable in v1.
2. Does the Craft API provide a "recents" or "last modified" sort on the documents list endpoint, or does the client need to sort manually?
3. Is there a rate limit on the API that would affect real-time search or frequent list refreshes?
4. Does the daily note endpoint return the note for today automatically, or does it require a date parameter?

---

## Summary: MVP Feature Set

The minimum first pass that makes CraftSide useful:

- Menu bar app, slides in from the side
- Lists all notes, most recent first
- Daily note pinned at top (toggleable)
- Pin any note to the top section
- Tap to open and edit inline
- Add new note with title and plain text body
- Save sends to Craft via API
- Open in Craft button on every note
- Search bar filters the list
- Craft purple colour scheme
- Left or right side setting
