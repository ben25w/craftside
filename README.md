# CraftSide

CraftSide is a native macOS menu bar app that opens a Craft Daily Notes side panel.

CraftSide is not affiliated with Craft Docs Limited. It is an independent open-source companion app prototype.

## Version 1 Scope

- Xcode macOS app, suitable to grow toward App Store distribution.
- Menu bar icon opens and closes a floating side panel.
- No global keyboard shortcut in v1.
- Left or right side opening, stored as a user setting.
- Outside click closes the panel.
- Daily Notes only for v1, with today pinned at the top and nearby dates available.
- Read daily-note blocks from the Craft Daily Notes API.
- Append or insert Markdown at the top, bottom, before a selected block, or after a selected block.
- Render common rich blocks locally: headings, paragraphs, lists, tasks, links, code, quotes, files, and nested children.
- Debug mode shows raw Craft JSON and write responses whenever the app cannot fully render or update something.
- API URL and API key are stored in Keychain.

Full Craft document browsing and normal document creation are planned for a later version.

## Running

Generate or refresh the Xcode project after changing `project.yml`:

```bash
xcodegen generate
```

Build and launch:

```bash
./script/build_and_run.sh
```

Build and verify launch:

```bash
./script/build_and_run.sh --verify
```

Run tests:

```bash
xcodebuild -project CraftSide.xcodeproj -scheme CraftSide -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' test
```

The Codex Run action is wired to `./script/build_and_run.sh`.

## API Notes

CraftSide v1 uses the Craft Daily Notes API:

- `GET /blocks?date=YYYY-MM-DD&maxDepth=-1&fetchMetadata=true`
- `POST /blocks` with `Content-Type: text/markdown`
- `PUT /blocks` for selected block editing
- `GET /tasks?scope=active` for debug coverage

The write path uses the Daily Notes `position` query parameter instead of the older JSON body shape that caused Craft validation errors.

## License

MIT. See [LICENSE](LICENSE).
