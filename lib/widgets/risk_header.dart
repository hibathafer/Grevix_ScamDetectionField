import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/analysis_result.dart';
import '../theme/app_theme.dart';

/// Big, unambiguous risk banner at the top of the result screen.
class RiskHeader extends StatelessWidget {
  const RiskHeader({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = StringsScope.of(context);
    final color = AppTheme.riskColor(result.riskLevel);
    final label = l10n.riskLabel(result.riskLevel);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFor(result.riskLevel),
                        color: color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            key: const ValueKey('risk-label'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.analysisKind(result.kind),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5B6B7C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SignalBadge(
                      text: l10n.signalCount(result.signalCount),
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  result.headline,
                  key: const ValueKey('risk-headline'),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Color(0xFF26364D),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      text: l10n.strongSignalCount(result.criticalCount),
                      color: AppTheme.high,
                    ),
                    _Pill(
                      text: l10n.warningCount(result.warningCount),
                      color: AppTheme.medium,
                    ),
                    _Pill(
                      text:
                          l10n.contextNoteCount(result.contextNotes.length),
                      color: const Color(0xFF5B6B7C),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(RiskLevel level) => switch (level) {
        RiskLevel.low => Icons.verified_user_outlined,
        RiskLevel.medium => Icons.priority_high_rounded,
        RiskLevel.high => Icons.gpp_bad_outlined,
      };
}

class _SignalBadge extends StatelessWidget {
  const _SignalBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF46566B),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
