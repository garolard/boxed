# Boxed — App Store Listing (Apple)

Store URL: *(to be created — Apple App Store)*

---

## App Name (30 characters max)

```
Boxed: Game Shelf Tracker
```
> 21 characters. Adds "boxed", "game", "shelf", "tracker" to the title index.

## Subtitle (30 characters max)

```
Track your physical games
```
> 26 characters. No keyword overlap with title.

## Promotional Text (170 characters max, refresh anytime, not indexed)

```
New: scan a game cover with your camera and we'll find it on IGDB — no typing. Plus share your entire shelf as a QR code friends can scan.
```
> 168 characters.

## Keywords field (100 bytes max, hidden, not visible to users)

```
collection,retro,cartridge,nintendo,playstation,sega,scan,cover,catalog,manage,inventory,ps4,wii
```
> 97 bytes. Verified: no overlap with title/subtitle words. All commas, no spaces.

## Description (long, not indexed for Apple search — optimize for conversion)

```
Boxed is the private way to track your physical video game collection.

No account. No cloud. Your shelf lives on your phone.

## Scan a cover, skip the typing

Point your camera at any game box. On-device OCR reads the title and looks it up on IGDB — one tap and it's on your shelf.

## Your shelf at a glance

Total games, counts per system and per genre, your top platforms — all on the home screen, all offline.

## Search 260,000+ games

Powered by the IGDB database. Filter by console (NES, SNES, PS1, PS5, Switch, Game Boy, Saturn, Dreamcast and more) or genre, then add the version you actually own.

## Discover your next game

"For You" recommends titles based on what you already own — games suggested by several of your favorites rank first.

## Share your shelf as a QR code

Show up to 150 games as a single QR. A friend scans it and browses your collection without it ever touching their own shelf.

## Export & import

Back up your collection as a JSON file, or move it to a new phone. Imports merge and skip games you already own.

## Privacy by design

- No login, no backend
- All data stored locally in SQLite
- Cover text recognized on-device with ML Kit
- The only network call is to IGDB for game metadata

Works offline — your shelf is always available, even with no connection.

For collectors of cartridges, discs, and boxes. From NES to PS5.
```

## What's New (version 1.0)

```
Welcome to Boxed 1.0 — your physical game collection, finally organized.
```

## Category

- **Primary:** Lifestyle
- **Secondary:** Reference
- **Age rating:** 4+ (no user-generated content, no online interaction)

## Screenshots needed (6.7" iPhone, 1290×2796)

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

> First 3 are visible in search results without scrolling — they must be the strongest.

## In-App Purchases

None. App is free with all features included.

## Pricing

Free. Might be monetized with a one-time unlock in the future.

## Developer

Apps4Fun

## Localizations

- English (US) — primary
- Spanish — *(in-app already supported)*
- French — *(in-app already supported)*

## Privacy Policy

*(Draft a simple policy: data is stored on-device, IGDB API receives search queries only, no analytics, no tracking.)*

## Review prompt

After adding 5 games, show a 5-star rating prompt using SKStoreReviewController. Max 3 prompts per 365 days.

## Filing notes

- The app uses the camera for cover scanning — already declared in `NSCameraUsageDescription`.
- The app uses ML Kit text recognition — this is on-device, download required at install/first use (add to description if reviewer questions "downloads" in review process).
- The QR scanning uses google_mlkit_barcode_scanning — on-device, no data sent.