# Product Decisions

These are the current decisions for CraftSide v1, based on Ben's inline answers on 2026-05-13.

## Locked For Version 1

1. CraftSide is an Xcode macOS app, not a SwiftPM-only prototype.
2. CraftSide stays a menu-bar app with a floating side panel.
3. No global keyboard shortcut for v1.
4. The panel can open from the left or right side, controlled by an in-panel setting.
5. Clicking away closes the panel.
6. Settings live inside the side panel.
7. The app name stays CraftSide.
8. The repo is public MIT.
9. Daily Notes are the v1 focus.
10. Today is pinned at the top, and nearby past/future dates are easy to reach.
11. The app should preserve and render as much Craft structure as possible.
12. Unsupported blocks and failed writes must expose debug details instead of pretending the note is empty.
13. Full Craft document browsing and normal document creation are version 2 work.

## Still To Prove Against Real Craft Data

1. Exact `PUT /blocks` payload for rich block edits.
2. Whether every Daily Notes connection accepts text/markdown inserts with `position` for top, bottom, before, and after selected blocks.
3. How Craft returns attachments, images, backlinks, and complex task metadata in real daily notes.
4. Whether Daily Notes search/date navigation needs a full calendar picker after the current date rail.
5. How much rich editing should be native in CraftSide versus opened directly in Craft.
