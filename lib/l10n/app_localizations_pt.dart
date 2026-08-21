// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Boxed';

  @override
  String get navShelf => 'Prateleira';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navScan => 'Escanear';

  @override
  String get navForYou => 'Para você';

  @override
  String get shareSubject => 'Minha coleção de jogos';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return '$imported jogos importados ($skipped já estavam na coleção)';
  }

  @override
  String importFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get shelfTitle => 'Minha Prateleira';

  @override
  String get sharedCollectionsTooltip => 'Coleções compartilhadas';

  @override
  String get menuShareQr => 'Compartilhar como QR code';

  @override
  String get menuExport => 'Exportar coleção';

  @override
  String get menuImport => 'Importar coleção';

  @override
  String get yourGames => 'Seus jogos';

  @override
  String get yourGamesSubtitle => 'Toque numa capa para ver os detalhes';

  @override
  String get emptyShelfTitle => 'Sua prateleira está vazia';

  @override
  String get emptyShelfMessage =>
      'Adicione os jogos que você tem fisicamente. Busque pelo título ou escaneie uma capa com a câmera — nós cuidamos do resto.';

  @override
  String get emptyShelfAction => 'Buscar um jogo';

  @override
  String gameRemoved(String name) {
    return '\"$name\" removido';
  }

  @override
  String gameAdded(String name) {
    return '\"$name\" adicionado à coleção';
  }

  @override
  String get removeGameTitle => 'Remover jogo?';

  @override
  String removeGameMessage(String name) {
    return '\"$name\" será removido da sua prateleira.';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get availableOn => 'Disponível em';

  @override
  String get about => 'Sobre';

  @override
  String get inYourShelf => 'Na sua prateleira';

  @override
  String get removeFromCollection => 'Remover da coleção';

  @override
  String get addToShelf => 'Adicionar à prateleira';

  @override
  String get recsEmptyTitle => 'Ainda sem recomendações';

  @override
  String get recsEmptyMessage =>
      'Adicione alguns jogos à sua prateleira e nós sugeriremos títulos baseados no que você já curte.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get recsTryAddingMore =>
      'Ainda sem recomendações — tente adicionar mais jogos.';

  @override
  String get featuredTitle => 'Em destaque';

  @override
  String get featuredSubtitle => 'Baseado no que você possui';

  @override
  String get allPicks => 'Todas as sugestões';

  @override
  String get scanTitle => 'Escanear Capa';

  @override
  String scanFailed(String error) {
    return 'Falha no escaneamento: $error';
  }

  @override
  String get camera => 'Câmera';

  @override
  String get gallery => 'Galeria';

  @override
  String get noReadableText =>
      'Nenhum texto legível encontrado — tente uma foto mais nítida, melhor iluminação ou segure a capa plana.';

  @override
  String candidatesFound(int count) {
    return '$count ENCONTRADO';
  }

  @override
  String get detectedText => 'Texto detectado — toque para buscar';

  @override
  String get scanIntroTitle => 'Leia uma capa, busque na IGDB';

  @override
  String get scanIntro => 'O texto é lido no dispositivo — sem digitar.';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String get noMatchesMessage =>
      'Tente um título diferente, escolha outro sistema ou limpe o filtro de gênero.';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get searchHint => 'Título do jogo…';

  @override
  String get filterSystem => 'SISTEMA';

  @override
  String get filterGenre => 'GÊNERO';

  @override
  String get filterAll => 'Todos';

  @override
  String get discoverGames => 'Descubra jogos';

  @override
  String get discoverGamesMessage =>
      'Busque no catálogo da IGDB. Filtre por sistema ou gênero para refinar.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total jogos · você tem $owned';
  }

  @override
  String get scanNoQr =>
      'Nenhum QR code encontrado — tente uma foto mais nítida.';

  @override
  String get notVgcQr => 'Esse QR code não é de um compartilhamento do Boxed.';

  @override
  String get sharedEmpty => 'A coleção compartilhada está vazia.';

  @override
  String get qrDamaged => 'Esse QR code está danificado ou não é suportado.';

  @override
  String get deleteSharedTitle => 'Excluir coleção compartilhada?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '\"$name\" ($count jogos) será removido. Sua própria prateleira não será afetada.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get sharedCollectionsTitle => 'Coleções Compartilhadas';

  @override
  String get scanACode => 'Escanear';

  @override
  String get fromGallery => 'Galeria';

  @override
  String get nothingSharedTitle => 'Nada compartilhado ainda';

  @override
  String get nothingSharedMessage =>
      'Peça a um amigo para abrir \"Compartilhar como QR code\" na prateleira dele e escaneie aqui para ver a coleção dele.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count jogos · $date';
  }

  @override
  String get whichVersion => 'Qual versão você possui?';

  @override
  String get shareQrTitle => 'Compartilhar como QR code';

  @override
  String shareQrSummary(int count) {
    return 'Compartilhando $count jogos. Um amigo escaneia isso na tela de Coleções compartilhadas.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'Sua prateleira tem $total jogos — um QR code comporta $max, então os adicionados mais recentemente estão incluídos.';
  }

  @override
  String get collectionName => 'Nome da coleção';

  @override
  String get defaultShelfName => 'Minha prateleira';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jogos na sua prateleira',
      one: 'jogo na sua prateleira',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'PRINCIPAIS SISTEMAS';

  @override
  String get unknownPlatform => 'Desconhecido';

  @override
  String get paywallTitle => 'Desbloqueie Escaneamentos Ilimitados';

  @override
  String get paywallSubtitle =>
      'Escaneie quantas capas de jogos quiser com uma compra única.';

  @override
  String get paywallFeature1 => 'Escaneamentos de capa ilimitados';

  @override
  String get paywallFeature2 => 'Precisão de reconhecimento avançada';

  @override
  String get paywallFeature3 => 'Acesso prioritário à visão da OpenAI';

  @override
  String get paywallCta => 'Desbloquear';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallComingSoon => 'Em breve — fique ligado!';

  @override
  String paywallCtaPrice(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get paywallCtaFallback => 'Desbloquear Premium';

  @override
  String get paywallCtaUnavailable => 'Temporariamente indisponível';

  @override
  String get paywallPurchaseError => 'Falha na compra. Tente novamente.';

  @override
  String get paywallNothingToRestore => 'Nenhuma compra para restaurar.';

  @override
  String get paywallRestoreError => 'Falha na restauração. Tente novamente.';

  @override
  String freeScansRemaining(int left, int total) {
    return '$left de $total escaneamentos grátis restantes';
  }

  @override
  String get owned => 'NA COLEÇÃO';

  @override
  String get addToShelfShort => 'Adicionar';

  @override
  String get removeShort => 'Remover';

  @override
  String get menuSelectGames => 'Selecionar jogos';

  @override
  String nSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String removeNGamesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remover $count jogos?',
      one: 'Remover 1 jogo?',
    );
    return '$_temp0';
  }

  @override
  String get removeNGamesMessage =>
      'Estes jogos serão removidos da sua prateleira.';

  @override
  String gamesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos removidos',
      one: '1 jogo removido',
    );
    return '$_temp0';
  }
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Boxed';

  @override
  String get navShelf => 'Prateleira';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navScan => 'Escanear';

  @override
  String get navForYou => 'Para você';

  @override
  String get shareSubject => 'Minha coleção de jogos';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return '$imported jogos importados ($skipped já estavam na coleção)';
  }

  @override
  String importFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get shelfTitle => 'Minha Prateleira';

  @override
  String get sharedCollectionsTooltip => 'Coleções compartilhadas';

  @override
  String get menuShareQr => 'Compartilhar como QR code';

  @override
  String get menuExport => 'Exportar coleção';

  @override
  String get menuImport => 'Importar coleção';

  @override
  String get yourGames => 'Seus jogos';

  @override
  String get yourGamesSubtitle => 'Toque numa capa para ver os detalhes';

  @override
  String get emptyShelfTitle => 'Sua prateleira está vazia';

  @override
  String get emptyShelfMessage =>
      'Adicione os jogos que você tem fisicamente. Busque pelo título ou escaneie uma capa com a câmera — nós cuidamos do resto.';

  @override
  String get emptyShelfAction => 'Buscar um jogo';

  @override
  String gameRemoved(String name) {
    return '\"$name\" removido';
  }

  @override
  String gameAdded(String name) {
    return '\"$name\" adicionado à coleção';
  }

  @override
  String get removeGameTitle => 'Remover jogo?';

  @override
  String removeGameMessage(String name) {
    return '\"$name\" será removido da sua prateleira.';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get availableOn => 'Disponível em';

  @override
  String get about => 'Sobre';

  @override
  String get inYourShelf => 'Na sua prateleira';

  @override
  String get removeFromCollection => 'Remover da coleção';

  @override
  String get addToShelf => 'Adicionar à prateleira';

  @override
  String get recsEmptyTitle => 'Ainda sem recomendações';

  @override
  String get recsEmptyMessage =>
      'Adicione alguns jogos à sua prateleira e nós sugeriremos títulos baseados no que você já curte.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get recsTryAddingMore =>
      'Ainda sem recomendações — tente adicionar mais jogos.';

  @override
  String get featuredTitle => 'Em destaque';

  @override
  String get featuredSubtitle => 'Baseado no que você possui';

  @override
  String get allPicks => 'Todas as sugestões';

  @override
  String get scanTitle => 'Escanear Capa';

  @override
  String scanFailed(String error) {
    return 'Falha no escaneamento: $error';
  }

  @override
  String get camera => 'Câmera';

  @override
  String get gallery => 'Galeria';

  @override
  String get noReadableText =>
      'Nenhum texto legível encontrado — tente uma foto mais nítida, melhor iluminação ou segure a capa plana.';

  @override
  String candidatesFound(int count) {
    return '$count ENCONTRADO';
  }

  @override
  String get detectedText => 'Texto detectado — toque para buscar';

  @override
  String get scanIntroTitle => 'Leia uma capa, busque na IGDB';

  @override
  String get scanIntro => 'O texto é lido no dispositivo — sem digitar.';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String get noMatchesMessage =>
      'Tente um título diferente, escolha outro sistema ou limpe o filtro de gênero.';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get searchHint => 'Título do jogo…';

  @override
  String get filterSystem => 'SISTEMA';

  @override
  String get filterGenre => 'GÊNERO';

  @override
  String get filterAll => 'Todos';

  @override
  String get discoverGames => 'Descubra jogos';

  @override
  String get discoverGamesMessage =>
      'Busque no catálogo da IGDB. Filtre por sistema ou gênero para refinar.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total jogos · você tem $owned';
  }

  @override
  String get scanNoQr =>
      'Nenhum QR code encontrado — tente uma foto mais nítida.';

  @override
  String get notVgcQr => 'Esse QR code não é de um compartilhamento do Boxed.';

  @override
  String get sharedEmpty => 'A coleção compartilhada está vazia.';

  @override
  String get qrDamaged => 'Esse QR code está danificado ou não é suportado.';

  @override
  String get deleteSharedTitle => 'Excluir coleção compartilhada?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '\"$name\" ($count jogos) será removido. Sua própria prateleira não será afetada.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get sharedCollectionsTitle => 'Coleções Compartilhadas';

  @override
  String get scanACode => 'Escanear';

  @override
  String get fromGallery => 'Galeria';

  @override
  String get nothingSharedTitle => 'Nada compartilhado ainda';

  @override
  String get nothingSharedMessage =>
      'Peça a um amigo para abrir \"Compartilhar como QR code\" na prateleira dele e escaneie aqui para ver a coleção dele.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count jogos · $date';
  }

  @override
  String get whichVersion => 'Qual versão você possui?';

  @override
  String get shareQrTitle => 'Compartilhar como QR code';

  @override
  String shareQrSummary(int count) {
    return 'Compartilhando $count jogos. Um amigo escaneia isso na tela de Coleções compartilhadas.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'Sua prateleira tem $total jogos — um QR code comporta $max, então os adicionados mais recentemente estão incluídos.';
  }

  @override
  String get collectionName => 'Nome da coleção';

  @override
  String get defaultShelfName => 'Minha prateleira';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jogos na sua prateleira',
      one: 'jogo na sua prateleira',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'PRINCIPAIS SISTEMAS';

  @override
  String get unknownPlatform => 'Desconhecido';

  @override
  String get paywallTitle => 'Desbloqueie Escaneamentos Ilimitados';

  @override
  String get paywallSubtitle =>
      'Escaneie quantas capas de jogos quiser com uma compra única.';

  @override
  String get paywallFeature1 => 'Escaneamentos de capa ilimitados';

  @override
  String get paywallFeature2 => 'Precisão de reconhecimento avançada';

  @override
  String get paywallFeature3 => 'Acesso prioritário à visão da OpenAI';

  @override
  String get paywallCta => 'Desbloquear';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallComingSoon => 'Em breve — fique ligado!';

  @override
  String paywallCtaPrice(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get paywallCtaFallback => 'Desbloquear Premium';

  @override
  String get paywallCtaUnavailable => 'Temporariamente indisponível';

  @override
  String get paywallPurchaseError => 'Falha na compra. Tente novamente.';

  @override
  String get paywallNothingToRestore => 'Nenhuma compra para restaurar.';

  @override
  String get paywallRestoreError => 'Falha na restauração. Tente novamente.';

  @override
  String freeScansRemaining(int left, int total) {
    return '$left de $total escaneamentos grátis restantes';
  }

  @override
  String get owned => 'NA COLEÇÃO';

  @override
  String get addToShelfShort => 'Adicionar';

  @override
  String get removeShort => 'Remover';

  @override
  String get menuSelectGames => 'Selecionar jogos';

  @override
  String nSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String removeNGamesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remover $count jogos?',
      one: 'Remover 1 jogo?',
    );
    return '$_temp0';
  }

  @override
  String get removeNGamesMessage =>
      'Estes jogos serão removidos da sua prateleira.';

  @override
  String gamesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos removidos',
      one: '1 jogo removido',
    );
    return '$_temp0';
  }
}

