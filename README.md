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

## Import Craft Tasks To Apple Reminders

The standalone import script reads open Craft tasks and creates Apple Reminders in the default Reminders list. It does not change the CraftSide app or modify any Craft tasks.

Preview first:

```bash
swift script/import_craft_tasks_to_reminders.swift --dry-run
```

Import:

```bash
swift script/import_craft_tasks_to_reminders.swift
```

The script imports `active`, `upcoming`, and `inbox` Craft tasks. It maps Craft schedule dates to Reminders due dates, falls back to deadline dates when no schedule is present, and does not add reminder notes. Re-running the import will add tasks again, including duplicates, by design.

The Craft MCP URL is read from `CRAFT_MCP_URL` first, then from the CraftSide Keychain item saved by Settings.

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
