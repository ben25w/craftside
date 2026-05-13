# CraftSide

CraftSide is a native macOS menu bar app that opens a slim side panel for Craft notes.

CraftSide is not affiliated with Craft Docs Limited. It is an independent open-source companion app prototype.

## Current Scope

- Menu bar app with a floating side panel.
- Secure Craft API URL and optional API key storage in Keychain.
- Full-space document listing through `GET /documents` when the API connection supports it.
- Daily Note fallback through `GET /blocks?date=today`.
- Inline create/edit flow using Craft block/document endpoints.
- Local pinning, search, Daily Note visibility, side position, and appearance settings.

## Running

```bash
./script/build_and_run.sh
```

The Codex Run action is wired to the same script.

## API Notes

Craft's docs expose separate connection types. Space connections provide document and block routes such as `GET /documents`, `GET /blocks`, `POST /documents`, and `PUT /blocks`. Daily Notes connections provide date-based block routes such as `GET /blocks?date=today`, `POST /blocks`, `PUT /blocks`, and task/search helpers.

The app attempts the broader document flow first and falls back to Daily Notes where a connection is scoped to that API surface.

## Open Questions

See [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md). The main unresolved areas are Craft API payload details for richer blocks, the intended default destination for new notes, and whether the first public release should support both full-space and Daily Notes connections.

## License

MIT. See [LICENSE](LICENSE).
