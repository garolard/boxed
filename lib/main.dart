import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'providers/collection_provider.dart';
import 'providers/shared_collections_provider.dart';
import 'screens/home_screen.dart';
import 'services/collection_repository.dart';
import 'services/igdb_service.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const VgCollectionApp());
}

class VgCollectionApp extends StatelessWidget {
  const VgCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = CollectionRepository();
    final igdb = IgdbService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CollectionProvider(repo: repo, igdb: igdb)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SharedCollectionsProvider(repo: repo, igdb: igdb)..load(),
        ),
      ],
      child: MaterialApp(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return GradientBackground(child: child ?? const SizedBox());
        },
        home: const HomeScreen(),
      ),
    );
  }
}
