import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Shortcut for accessing the generated [AppLocalizations].
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  Locale get appLocale => Localizations.localeOf(this);
}