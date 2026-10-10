import '../models/analysis_result.dart';

/// Turns a list of transparent signals into a risk level.
///
/// The weights are deliberately simple so they can be explained to a user:
/// a warning signal is worth 1 point, a critical signal 5 points.
/// One critical signal on its own already means HIGH, because each critical
/// rule was written to fire only on well-established scam patterns.
class RiskScorer {
  const RiskScorer._();

  static const int warningWeight = 1;
  static const int criticalWeight = 5;

  /// Points contributed by every signal.
  static int score(List<Indicator> indicators) {
    var total = 0;
    for (final i in indicators) {
      switch (i.severity) {
        case IndicatorSeverity.info:
          break;
        case IndicatorSeverity.warning:
          total += warningWeight;
        case IndicatorSeverity.critical:
          total += criticalWeight;
      }
    }
    return total;
  }

  /// Number of signals that actually raised the risk level.
  static int signalCount(List<Indicator> indicators) => indicators
      .where((i) => i.severity != IndicatorSeverity.info)
      .length;

  /// Maps signals to LOW / MEDIUM / HIGH.
  static RiskLevel level(List<Indicator> indicators) {
    final criticals =
        indicators.where((i) => i.severity == IndicatorSeverity.critical).length;
    if (criticals > 0) return RiskLevel.high;
    final total = score(indicators);
    if (total >= 7) return RiskLevel.high;
    if (total >= 2) return RiskLevel.medium;
    return RiskLevel.low;
  }
}
