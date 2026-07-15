# VG Collection

Manage your physical videogame collection. All data lives on the device;
the only remote service used is the [IGDB API](https://api-docs.igdb.com/)
for game metadata. No login, no backend.

## Features

- **Collection summary** (first screen): total games, counts per system and
  per genre, and the full list of owned games.
- **Search** IGDB by title, with filters for system (GB, GBC, NES, …) and genre.
- **Add / remove** games. When a game shipped on several systems you pick
  which version you own.
- **Recommendations**: built from IGDB's `similar_games` of the titles you
  own — games suggested by several of your games rank first, ties broken by
  rating.
- **Cover scan**: photograph a game cover (or pick one from the gallery);
  on-device ML Kit OCR extracts the title candidates and one tap searches
  IGDB — no typing.
- **Export / import** the collection as a JSON file (share sheet to export,
  file picker to import; imports merge and skip games you already own).
- **Share via QR code**: show your shelf as a QR code (up to 150 games —
  the code carries only compact game/platform ids, the receiver re-fetches
  metadata from IGDB). Scanned collections are saved under a name in a
  separate "Shared collections" area — they never touch your own shelf,
  but you can add individual games from them.

## Setup

1. Create a `.env` file at the project root with your IGDB (Twitch) app
   credentials:

   ```
   IGDB_CLIENT_ID=your_client_id
   IGDB_SECRET_ID=your_client_secret
   ```

2. `flutter pub get`
3. `flutter run` on an Android or iOS device. The cover scan feature needs a
   real device (camera + ML Kit).

## Architecture

```
lib/
├── main.dart                        # dotenv bootstrap, theming, Provider setup
├── models/
│   ├── game.dart                    # Game model (IGDB parsing + JSON round-trip)
│   └── platforms.dart               # Curated IGDB platform ids for the filter
├── services/
│   ├── igdb_service.dart            # Twitch OAuth + IGDB Apicalypse queries
│   ├── collection_repository.dart   # sqflite persistence + JSON export/import
│   └── cover_scan_service.dart      # image_picker + ML Kit text recognition
├── providers/
│   └── collection_provider.dart     # App state + recommendation ranking
├── screens/                         # Collection, Search, Scan, For you, Detail
└── widgets/
    └── game_tile.dart               # Shared list tile + add-to-collection flow
```

Storage: each owned game is a row in a local SQLite database holding a full
JSON snapshot of its IGDB metadata, so the collection screen works offline.
The IGDB app token is cached in SharedPreferences and refreshed automatically.

## Tests

```
flutter test
```