/// The translations for Portuguese, as used in Portugal (`pt_PT`).
class AppLocalizationsPtPt extends AppLocalizationsPt {
  AppLocalizationsPtPt() : super('pt_PT');

  @override
  String get appTitle => 'Boxed';

  @override
  String get navShelf => 'Estante';

  @override
  String get navSearch => 'Procurar';

  @override
  String get navScan => 'Digitalizar';

  @override
  String get navForYou => 'Para ti';

  @override
  String get shareSubject => 'A minha coleção de jogos';

  @override
  String get fileLabelJson => 'JSON';

  @override
  String importResult(int imported, int skipped) {
    return '$imported jogos importados ($skipped já tinhas na coleção)';
  }

  @override
  String importFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get shelfTitle => 'A Minha Estante';

  @override
  String get sharedCollectionsTooltip => 'Coleções partilhadas';

  @override
  String get menuShareQr => 'Partilhar como código QR';

  @override
  String get menuExport => 'Exportar coleção';

  @override
  String get menuImport => 'Importar coleção';

  @override
  String get yourGames => 'Os teus jogos';

  @override
  String get yourGamesSubtitle => 'Toca numa capa para ver os detalhes';

  @override
  String get emptyShelfTitle => 'A tua estante está vazia';

  @override
  String get emptyShelfMessage =>
      'Adiciona os jogos que tens fisicamente. Procura pelo título ou digitaliza uma capa com a câmara — nós tratamos do resto.';

