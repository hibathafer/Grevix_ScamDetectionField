import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_strings.dart';
import 'l10n/app_strings_ar.dart';
import 'l10n/strings_scope.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

/// Every language the app ships. Adding one more means adding a class and an
/// entry here.
List<AppStrings> buildSupportedStrings() => const [
      EnglishStrings(),
      ArabicStrings(),
    ];

class ScamDetectionApp extends StatefulWidget {
  const ScamDetectionApp({super.key, this.initialStrings});

  /// Lets tests start in a non-default language. Production omits it and
  /// therefore starts in English.
  final AppStrings? initialStrings;

  @override
  State<ScamDetectionApp> createState() => _ScamDetectionAppState();
}

class _ScamDetectionAppState extends State<ScamDetectionApp> {
  /// English is the default; there is no persisted preference yet, so a
  /// restart returns to English.
  AppStrings _strings = const EnglishStrings();

  @override
  void initState() {
    super.initState();
    _strings = widget.initialStrings ?? const EnglishStrings();
  }

  void _changeLanguage(AppStrings next) {
    if (next.languageCode == _strings.languageCode) return;
    setState(() => _strings = next);
  }

  @override
  Widget build(BuildContext context) {
    return StringsScope(
      strings: _strings,
      onChanged: _changeLanguage,
      child: MaterialApp(
        title: _strings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // Drives Directionality/RTL for the whole tree, including Material's
        // own built-in widgets.
        locale: Locale(_strings.languageCode),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
