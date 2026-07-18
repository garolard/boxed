import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'services/scan_quota_service.dart';
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

  final isPremiumOverride =
      (dotenv.env['IS_PREMIUM'] ?? '').trim().toLowerCase() == 'true';

  final scanQuotaService = ScanQuotaService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    isPremiumOverride: isPremiumOverride,
  );

  runZonedGuarded(
    () => runApp(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        scanQuotaServiceProvider.overrideWithValue(scanQuotaService),
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
    // Run anonymous auth in parallel with the existing minimum splash delay.
    //
    // Trade-off: on Android, uninstalling the app rotates SSAID and the next
    // install gets a fresh anonymous uid + a fresh counter, so the quota can
    // be reset. iOS is unaffected because the Firebase Anonymous Auth uid is
    // stored in the iOS Keychain, which survives uninstall. This is the
    // documented, accepted trade-off for the "no login required" stance.
    //
    // A 5-second timeout on auth ensures that on airplane mode the splash
    // screen eventually transitions to home rather than hanging forever.
    Future<void> signIn() async {
      try {
        await FirebaseAuth.instance.signInAnonymously()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    await Future.wait([
      signIn(),
      Future<void>.delayed(_minSplash),
    ]);

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final snap = await docRef.get();
      if (!snap.exists) {
        await docRef.set({
          'scansUsed': 0,
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

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
