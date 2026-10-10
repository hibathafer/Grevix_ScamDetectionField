import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../theme/app_theme.dart';

/// One signal found by the rules: icon, title, plain-English reason.
class IndicatorTile extends StatelessWidget {
  const IndicatorTile({super.key, required this.indicator});

  final Indicator indicator;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(indicator.severity);
    final isCritical = indicator.severity == IndicatorSeverity.critical;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppTheme.severityIcon(indicator.severity),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        indicator.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isCritical ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF12203A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SourceTag(source: indicator.source),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  indicator.explanation,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Color(0xFF46566B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final IndicatorSource source;

  @override
  Widget build(BuildContext context) {
    final label = source == IndicatorSource.link ? 'Link' : 'Message';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5B6B7C),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
