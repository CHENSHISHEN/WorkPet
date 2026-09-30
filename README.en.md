# WorkPet

[中文](README.md) | [English](README.en.md)

WorkPet is a native macOS desktop pet that doubles as a work-notification hub. Instead of a complex virtual-pet game, it uses an always-on-top, cross-Space overlay pet to surface the work messages you'd otherwise miss.

> This repository is prepared as a public open-source project. The software source code is MIT-licensed; licensing for the bundled pet artwork is described in [`NOTICE.md`](NOTICE.md).

## Preview

### Message alerts

The pet pops a speech bubble and plays a per-source animation when a message arrives:

WeChat / Feishu:

![WeChat alert](docs/videos/wechat-alert.mp4) ![Feishu alert](docs/videos/feishu-alert.mp4)

Calendar agenda / DataGrip task:

![Calendar alert](docs/videos/calendar-alert.mp4) ![DataGrip alert](docs/videos/datagrip-alert.mp4)

### Idle animations

When no messages arrive for a while, the pet rotates through idle animations:

![Idle standing](docs/videos/idle-standing.mp4) ![Idle cuddle](docs/videos/idle-cuddle.mp4) ![Idle life-death burst](docs/videos/idle-life-death-burst.mp4)

## Features

- Native AppKit overlay window: draggable, always-on-top, attempts to stay visible across Spaces and full-screen apps.
- `NotificationHub`: source-grading, deduplication, and unified delivery of notifications.
- Today's agenda via EventKit (macOS Calendar).
- WeChat / Feishu message alerts: monitors the macOS notification database in real time, extracts sender and body, classifies chats (direct / group / official / system), and triggers per-source pet animations.
- Message rule filtering: whitelist / blacklist by app, category, sender, and keyword to decide strong / normal / silent alerts.
- Menu-bar unread fallback: optionally reads WeChat / Feishu menu-bar unread counts via the Accessibility API.
- DataGrip integration: a file-hook script plus a JetBrains plugin that monitors SQL execution batches.
- Startup diagnostics for calendar permission, notification-database access, and the DataGrip watch directory.
- Image-based pet packs (`pet.json` + png/jpg/webp frames) — swap pets without touching code.
- Right-click menu: choose pet, interact, refresh agenda, do-not-disturb, quit.

Not yet implemented: dedicated WeChat/Feishu platform APIs (reading messages via the macOS notification channel already works today), a settings UI, code signing, auto-update, and production distribution.

## Requirements

- macOS 14.0+
- Swift 5.10+ (Xcode Command Line Tools; no Xcode project needed)
- Optional, for the DataGrip plugin: JDK 17+ and a local DataGrip installation

## Quick Start

```bash
git clone <repo-url> && cd WorkPet

# Build & test
cd WorkPet
swift build
swift test

# Run
swift run WorkPet

# Or package as .app (from repo root)
cd ..
./build-app.sh
open build/WorkPet.app
```

To build the DataGrip plugin:

```bash
cd datagrip-plugin
./build-local.sh   # output: build/WorkPetDataGripNotifier.zip
```

Install in DataGrip via Settings > Plugins > gear icon > Install Plugin from Disk...

## Project Layout

```text
WorkPet/           # Swift Package macOS app
datagrip-plugin/   # DataGrip auto-monitor plugin (Java)
docs/              # Documentation (Chinese)
scripts/           # Utility and asset-generation scripts
build-app.sh       # Packages WorkPet.app
```

## Privacy & Data Boundary

WorkPet runs entirely on your Mac. It has no remote service, no account login, and no API keys. Depending on the permissions you grant, it may read locally:

- Calendar events (EventKit) for today's agenda.
- The macOS notification database (read-only) to identify WeChat / Feishu notifications — this typically requires Full Disk Access.
- WeChat / Feishu menu-bar unread counts via optional Accessibility access.
- DataGrip task summary files under `~/Library/Application Support/WorkPet/datagrip-tasks/` — SQL text and database credentials are never uploaded (there is no upload channel at all).

All data stays on your machine. Adapters remain disabled if you decline the corresponding permission.

## License

The software source code is released under the MIT License — see [`LICENSE`](LICENSE). The bundled pet artwork under `WorkPet/Sources/WorkPet/Resources/PetPacks/` is **not** covered by MIT; see [`NOTICE.md`](NOTICE.md) for details.

## Documentation

Full documentation is in Chinese under [`docs/`](docs/):
[Daily use](docs/DAILY_USE.md) · [Message rules](docs/MESSAGE_RULES.md) · [Pet asset packs](docs/PET_ASSET_PACKS.md) · [DataGrip hooks](docs/DATAGRIP_INTEGRATION.md) · [DataGrip auto monitor](docs/DATAGRIP_AUTO_MONITOR.md)
