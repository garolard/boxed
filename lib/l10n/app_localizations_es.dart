// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'VG Collection';

  @override
  String get navShelf => 'Estantería';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navScan => 'Escanear';

  @override
  String get navForYou => 'Para ti';

  @override
  String get shareSubject => 'Mi colección de juegos';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return 'Se importaron $imported juegos ($skipped ya los tenías)';
  }

  @override
  String importFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get shelfTitle => 'Mi estantería';

  @override
  String get sharedCollectionsTooltip => 'Colecciones compartidas';

  @override
  String get menuShareQr => 'Compartir como código QR';

  @override
  String get menuExport => 'Exportar colección';

  @override
  String get menuImport => 'Importar colección';

  @override
  String get yourGames => 'Tus juegos';

  @override
  String get yourGamesSubtitle => 'Toca una portada para ver los detalles';

  @override
  String get emptyShelfTitle => 'Tu estantería está vacía';

  @override
  String get emptyShelfMessage =>
      'Añade los juegos que tienes físicamente. Busca por título o escanea una portada con tu cámara — nosotros nos encargamos del resto.';

  @override
  String get emptyShelfAction => 'Buscar un juego';

  @override
  String gameRemoved(String name) {
    return '\"$name\" eliminado';
  }

  @override
  String gameAdded(String name) {
    return '\"$name\" añadido a la colección';
  }

  @override
  String get availableOn => 'Disponible en';

  @override
  String get about => 'Acerca de';

  @override
  String get inYourShelf => 'En tu estantería';

  @override
  String get removeFromCollection => 'Quitar de la colección';

  @override
  String get addToShelf => 'Añadir a la estantería';

  @override
  String get recsEmptyTitle => 'Aún no hay recomendaciones';

  @override
  String get recsEmptyMessage =>
      'Añade algunos juegos a tu estantería y te sugeriremos títulos basados en lo que ya te gusta.';

  @override
  String get retry => 'Reintentar';

  @override
  String get recsTryAddingMore =>
      'Aún no hay recomendaciones — prueba a añadir más juegos.';

  @override
  String get featuredTitle => 'Destacados';

  @override
  String get featuredSubtitle => 'Basado en lo que tienes';

  @override
  String get allPicks => 'Todas las sugerencias';

  @override
  String get scanTitle => 'Escanear portada';

  @override
  String scanFailed(String error) {
    return 'Error al escanear: $error';
  }

  @override
  String get camera => 'Cámara';

  @override
  String get gallery => 'Galería';

  @override
  String get noReadableText =>
      'No se encontró texto legible — prueba con una foto más nítida, mejor luz o manteniendo la portada plana.';

  @override
  String candidatesFound(int count) {
    return '$count ENCONTRADOS';
  }

  @override
  String get detectedText => 'Texto detectado — toca para buscar';

  @override
  String get scanIntroTitle => 'Lee una portada, busca en IGDB';

  @override
  String get scanIntro =>
      'El texto se lee en el dispositivo — sin necesidad de escribir.';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get noMatches => 'Sin resultados';

  @override
  String get noMatchesMessage =>
      'Prueba con otro título, elige otro sistema o quita el filtro de género.';

  @override
  String get clearFilters => 'Quitar filtros';

  @override
  String get searchHint => 'Título del juego…';

  @override
  String get filterSystem => 'SISTEMA';

  @override
  String get filterGenre => 'GÉNERO';

  @override
  String get filterAll => 'Todos';

  @override
  String get discoverGames => 'Descubre juegos';

  @override
  String get discoverGamesMessage =>
      'Busca en el catálogo de IGDB. Filtra por sistema o género para afinar.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total juegos · tienes $owned';
  }

  @override
  String get scanNoQr =>
      'No se encontró ningún código QR — prueba con una foto más nítida.';

  @override
  String get notVgcQr =>
      'Ese código QR no es un enlace compartido de VG Collection.';

  @override
  String get sharedEmpty => 'La colección compartida está vacía.';

  @override
  String get qrDamaged => 'Ese código QR está dañado o no es compatible.';

  @override
  String get deleteSharedTitle => '¿Eliminar la colección compartida?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '\"$name\" ($count juegos) se eliminará. Tu propia estantería no se verá afectada.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get sharedCollectionsTitle => 'Colecciones compartidas';

  @override
  String get scanACode => 'Escanear un código';

  @override
  String get fromGallery => 'Desde la galería';

  @override
  String get nothingSharedTitle => 'Aún no hay nada compartido';

  @override
  String get nothingSharedMessage =>
      'Pide a un amigo que abra \"Compartir como código QR\" en su estantería y luego escanéalo aquí para explorarla.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count juegos · $date';
  }

  @override
  String get whichVersion => '¿Qué versión tienes?';

  @override
  String get shareQrTitle => 'Compartir como código QR';

  @override
  String shareQrSummary(int count) {
    return 'Compartiendo $count juegos. Un amigo lo escanea desde la pantalla de Colecciones compartidas.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'Tu estantería tiene $total juegos — un código QR admite $max, así que se incluyen los añadidos más recientemente.';
  }

  @override
  String get collectionName => 'Nombre de la colección';

  @override
  String get defaultShelfName => 'Mi estantería';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'juegos en tu estantería',
      one: 'juego en tu estantería',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'SISTEMAS TOP';

  @override
  String get unknownPlatform => 'Desconocido';

  @override
  String get owned => 'TUYO';

  @override
  String get addToShelfShort => 'Añadir';

  @override
  String get removeShort => 'Quitar';
}
