# Boxed — Google Play Listing

Store URL: *(to be created — Google Play)*

---

## App Name (30 characters max)

```
Boxed: Game Shelf Tracker
```
> 21 characters. Same as Apple for consistency.

## Short Description (80 characters max)

```
Track your physical video game collection. Scan covers, no typing. 100% private.
```
> 78 characters. Indexed for search.

## Full Description (4000 characters max, indexed for search)

```
Boxed is a private, on-device tracker for your physical video game collection. No account, no cloud, no ads — your shelf lives on your phone.

Whether you collect retro cartridges, disc-based classics, or current-gen boxes, Boxed helps you catalog every game you own and discover what to play next.

## Scan a cover, skip the typing

Point your camera at any game box and on-device OCR reads the title for you. Boxed looks it up on the IGDB database and adds it to your collection in one tap — no manual entry, no typing. The text recognition runs entirely on your device.

## Your collection at a glance

The home screen shows your total game count, the number of games per system, and the number per genre, plus your most-played platforms — all offline, all instant.

## Search the IGDB game database

Search over 260,000 games. Filter by console — NES, SNES, Nintendo 64, GameCube, Wii, Switch, Game Boy, GBC, GBA, Nintendo DS, 3DS, PlayStation, PS2, PS3, PS4, PS5, PSP, Vita, Xbox, Xbox 360, Xbox One, Xbox Series, Master System, Mega Drive, Saturn, Dreamcast, Atari 2600, Neo Geo, PC and more — or filter by genre to find exactly what you own.

## Add the version you own

When a game shipped on multiple systems, Boxed lets you pick which version is on your shelf. Your collection reflects your actual games, not just titles.

## Discover your next game

The "For You" tab recommends games based on what you already own. Recommendations come from IGDB's similar-games data — titles suggested by several of your games rank first, ties broken by rating.

## Share your collection as a QR code

Share up to 150 games as a single QR code. A friend scans it from their phone and can browse your collection — without it ever touching their own shelf. Great for showing off your collection at meetups or trades.

## Export & import

Back up your collection as a JSON file, or move it to a new phone. Imports merge automatically and skip games you already own.

## Privacy by design

- No login and no account required
- All collection data stored locally in SQLite
- Cover text recognized on your device with ML Kit
- The only network request is to IGDB for game metadata
- Works offline — your shelf is always available

## Who it's for

Collectors of physical video games: retro game collectors, cartridge collectors, disc-game collectors, CIB collectors, and anyone building a library of boxed games across consoles and handhelds. From the NES to the PS5, from the Game Boy to the Switch.

Keywords: video game collection, game tracker, physical games, retro game collector, game shelf, game catalog, game inventory, IGDB, cartridge, boxed games, complete in box, CIB, NES, SNES, PlayStation, Nintendo, Sega, game database.
```

> ~3,600 characters, naturally including core terms ("game collection", "collection", "retro", "cartridge", "catalog", "video game") at target density without stuffing.

## Category

- **App category:** Lifestyle *(or Entertainment — Lifestyle is less competitive)*
- **Tags:** Collector, Retro, Catalog, Library

## Feature Graphic (1024×500, exact)

> Required for featuring on Google Play.
> Design: dark `#0E0E16` background with the three stacked box-spines mark centered-left, the text `BOXED` in Bungee (or similar chunky typeface) on the right in violet `#A78BFA`. Soft outer glow. No small text.

## App Icon (512×512, for Play Store listing)

> Same 1024 master, exported to 512.

## Screenshots needed (1080×1920 or 1200×2000)

| # | Screen | Caption (headline) | Sub-line |
|---|---|---|---|
| 1 | My Shelf — stats dashboard + cover grid | Your shelf, beautifully organized | Counts by system & genre, all on-device |
| 2 | Search — filters open, results grid | Search 260k+ games via IGDB | Filter by console, genre, or both |
| 3 | Scan Cover — mid-scan, detected titles | Snap a cover, we find the game | On-device OCR, no typing |
| 4 | Game detail — back-cover blurb + platforms | Rich metadata, no login | Cover, synopsis, platforms, genres |
| 5 | For You — recommendations screen | Discover your next favorite | Picks based on what you already own |
| 6 | Share QR sheet — QR code on screen | Share your whole shelf as a QR code | Friends scan it to browse your collection |
| 7 | Shared Collections — a friend's shelf | Browse a friend's collection | Without touching your own shelf |
| 8 | Empty Shelf — dark gradient visible | Private by design | No account, no cloud, your data stays on your phone |

> Max 8 on Google Play. These 8 cover both stores.

## Pricing

Free. Might be monetized with a one-time unlock in the future.

## In-App Purchases

No. App is free with all features included.

## Content Rating

- **Violence:** None (the app catalogues games, the app itself contains no graphic content)
- File as: Everyone
- Actual maximum rating shown on the app's store will be based on Google Play's questionnaire responses about the app, not the games it tracks

## Data Safety (Google Play)

| Data collected | Purpose | Encrypted in transit? | Can users request deletion? |
|---|---|---|---|
| *(none / no data collected)* | — | N/A | N/A |

> **Important:** All user data (collection, cover scans, QR imports) is stored on-device only in SQLite.
> The app makes one network request to IGDB (Twitch / igdb.com) with the search query title.
> No user account, no analytics, no advertising SDKs, no data shared with third parties.
> Answer the Data Safety form: "No data collected". Verify and confirm before submission.

## Privacy Policy

*(Draft a simple policy URL: data stored on-device, IGDB API receives search queries only, no analytics, no tracking. The policy must be live at a public URL for Google Play listing.)*

## App permissions

| Permission | Purpose |
|---|---|
| `android.permission.CAMERA` | Scan game covers and QR codes |

## Minimum Android version

Min color/SDK: Follow `flutter.minSdkVersion` (autogenerated — verify in `android/app/build.gradle.kts`).

## Release notes (version 1.0)

```
Welcome to Boxed 1.0 — your physical game collection, finally organized.
```

## APK vs AAB

Upload `.aab` (App Bundle). Google Play will generate the split APKs.