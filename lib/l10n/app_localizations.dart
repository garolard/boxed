import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'VG Collection'**
  String get appTitle;

  /// No description provided for @navShelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get navShelf;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get navForYou;

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'My game collection'**
  String get shareSubject;

  /// No description provided for @fileLabelJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get fileLabelJson;

  /// No description provided for @importResult.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} games ({skipped} already owned)'**
  String importResult(int imported, int skipped);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @shelfTitle.
  ///
  /// In en, this message translates to:
  /// **'My Shelf'**
  String get shelfTitle;

  /// No description provided for @sharedCollectionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Shared collections'**
  String get sharedCollectionsTooltip;

  /// No description provided for @menuShareQr.
  ///
  /// In en, this message translates to:
  /// **'Share as QR code'**
  String get menuShareQr;

  /// No description provided for @menuExport.
  ///
  /// In en, this message translates to:
  /// **'Export collection'**
  String get menuExport;

  /// No description provided for @menuImport.
  ///
  /// In en, this message translates to:
  /// **'Import collection'**
  String get menuImport;

  /// No description provided for @yourGames.
  ///
  /// In en, this message translates to:
  /// **'Your games'**
  String get yourGames;

  /// No description provided for @yourGamesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a cover to view details'**
  String get yourGamesSubtitle;

  /// No description provided for @emptyShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'Your shelf is empty'**
  String get emptyShelfTitle;

  /// No description provided for @emptyShelfMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the games you own physically. Search by title or scan a cover with your camera — we\'ll handle the rest.'**
  String get emptyShelfMessage;

  /// No description provided for @emptyShelfAction.
  ///
  /// In en, this message translates to:
  /// **'Search a game'**
  String get emptyShelfAction;

  /// No description provided for @gameRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed'**
  String gameRemoved(String name);

  /// No description provided for @gameAdded.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" added to collection'**
  String gameAdded(String name);

  /// No description provided for @availableOn.
  ///
  /// In en, this message translates to:
  /// **'Available on'**
  String get availableOn;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @inYourShelf.
  ///
  /// In en, this message translates to:
  /// **'In your shelf'**
  String get inYourShelf;

  /// No description provided for @removeFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove from collection'**
  String get removeFromCollection;

  /// No description provided for @addToShelf.
  ///
  /// In en, this message translates to:
  /// **'Add to shelf'**
  String get addToShelf;

  /// No description provided for @recsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recommendations yet'**
  String get recsEmptyTitle;

  /// No description provided for @recsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a few games to your shelf and we\'ll suggest titles based on what you already love.'**
  String get recsEmptyMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @recsTryAddingMore.
  ///
  /// In en, this message translates to:
  /// **'No recommendations yet — try adding more games.'**
  String get recsTryAddingMore;

  /// No description provided for @featuredTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredTitle;

  /// No description provided for @featuredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on what you own'**
  String get featuredSubtitle;

  /// No description provided for @allPicks.
  ///
  /// In en, this message translates to:
  /// **'All picks'**
  String get allPicks;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Cover'**
  String get scanTitle;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(String error);

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @noReadableText.
  ///
  /// In en, this message translates to:
  /// **'No readable text found — try a sharper photo, better lighting or hold the cover flat.'**
  String get noReadableText;

  /// No description provided for @candidatesFound.
  ///
  /// In en, this message translates to:
  /// **'{count} FOUND'**
  String candidatesFound(int count);

  /// No description provided for @detectedText.
  ///
  /// In en, this message translates to:
  /// **'Detected text — tap to search'**
  String get detectedText;

  /// No description provided for @scanIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Read a cover, search IGDB'**
  String get scanIntroTitle;

  /// No description provided for @scanIntro.
  ///
  /// In en, this message translates to:
  /// **'The text is read on-device — no typing required.'**
  String get scanIntro;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @noMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different title, pick a different system, or clear the genre filter.'**
  String get noMatchesMessage;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Game title…'**
  String get searchHint;

  /// No description provided for @filterSystem.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get filterSystem;

  /// No description provided for @filterGenre.
  ///
  /// In en, this message translates to:
  /// **'GENRE'**
  String get filterGenre;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @discoverGames.
  ///
  /// In en, this message translates to:
  /// **'Discover games'**
  String get discoverGames;

  /// No description provided for @discoverGamesMessage.
  ///
  /// In en, this message translates to:
  /// **'Search the IGDB catalog. Filter by system or genre to drill down.'**
  String get discoverGamesMessage;

  /// No description provided for @sharedDetailCount.
  ///
  /// In en, this message translates to:
  /// **'{total} games · you own {owned}'**
  String sharedDetailCount(int total, int owned);

  /// No description provided for @scanNoQr.
  ///
  /// In en, this message translates to:
  /// **'No QR code found — try a sharper photo.'**
  String get scanNoQr;

  /// No description provided for @notVgcQr.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a VG Collection share.'**
  String get notVgcQr;

  /// No description provided for @sharedEmpty.
  ///
  /// In en, this message translates to:
  /// **'The shared collection is empty.'**
  String get sharedEmpty;

  /// No description provided for @qrDamaged.
  ///
  /// In en, this message translates to:
  /// **'That QR code is damaged or unsupported.'**
  String get qrDamaged;

  /// No description provided for @deleteSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete shared collection?'**
  String get deleteSharedTitle;

  /// No description provided for @deleteSharedMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" ({count} games) will be removed. Your own shelf is not affected.'**
  String deleteSharedMessage(String name, int count);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @sharedCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared Collections'**
  String get sharedCollectionsTitle;

  /// No description provided for @scanACode.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get scanACode;

  /// No description provided for @fromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get fromGallery;

  /// No description provided for @nothingSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared yet'**
  String get nothingSharedTitle;

  /// No description provided for @nothingSharedMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask a friend to open \"Share as QR code\" on their shelf, then scan it here to browse their collection.'**
  String get nothingSharedMessage;

  /// No description provided for @sharedRowMeta.
  ///
  /// In en, this message translates to:
  /// **'{count} games · {date}'**
  String sharedRowMeta(int count, String date);

  /// No description provided for @whichVersion.
  ///
  /// In en, this message translates to:
  /// **'Which version do you own?'**
  String get whichVersion;

  /// No description provided for @shareQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Share as QR code'**
  String get shareQrTitle;

  /// No description provided for @shareQrSummary.
  ///
  /// In en, this message translates to:
  /// **'Sharing {count} games. A friend scans this from the Shared collections screen.'**
  String shareQrSummary(int count);

  /// No description provided for @shareQrCapped.
  ///
  /// In en, this message translates to:
  /// **'Your shelf has {total} games — a QR code fits {max}, so the most recently added ones are included.'**
  String shareQrCapped(int total, int max);

  /// No description provided for @collectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionName;

  /// No description provided for @defaultShelfName.
  ///
  /// In en, this message translates to:
  /// **'My shelf'**
  String get defaultShelfName;

  /// No description provided for @gamesInShelf.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{game in your shelf} other{games in your shelf}}'**
  String gamesInShelf(int count);

  /// No description provided for @topSystems.
  ///
  /// In en, this message translates to:
  /// **'TOP SYSTEMS'**
  String get topSystems;

  /// No description provided for @unknownPlatform.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownPlatform;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'OWNED'**
  String get owned;

  /// No description provided for @addToShelfShort.
  ///
  /// In en, this message translates to:
  /// **'Add to shelf'**
  String get addToShelfShort;

  /// No description provided for @removeShort.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
