# CraftSide Design Document

CraftSide is a native macOS menu-bar app that opens a slim Craft Daily Notes side panel. The app is built as an Xcode project so it can grow toward App Store distribution later.

CraftSide is not affiliated with Craft Docs Limited.

## Version 1 Goal

A working menu-bar Craft Daily Notes side panel that can read today's note, navigate nearby daily notes, and insert or edit note content without opening Craft.

## Version 1 Decisions

- Daily Notes only.
- Today stays pinned at the top.
- Past and future daily notes are available from the date rail, including tomorrow.
- Open and close from the menu bar icon.
- No global keyboard shortcut.
- Side placement is a user setting: left or right.
- Clicking away closes the panel.
- Settings live inside the panel.
- Unsupported Craft blocks and API failures show debug data instead of empty-state text.
- The app name remains CraftSide.
- The project stays public under MIT.

## Main Panel

The panel is optimized for fast Daily Notes work:

1. Header with the CraftSide title, selected date, refresh, settings, and close controls.
2. Pinned today row.
3. Date rail for nearby past and future daily notes.
4. Daily note content rendered as nested Craft-like blocks.
5. Composer for inserting Markdown at the top, bottom, before the selected block, or after the selected block.
6. Inline editor for the selected block where the API supports it.
7. Debug drawer for raw Craft JSON and write responses.

## Craft Content

CraftSide should preserve as much daily-note structure as possible in v1:

- Headings
- Paragraphs
- Lists
- Tasks
- Links
- Code
- Quotes
- Attachments and file references
- Nested child blocks

Any block shape the app does not understand must still be visible through the debug view.

## API Surface

Version 1 uses the Craft Daily Notes API:

- `GET /blocks?date=YYYY-MM-DD&maxDepth=-1&fetchMetadata=true`
- `POST /blocks` with `Content-Type: text/markdown`
- `PUT /blocks` for selected block edits where supported
- `GET /tasks?scope=active` for debug coverage

The insertion path uses the Daily Notes `position` query parameter because the previous JSON-body shape caused Craft validation errors.

## Version 2 Direction

Later versions can add:

- Full Craft document browsing.
- Normal Craft document creation.
- Richer visual rendering for images and backlinks.
- Search across documents and daily notes.
- More complete native block editing.
