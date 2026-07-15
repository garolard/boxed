/// Curated list of common physical-media platforms with their IGDB ids.
/// Full list: https://api-docs.igdb.com/#platform
class PlatformFilter {
  final int id;
  final String shortName;
  final String fullName;

  const PlatformFilter(this.id, this.shortName, this.fullName);
}

const List<PlatformFilter> kPlatforms = [
  PlatformFilter(18, 'NES', 'Nintendo Entertainment System'),
  PlatformFilter(19, 'SNES', 'Super Nintendo'),
  PlatformFilter(4, 'N64', 'Nintendo 64'),
  PlatformFilter(21, 'NGC', 'GameCube'),
  PlatformFilter(5, 'Wii', 'Nintendo Wii'),
  PlatformFilter(41, 'Wii U', 'Nintendo Wii U'),
  PlatformFilter(130, 'Switch', 'Nintendo Switch'),
  PlatformFilter(33, 'GB', 'Game Boy'),
  PlatformFilter(22, 'GBC', 'Game Boy Color'),
  PlatformFilter(24, 'GBA', 'Game Boy Advance'),
  PlatformFilter(20, 'NDS', 'Nintendo DS'),
  PlatformFilter(37, '3DS', 'Nintendo 3DS'),
  PlatformFilter(7, 'PS1', 'PlayStation'),
  PlatformFilter(8, 'PS2', 'PlayStation 2'),
  PlatformFilter(9, 'PS3', 'PlayStation 3'),
  PlatformFilter(48, 'PS4', 'PlayStation 4'),
  PlatformFilter(167, 'PS5', 'PlayStation 5'),
  PlatformFilter(38, 'PSP', 'PlayStation Portable'),
  PlatformFilter(46, 'Vita', 'PlayStation Vita'),
  PlatformFilter(11, 'Xbox', 'Xbox'),
  PlatformFilter(12, 'X360', 'Xbox 360'),
  PlatformFilter(49, 'XOne', 'Xbox One'),
  PlatformFilter(169, 'XSX', 'Xbox Series X|S'),
  PlatformFilter(64, 'SMS', 'Sega Master System'),
  PlatformFilter(29, 'MD', 'Sega Mega Drive/Genesis'),
  PlatformFilter(32, 'Saturn', 'Sega Saturn'),
  PlatformFilter(23, 'DC', 'Sega Dreamcast'),
  PlatformFilter(35, 'GG', 'Sega Game Gear'),
  PlatformFilter(59, '2600', 'Atari 2600'),
  PlatformFilter(80, 'NG', 'Neo Geo AES'),
  PlatformFilter(6, 'PC', 'PC (Windows)'),
];
