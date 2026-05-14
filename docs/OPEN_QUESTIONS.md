# Product Decisions

These are the current decisions for CraftSide v1, based on Ben's inline answers on 2026-05-13.

## Locked For Version 1

1. CraftSide is an Xcode macOS app, not a SwiftPM-only prototype.
2. CraftSide stays a menu-bar app with a Reminders-style popover.
3. No global keyboard shortcut for v1.
4. Clicking away closes the popover.
5. Settings live inside the popover.
7. The app name stays CraftSide.
8. The repo is public MIT.
9. Craft Tasks are the v1 focus.
10. Today, overdue, upcoming, and inbox tasks should be easy to scan.
11. Adding tasks must be fast from the keyboard.
12. Completing and rescheduling tasks should happen in-place through MCP.
13. Unsupported MCP/API failures must expose debug details instead of pretending the data is empty.
14. Daily-note block browsing, rich notes, full Craft document browsing, and normal document creation are later work.

## Still To Prove Against Real Craft Data

1. Whether task text editing should be inline or in a small detail sheet.
2. Whether custom date changes should be available per existing task, not just Today/Tomorrow/Inbox chips.
3. Whether repeating tasks need first-class UI in v1.
4. Whether Daily Notes should return as a separate tab after the task workflow is solid.
