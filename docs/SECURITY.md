# Security

CraftSide stores the Craft API URL and optional API key in the macOS Keychain.

Do not commit:

- API keys or bearer tokens
- `.env` files
- provisioning profiles
- signing certificates
- exported app archives
- local logs containing API responses

If a secret is committed by accident, rotate it immediately in Craft and remove it from Git history before making another public push.
