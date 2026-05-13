# Contributing

CraftSide is early-stage. Keep contributions small and focused.

Before opening changes:

1. Run `xcodegen generate` after changing `project.yml`.
2. Run `xcodebuild -project CraftSide.xcodeproj -scheme CraftSide -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' test`.
3. Run `./script/build_and_run.sh --verify` on macOS.
4. Avoid committing API keys, local build products, app bundles, or signing material.

The app intentionally starts with Craft Daily Notes and Markdown-oriented inserts. When the Craft API returns blocks that are not fully understood, keep a visible debug path rather than hiding the response.
