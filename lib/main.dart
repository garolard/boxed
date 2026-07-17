import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/services.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialise Firebase before anything else that might throw.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Pass all uncaught async errors to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final analytics = await AnalyticsService.create();
  await analytics.logAppOpen();

  runZonedGuarded(
    () => runApp(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: BoxedApp(analytics: analytics),
    )),
    (error, stack) {
      analytics.logError(
        context: 'main_zone_uncaught',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class BoxedApp extends StatelessWidget {
  final AnalyticsService analytics;
  const BoxedApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: _AppBootstrap(analytics: analytics),
    );
  }
}

/// Shows the splash while the engine warms up, then crossfades to the
/// home screen. We keep it visible for a brief minimum time so the brand
/// moment reads even on a cold start.
class _AppBootstrap extends StatefulWidget {
  final AnalyticsService analytics;
  const _AppBootstrap({required this.analytics});

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  static const Duration _minSplash = Duration(milliseconds: 1500);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'splash');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(_minSplash);
    if (!mounted) return;
    widget.analytics.logScreenView(screenName: 'home');
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _ready
          ? const HomeScreen(key: ValueKey('home'))
          : const SplashScreen(key: ValueKey('splash')),
    );
  }
}