  @override
  String get emptyShelfAction => 'Procurar um jogo';

  @override
  String gameRemoved(String name) {
    return '\"$name\" removido';
  }

  @override
  String gameAdded(String name) {
    return '\"$name\" adicionado à coleção';
  }

  @override
  String get removeGameTitle => 'Remover jogo?';

  @override
  String removeGameMessage(String name) {
    return '\"$name\" será removido da tua estante.';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get availableOn => 'Disponível em';

  @override
  String get about => 'Sobre';

  @override
  String get inYourShelf => 'Na tua estante';

  @override
  String get removeFromCollection => 'Remover da coleção';

  @override
  String get addToShelf => 'Adicionar à estante';

  @override
  String get recsEmptyTitle => 'Ainda sem recomendações';

  @override
  String get recsEmptyMessage =>
      'Adiciona alguns jogos à tua estante e nós sugeriremos títulos baseados no que já gostas.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get recsTryAddingMore =>
      'Ainda sem recomendações — tenta adicionar mais jogos.';

  @override
  String get featuredTitle => 'Em destaque';

  @override
  String get featuredSubtitle => 'Baseado no que possuis';

  @override
  String get allPicks => 'Todas as sugestões';

  @override
  String get scanTitle => 'Digitalizar Capa';

  @override
  String scanFailed(String error) {
    return 'Falha na digitalização: $error';
  }

  @override
  String get camera => 'Câmara';

  @override
  String get gallery => 'Galeria';

  @override
  String get noReadableText =>
      'Nenhum texto legível encontrado — tenta uma foto mais nítida, melhor iluminação ou segura a capa plana.';

  @override
  String candidatesFound(int count) {
    return '$count ENCONTRADO';
  }

  @override
  String get detectedText => 'Texto detetado — toca para procurar';

  @override
  String get scanIntroTitle => 'Lê uma capa, procura na IGDB';

  @override
  String get scanIntro => 'O texto é lido no dispositivo — sem escrever.';

  @override
  String get searchTitle => 'Procurar';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String get noMatchesMessage =>
      'Tenta um título diferente, escolhe outro sistema ou limpa o filtro de género.';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get searchHint => 'Título do jogo…';

  @override
  String get filterSystem => 'SISTEMA';

  @override
  String get filterGenre => 'GÉNERO';

  @override
  String get filterAll => 'Todos';

  @override
  String get discoverGames => 'Descobre jogos';

  @override
  String get discoverGamesMessage =>
      'Procura no catálogo da IGDB. Filtra por sistema ou género para refinar.';

  @override
  String sharedDetailCount(int total, int owned) {
    return '$total jogos · tens $owned';
  }

  @override
  String get scanNoQr =>
      'Nenhum código QR encontrado — tenta uma foto mais nítida.';

  @override
  String get notVgcQr => 'Esse código QR não é de uma partilha do Boxed.';

  @override
  String get sharedEmpty => 'A coleção partilhada está vazia.';

  @override
  String get qrDamaged => 'Esse código QR está danificado ou não é suportado.';

  @override
  String get deleteSharedTitle => 'Eliminar coleção partilhada?';

  @override
  String deleteSharedMessage(String name, int count) {
    return '\"$name\" ($count jogos) será removido. A tua própria estante não é afetada.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get sharedCollectionsTitle => 'Coleções Partilhadas';

  @override
  String get scanACode => 'Digitalizar';

  @override
  String get fromGallery => 'Galeria';

  @override
  String get nothingSharedTitle => 'Ainda nada partilhado';

  @override
  String get nothingSharedMessage =>
      'Pede a um amigo para abrir \"Partilhar como código QR\" na estante dele e digitaliza aqui para ver a coleção dele.';

  @override
  String sharedRowMeta(int count, String date) {
    return '$count jogos · $date';
  }

  @override
  String get whichVersion => 'Qual versão possuis?';

  @override
  String get shareQrTitle => 'Partilhar como código QR';

  @override
  String shareQrSummary(int count) {
    return 'A partilhar $count jogos. Um amigo digitaliza isto no ecrã de Coleções partilhadas.';
  }

  @override
  String shareQrCapped(int total, int max) {
    return 'A tua estante tem $total jogos — um código QR comporta $max, pelo que os adicionados mais recentemente estão incluídos.';
  }

  @override
  String get collectionName => 'Nome da coleção';

  @override
  String get defaultShelfName => 'A minha estante';

  @override
  String gamesInShelf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jogos na tua estante',
      one: 'jogo na tua estante',
    );
    return '$_temp0';
  }

