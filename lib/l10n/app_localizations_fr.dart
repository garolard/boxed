// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'VG Collection';

  @override
  String get navShelf => 'Étagère';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navScan => 'Scanner';

  @override
  String get navForYou => 'Pour vous';

  @override
  String get shareSubject => 'Ma collection de jeux';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return '$imported jeux importés ($skipped déjà possédés)';
  }

  @override
  String importFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get shelfTitle => 'Mon étagère';

  @override
  String get sharedCollectionsTooltip => 'Collections partagées';

  @override
  String get menuShareQr => 'Partager en code QR';

  @override
  String get menuExport => 'Exporter la collection';

  @override
  String get menuImport => 'Importer la collection';

  @override
  String get yourGames => 'Vos jeux';

  @override
  String get yourGamesSubtitle => 'Touchez une pochette pour voir les détails';

  @override
  String get emptyShelfTitle => 'Votre étagère est vide';

  @override
  String get emptyShelfMessage =>
      'Ajoutez les jeux que vous possédez physiquement. Recherchez par titre ou scannez une pochette avec votre appareil photo — on s\'occupe du reste.';

  @override
  String get emptyShelfAction => 'Rechercher un jeu';

  @override
  String gameRemoved(String name) {
    return '« $name » retiré';
  }

  @override
  String gameAdded(String name) {
    return '« $name » ajouté à la collection';
  }

  @override
  String get availableOn => 'Disponible sur';

  @override
  String get about => 'À propos';

  @override
  String get inYourShelf => 'Dans votre étagère';

  @override
  String get removeFromCollection => 'Retirer de la collection';

  @override
  String get addToShelf => 'Ajouter à l\'étagère';

  @override
  String get recsEmptyTitle => 'Pas encore de recommandations';

  @override
  String get recsEmptyMessage =>
      'Ajoutez quelques jeux à votre étagère et nous vous suggérerons des titres basés sur ce que vous aimez déjà.';

  @override
  String get retry => 'Réessayer';

  @override
  String get recsTryAddingMore =>
      'Pas encore de recommandations — essayez d\'ajouter plus de jeux.';

  @override
  String get featuredTitle => 'En vedette';

  @override
  String get featuredSubtitle => 'Basé sur ce que vous possédez';

  @override
  String get allPicks => 'Toutes les suggestions';

  @override
  String get scanTitle => 'Scanner la pochette';

  @override
  String scanFailed(String error) {
    return 'Échec du scan : $error';
  }

  @override
  String get camera => 'Caméra';

  @override
  String get gallery => 'Galerie';

  @override
  String get noReadableText =>
      'Aucun texte lisible trouvé — essayez une photo plus nette, un meilleur éclairage ou gardez la pochette bien à plat.';

  @override
  String candidatesFound(int count) {
    return '$count TROUVÉS';
  }

  @override
  String get detectedText => 'Texte détecté — touchez pour rechercher';

  @override
  String get scanIntroTitle => 'Lisez une pochette, recherchez sur IGDB';

  @override
  String get scanIntro =>
      'Le texte est lu sur l\'appareil — aucune saisie requise.';

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get noMatches => 'Aucun résultat';

  @override
  String get noMatchesMessage =>
      'Essayez un autre titre, choisissez un autre système ou effacez le filtre de genre.';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get searchHint => 'Titre du jeu…';

  @override
  String get filterSystem => 'SYSTÈME';

  @override
  String get filterGenre => 'GENRE';

  @override
  String get filterAll => 'Tous';

  @override
  String get discoverGames => 'Découvrir des jeux';

  @override
  String get discoverGamesMessage =>
      'Recherchez dans le catalogue IGDB. Filtrez par système ou genre pour affiner.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total jeux · vous en avez $owned';
  }

  @override
  String get scanNoQr => 'Aucun code QR trouvé — essayez une photo plus nette.';

  @override
  String get notVgcQr => 'Ce code QR n\'est pas un partage VG Collection.';

  @override
  String get sharedEmpty => 'La collection partagée est vide.';

  @override
  String get qrDamaged => 'Ce code QR est endommagé ou non pris en charge.';

  @override
  String get deleteSharedTitle => 'Supprimer la collection partagée ?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '« $name » ($count jeux) sera supprimée. Votre propre étagère n\'est pas affectée.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get sharedCollectionsTitle => 'Collections partagées';

  @override
  String get scanACode => 'Scanner un code';

  @override
  String get fromGallery => 'Depuis la galerie';

  @override
  String get nothingSharedTitle => 'Rien de partagé pour l\'instant';

  @override
  String get nothingSharedMessage =>
      'Demandez à un ami d\'ouvrir « Partager en code QR » sur son étagère, puis scannez-le ici pour parcourir sa collection.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count jeux · $date';
  }

  @override
  String get whichVersion => 'Quelle version possédez-vous ?';

  @override
  String get shareQrTitle => 'Partager en code QR';

  @override
  String shareQrSummary(int count) {
    return 'Partage de $count jeux. Un ami le scanne depuis l\'écran Collections partagées.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'Votre étagère contient $total jeux — un code QR en accepte $max, les plus récemment ajoutés sont donc inclus.';
  }

  @override
  String get collectionName => 'Nom de la collection';

  @override
  String get defaultShelfName => 'Mon étagère';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jeux dans votre étagère',
      one: 'jeu dans votre étagère',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'SYSTÈMES TOP';

  @override
  String get unknownPlatform => 'Inconnu';

  @override
  String get owned => 'À VOUS';

  @override
  String get addToShelfShort => 'Ajouter';

  @override
  String get removeShort => 'Retirer';
}
