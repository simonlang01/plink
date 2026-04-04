# Plink

A minimalist, ultra-fast macOS ToDo app focused on quick capture via a global keyboard shortcut.

**Current version:** 1.5.1 · macOS 14+

---

## Features

- Global shortcut to instantly capture tasks (default: `N + Space`)
- Dashboard with open, overdue, and future tasks
- Task groups, priorities, and due dates
- Smart Input — natural language date parsing (e.g. "dentist tomorrow")
- Full Dark / Light / System appearance support
- Accent color theming
- English and German localization
- Search across active and completed tasks
- Trash with permanent delete
- Auto-updates via Sparkle

---

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **Auto-updates:** [Sparkle 2](https://sparkle-project.org)
- **Shortcuts:** [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- **Project generation:** XcodeGen (`project.yml`)

---

## Project Structure

```
Plink/
├── Core/               # AppState, PersistenceController, LanguageManager, models
├── Views/              # All SwiftUI views
│   ├── Dashboard/
│   ├── QuickAdd/
│   ├── Onboarding/
│   ├── Help/
│   └── Settings/
dist/
├── appcast.xml         # Sparkle update feed (also at repo root)
├── Plink-x.x.x.dmg    # Built DMGs (not committed, see .gitignore)
release.sh              # Release automation script
project.yml             # XcodeGen project definition
```

---

## Environments

| | Dev | Production |
|---|---|---|
| Bundle ID | `com.simonlang.Plink.dev` | `com.simonlang.Plink` |
| Display name | Plink Dev | Plink |
| Data location | `~/Library/Application Support/Plink-Dev/` | `~/Library/Application Support/Plink/` |
| Sparkle | Disabled | Enabled |

Build with **Debug** scheme for development, **Release** scheme for distribution.

---

## Releasing a New Version

1. Develop and test in the **Dev** environment.

2. Run the release script:
   ```bash
   ./release.sh <version> <build>
   # Example:
   ./release.sh 1.6 3
   ```
   This will:
   - Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`
   - Build the Release configuration
   - Create `dist/Plink-<version>.dmg`
   - Sign the DMG with the Sparkle EdDSA key
   - Update `appcast.xml` (root + `dist/`)

3. Commit and push:
   ```bash
   git add appcast.xml dist/appcast.xml Plink/Info.plist
   git commit -m "Release <version>"
   git push
   ```

4. Create a GitHub Release:
   - Go to github.com/simonlang01/plink → Releases → Draft a new release
   - Tag: `v<version>` (e.g. `v1.6`)
   - Upload `dist/Plink-<version>.dmg`
   - Publish

Existing users will see the update prompt on next launch.

### Build number convention
| Version | Build |
|---|---|
| 1.5 | 1 |
| 1.5.1 | 2 |
| 1.6 | 3 |
| … | … |

Always increment the build number with each release — Sparkle uses it (not the version string) to detect updates.

---

## Sparkle Signing Key

The EdDSA private key used to sign DMGs is stored in **macOS Keychain** under `https://sparkle-project.org`. It is never committed to this repo.

**To back it up:**
```bash
./build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/sparkle_private_key_backup.txt
```
Store the backup in a password manager or encrypted location. Without this key, you cannot sign future updates.

The corresponding **public key** is in `Plink/Info.plist` under `SUPublicEDKey` — this is safe to be public.

---

## Localization

Strings are managed in `Plink/Core/Localizable.xcstrings`. Currently supported:
- English (`en`)
- German (`de`)
- Spanish — coming later this year

---

## License

Copyright © 2025 Simon Lang. All rights reserved.