  @override
  String get topSystems => 'PRINCIPAIS SISTEMAS';

  @override
  String get unknownPlatform => 'Desconhecido';

  @override
  String get paywallTitle => 'Desbloqueia Digitalizações Ilimitadas';

  @override
  String get paywallSubtitle =>
      'Digitaliza quantas capas de jogos quiseres com uma compra única.';

  @override
  String get paywallFeature1 => 'Digitalizações de capa ilimitadas';

  @override
  String get paywallFeature2 => 'Precisão de reconhecimento avançada';

  @override
  String get paywallFeature3 => 'Acesso prioritário à visão da OpenAI';

  @override
  String get paywallCta => 'Desbloquear';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallComingSoon => 'Brevemente — fica atento!';

  @override
  String paywallCtaPrice(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get paywallCtaFallback => 'Desbloquear Premium';

  @override
  String get paywallCtaUnavailable => 'Temporariamente indisponível';

  @override
  String get paywallPurchaseError => 'Falha na compra. Tenta novamente.';

  @override
  String get paywallNothingToRestore => 'Nenhuma compra para restaurar.';

  @override
  String get paywallRestoreError => 'Falha na restauração. Tenta novamente.';

  @override
  String freeScansRemaining(int left, int total) {
    return '$left de $total digitalizações grátis restantes';
  }

  @override
  String get owned => 'NA COLEÇÃO';

  @override
  String get addToShelfShort => 'Adicionar';

  @override
  String get removeShort => 'Remover';

  @override
  String get menuSelectGames => 'Selecionar jogos';

  @override
  String nSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String removeNGamesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remover $count jogos?',
      one: 'Remover 1 jogo?',
    );
    return '$_temp0';
  }

  @override
  String get removeNGamesMessage =>
      'Estes jogos serão removidos da tua estante.';

  @override
  String gamesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos removidos',
      one: '1 jogo removido',
    );
    return '$_temp0';
  }
}
