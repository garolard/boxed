# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Boxed** (`vgcollection`) — Flutter app for cataloguing a physical videogame collection.
Android + iOS only. Dark theme only. Localized en/es/fr.

## Commands

```bash
flutter pub get
flutter analyze                                   # lints: flutter_lints
flutter test                                      # all tests
flutter test test/services/scan_quota_service_test.dart   # single file
flutter test --plain-name "records a scan"        # single test by name
flutter gen-l10n                                  # regenerate lib/l10n/app_localizations*.dart
```

Running the app needs compile-time secrets (see below):

```bash
flutter run \
  --dart-define=IGDB_CLIENT_ID=... --dart-define=IGDB_SECRET_ID=... \
  --dart-define=COVER_SCAN_ENDPOINT=https://... --dart-define=COVER_SCAN_TOKEN=... \
  --dart-define=REVENUECAT_ANDROID_KEY=... --dart-define=REVENUECAT_IOS_KEY=... \
  --dart-define=IS_PREMIUM=false
```

Cover scan needs a real device (camera). `IS_PREMIUM=true` bypasses the scan paywall locally.

## Configuration

Secrets are **compile-time** `String.fromEnvironment` reads, not runtime `.env` loading —
`flutter_dotenv` is still in `pubspec.yaml` but nothing imports it. The gitignored `.env` at
the repo root is only a place to keep the values; it is not a bundled asset.

| define | read in |
| --- | --- |
| `IGDB_CLIENT_ID`, `IGDB_SECRET_ID` | `lib/services/igdb_service.dart` |
| `COVER_SCAN_ENDPOINT`, `COVER_SCAN_TOKEN` | `lib/services/cover_scan_service.dart` |
| `REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY` | `lib/services/purchase/revenuecat_purchase_service.dart` |
| `IS_PREMIUM` | `lib/main.dart` (dev-only premium override) |

## Architecture

State is **Riverpod** (`flutter_riverpod` 3.x). Widgets are `ConsumerWidget` /
`ConsumerStatefulWidget`; there is no router — `HomeScreen` is an `IndexedStack` of tabs and
everything else is pushed with `Navigator`.

### The dependency-injection seam

`lib/providers/services.dart` is the single place shared singletons are declared. Three of
them **throw by default** and are overridden in `main.dart`'s `ProviderScope`:
`analyticsServiceProvider`, `scanQuotaServiceProvider`, `purchaseServiceProvider`. When adding
a service that needs async init or platform plugins, follow that pattern — declare a throwing
`Provider`, construct it in `main()`, override it. Tests override the same providers with fakes
(`test/fakes/`, `test/services/purchase/fake_purchase_service.dart`).

`CollectionNotifier` reads its dependencies in `build()` via `ref.read`, so overriding the
providers is enough to isolate it.

### Layers

- `models/` — plain data. `Game` parses IGDB JSON *and* round-trips to the local DB snapshot.
- `services/` — no Flutter widget imports; each takes its collaborators via constructor.
  - `igdb_service.dart` — Twitch OAuth token (cached in SharedPreferences) + Apicalypse queries.
  - `collection_repository.dart` — sqflite; owned games and scanned "shared collections" are
    separate tables. Each row stores a full IGDB JSON snapshot so the app works offline.
  - `cover_scan_service.dart` — POSTs the raw photo bytes to the Cloudflare worker in
    `worker/`, which calls OpenAI `gpt-5-nano` vision and returns `{title, confidence}`
    candidates. **No OpenAI key ships in the app**; it lives only in the worker's secrets.
    (Cover scan replaced on-device ML Kit OCR; ML Kit is still a dependency but only for
    **QR barcode** scanning in `qr_scan_service.dart`.)
  - `qr_payload_codec.dart` — compact game/platform id encoding for collection sharing.
  - `analytics_service.dart` — the only file touching Firebase Analytics/Crashlytics. Events go
    through typed param classes (`SearchEventParams`, `GameAddedParams`, …), not loose maps.
- `providers/` — `CollectionState` is immutable with `copyWith`; derived views
  (`contains`, `countByPlatform`, `countByGenre`) live on the state so widgets read them
  straight off the watched value.
- `theme/` — `AppColors` + `AppTheme.dark()`; `platform_palette.dart` maps a console to its
  brand colour; `responsive.dart` drives the phone/tablet nav switch.

### Premium & scan quota

Free users get `kFreeScanLimit` (50) cover scans, counted server-side in Firestore
`users/{uid}.scansUsed` under an **anonymous** Firebase Auth uid (there is no login).

- `ScanQuotaService` is **fail-closed**: any read error emits `ScanQuota(readFailed: true)` with
  `scansUsed` pinned to the limit, so a broken read blocks scanning rather than granting it.
  Use `tryRecordScan()` (transactional check-and-increment) for new call sites;
  `decrementScan()` refunds a scan when the downstream work fails.
- `RevenueCatPurchaseService` is the **only** file importing `purchases_flutter`, and it imports
  no Firestore symbol. It resolves the offering explicitly via `getOfferings().all[...]`, never
  `offerings.current`.
- `PremiumBridge` is the one link between them: it listens to `premiumUpdates()` and calls
  `markPremium()`. Keep purchase and quota code from importing each other directly.
- Known trade-off, documented in `main.dart`: on Android, reinstalling rotates the anonymous uid
  and resets the counter. Accepted, in exchange for no login.

Anonymous sign-in, quota-doc provisioning and the purchase bridge all run in parallel with the
splash screen's minimum display time in `_AppBootstrap._bootstrap()`.

### Localization

`generate: true` + `l10n.yaml`, but the generated `lib/l10n/app_localizations*.dart` files are
**committed**. After editing an `.arb`, run `flutter gen-l10n` and commit the output. Access
strings with `context.l10n` (extension in `lib/l10n/l10n.dart`), never hardcode user-facing text.

## Workflow

The repo uses **OpenSpec** (`openspec/`, CLI on PATH) with the `sai-workflow` schema. Non-trivial
features go through `openspec/changes/{name}/` — `proposal.md` → `design.md`/`specs/` →
`tasks.md` → `implementation.md`, plus review/security/performance/accessibility audits. The
`/sai-*` and `/opsx:*` skills drive this; check `openspec/changes/` for in-flight work before
starting a feature.

## Notes

- `README.md` is partly stale: it says Provider (it's Riverpod), "no login / no backend" (there
  is anonymous Firebase Auth + Firestore for quota), and ML Kit OCR for cover scan (it's OpenAI).
  Trust the code.
- `.codegraph/` exists — prefer `codegraph explore "<question>"` or the `codegraph_explore` MCP
  tool over grep when locating or understanding code.
