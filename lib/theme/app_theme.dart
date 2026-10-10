import 'package:flutter/material.dart';

import '../models/analysis_result.dart';

/// Central colours, typography and risk styling.
class AppTheme {
  const AppTheme._();

  static const Color brand = Color(0xFF1F4B99);
  static const Color brandSoft = Color(0xFFE8EFFB);

  static const Color low = Color(0xFF1B7F4B);
  static const Color medium = Color(0xFFB26A00);
  static const Color high = Color(0xFFC62828);

  static Color riskColor(RiskLevel level) => switch (level) {
        RiskLevel.low => low,
        RiskLevel.medium => medium,
        RiskLevel.high => high,
      };

  static String riskLabel(RiskLevel level) => switch (level) {
        RiskLevel.low => 'LOW RISK',
        RiskLevel.medium => 'MEDIUM RISK',
        RiskLevel.high => 'HIGH RISK',
      };

  static String riskShortLabel(RiskLevel level) => switch (level) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
      };

  static Color severityColor(IndicatorSeverity severity) => switch (severity) {
        IndicatorSeverity.info => const Color(0xFF5B6B7C),
        IndicatorSeverity.warning => medium,
        IndicatorSeverity.critical => high,
      };

  static IconData severityIcon(IndicatorSeverity severity) => switch (severity) {
        IndicatorSeverity.info => Icons.info_outline,
        IndicatorSeverity.warning => Icons.warning_amber_outlined,
        IndicatorSeverity.critical => Icons.report_gmailerrorred_outlined,
      };

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF6F8FC),
        foregroundColor: Color(0xFF12203A),
        titleTextStyle: TextStyle(
          color: Color(0xFF12203A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7DEE9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7DEE9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brand, width: 1.6),
        ),
        hintStyle: const TextStyle(color: Color(0xFF8A97A8), fontSize: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE3E9F2)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: const BorderSide(color: Color(0xFFCBD5E3)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEDF1F7),
        thickness: 1,
      ),
    );
  }
}
