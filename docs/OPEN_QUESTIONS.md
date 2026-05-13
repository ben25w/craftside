# Open Questions

These are the questions that should be answered before the app is treated as more than a prototype.

## Product

1. Should the first public release support full-space Craft API connections, Daily Notes API connections, or both?
2. Where should new notes go by default when a full-space connection is available?
3. Should editing overwrite the first editable text block only, or should CraftSide preserve and update multiple text blocks?
4. Should outside-click close ask for confirmation when the editor has unsaved changes?
5. Should the global keyboard shortcut be fixed for v1 or user configurable before release?
6. Should delete/archive be included in v1, or should v1 avoid destructive actions entirely?

## Craft API

1. What exact payload shape should be used for rich Markdown and task blocks in `POST /documents`, `POST /blocks`, and `PUT /blocks`?
2. Does `GET /documents` reliably return `metadata.lastModifiedAt` for sorting, or does the client need another field?
3. Are Craft deep links best sourced from API `url` fields, `/connection` URL templates, or a custom URL scheme?
4. What API rate limits apply to live search and refresh-on-open?
5. Does a Daily Notes connection support creating a daily note implicitly by inserting a block for `date=today`, or is a separate create operation needed?

## Open Source

1. Is MIT the intended license long term?
2. Should the public repository include issue templates and a contributing guide now, or wait until the app has real users?
3. Should the app name stay `CraftSide`, given Craft is a third-party product name?
