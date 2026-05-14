# CraftSide

CraftSide is a native macOS menu bar app for fast Craft tasks.

CraftSide is not affiliated with Craft Docs Limited. It is an independent open-source companion app prototype.

## Version 1 Scope

- Xcode macOS app, suitable to grow toward App Store distribution.
- Menu bar icon opens and closes a Reminders-style popover.
- No global keyboard shortcut in v1.
- Outside click closes the panel.
- Craft Tasks are the main v1 focus.
- Fast task entry with Return-to-add.
- Schedule tasks for Inbox, Today, Tomorrow, or a custom date.
- Show Today, Overdue, Upcoming, Inbox, and All task views.
- Complete Craft tasks from the popover.
- Move tasks between Inbox, Today, and Tomorrow.
- Debug mode shows raw Craft JSON and write responses whenever the app cannot fully render or update something.
- Craft MCP URL, API URL, and API key are stored in Keychain.

Daily-note block browsing and normal Craft document creation are planned for later versions.

## Running

Generate or refresh the Xcode project after changing `project.yml`:

```bash
xcodegen generate
```

Build and launch:

```bash
./script/build_and_run.sh
```

Install into `/Applications` and launch:

```bash
./script/build_and_run.sh --install
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

## Craft Connection

CraftSide v1 prefers the Craft Daily Notes MCP connection because it exposes task actions cleanly:

- `craft_read`: `tasks list --scope active`
- `craft_read`: `tasks list --scope upcoming`
- `craft_read`: `tasks list --scope inbox`
- `craft_write`: `tasks add --markdown ... --schedule ...`
- `craft_write`: `tasks update --task ... --state done`
- `craft_write`: `tasks update --task ... --schedule ...`

The older Craft Daily Notes API remains as a fallback:

- `GET /blocks?date=YYYY-MM-DD&maxDepth=-1&fetchMetadata=true`
- `POST /blocks` with `Content-Type: text/markdown`
- `PUT /blocks` for selected block editing
- `GET /tasks?scope=active` for debug coverage

Never commit MCP URLs, API URLs, API keys, screenshots containing tokens, or copied request output with private note content.

## License

MIT. See [LICENSE](LICENSE).
