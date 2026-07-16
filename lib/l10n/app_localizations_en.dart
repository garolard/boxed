// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VG Collection';

  @override
  String get navShelf => 'Shelf';

  @override
  String get navSearch => 'Search';

  @override
  String get navScan => 'Scan';

  @override
  String get navForYou => 'For you';

  @override
  String get shareSubject => 'My game collection';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return 'Imported $imported games ($skipped already owned)';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get shelfTitle => 'My Shelf';

  @override
  String get sharedCollectionsTooltip => 'Shared collections';

  @override
  String get menuShareQr => 'Share as QR code';

  @override
  String get menuExport => 'Export collection';

  @override
  String get menuImport => 'Import collection';

  @override
  String get yourGames => 'Your games';

  @override
  String get yourGamesSubtitle => 'Tap a cover to view details';

  @override
  String get emptyShelfTitle => 'Your shelf is empty';

  @override
  String get emptyShelfMessage =>
      'Add the games you own physically. Search by title or scan a cover with your camera — we\'ll handle the rest.';

  @override
  String get emptyShelfAction => 'Search a game';

  @override
  String gameRemoved(String name) {
    return '\"$name\" removed';
  }

  @override
  String gameAdded(String name) {
    return '\"$name\" added to collection';
  }

  @override
  String get availableOn => 'Available on';

  @override
  String get about => 'About';

  @override
  String get inYourShelf => 'In your shelf';

  @override
  String get removeFromCollection => 'Remove from collection';

  @override
  String get addToShelf => 'Add to shelf';

  @override
  String get recsEmptyTitle => 'No recommendations yet';

  @override
  String get recsEmptyMessage =>
      'Add a few games to your shelf and we\'ll suggest titles based on what you already love.';

  @override
  String get retry => 'Retry';

  @override
  String get recsTryAddingMore =>
      'No recommendations yet — try adding more games.';

  @override
  String get featuredTitle => 'Featured';

  @override
  String get featuredSubtitle => 'Based on what you own';

  @override
  String get allPicks => 'All picks';

  @override
  String get scanTitle => 'Scan Cover';

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get noReadableText =>
      'No readable text found — try a sharper photo, better lighting or hold the cover flat.';

  @override
  String candidatesFound(int count) {
    return '$count FOUND';
  }

  @override
  String get detectedText => 'Detected text — tap to search';

  @override
  String get scanIntroTitle => 'Read a cover, search IGDB';

  @override
  String get scanIntro => 'The text is read on-device — no typing required.';

  @override
  String get searchTitle => 'Search';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noMatches => 'No matches';

  @override
  String get noMatchesMessage =>
      'Try a different title, pick a different system, or clear the genre filter.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get searchHint => 'Game title…';

  @override
  String get filterSystem => 'SYSTEM';

  @override
  String get filterGenre => 'GENRE';

  @override
  String get filterAll => 'All';

  @override
  String get discoverGames => 'Discover games';

  @override
  String get discoverGamesMessage =>
      'Search the IGDB catalog. Filter by system or genre to drill down.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total games · you own $owned';
  }

  @override
  String get scanNoQr => 'No QR code found — try a sharper photo.';

  @override
  String get notVgcQr => 'That QR code is not a VG Collection share.';

  @override
  String get sharedEmpty => 'The shared collection is empty.';

  @override
  String get qrDamaged => 'That QR code is damaged or unsupported.';

  @override
  String get deleteSharedTitle => 'Delete shared collection?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '\"$name\" ($count games) will be removed. Your own shelf is not affected.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get sharedCollectionsTitle => 'Shared Collections';

  @override
  String get scanACode => 'Scan a code';

  @override
  String get fromGallery => 'From gallery';

  @override
  String get nothingSharedTitle => 'Nothing shared yet';

  @override
  String get nothingSharedMessage =>
      'Ask a friend to open \"Share as QR code\" on their shelf, then scan it here to browse their collection.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count games · $date';
  }

  @override
  String get whichVersion => 'Which version do you own?';

  @override
  String get shareQrTitle => 'Share as QR code';

  @override
  String shareQrSummary(int count) {
    return 'Sharing $count games. A friend scans this from the Shared collections screen.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'Your shelf has $total games — a QR code fits $max, so the most recently added ones are included.';
  }

  @override
  String get collectionName => 'Collection name';

  @override
  String get defaultShelfName => 'My shelf';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'games in your shelf',
      one: 'game in your shelf',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'TOP SYSTEMS';

  @override
  String get unknownPlatform => 'Unknown';

  @override
  String get owned => 'OWNED';

  @override
  String get addToShelfShort => 'Add to shelf';

  @override
  String get removeShort => 'Remove';
}
