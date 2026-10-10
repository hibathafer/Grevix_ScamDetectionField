/// Core data types produced by the analysis engine.
///
/// These models are pure Dart (no Flutter imports) so they can be unit tested
/// on any platform.
library;

/// How risky the analysed input looks, based on transparent rule signals.
enum RiskLevel { low, medium, high }

/// How strongly a single signal contributes to the risk level.
enum IndicatorSeverity {
  /// Context that is useful to show but does not raise the risk level.
  info,

  /// A recognised warning sign.
  warning,

  /// A strong, well known scam signal.
  critical,
}

/// Which part of the input produced the signal.
enum IndicatorSource { link, message }

/// What kind of content the user submitted.
enum InputKind { link, message }

/// Which services actually produced the shown explanation.
enum AnalysisMode {
  /// Only the built-in transparent rules ran (no AI key configured).
  rulesOnly,

  /// Rules set the risk level and an AI model added a plain-language
  /// explanation.
  rulesAndAi,

  /// Rules set the risk level; an AI explanation was requested but could not
  /// be completed.
  rulesWithAiFallback,
}

/// One transparent, explainable warning signal.
class Indicator {
  const Indicator({
    required this.id,
    required this.title,
    required this.explanation,
    required this.severity,
    required this.source,
  });

  /// Stable identifier, used for de-duplication and tests.
  final String id;

  /// Short human label, e.g. "Urgency language".
  final String title;

  /// Plain-English reason this signal matters.
  final String explanation;

  final IndicatorSeverity severity;

  final IndicatorSource source;

  Indicator copyWith({IndicatorSource? source}) => Indicator(
        id: id,
        title: title,
        explanation: explanation,
        severity: severity,
        source: source ?? this.source,
      );
}

/// The full, honest result of one analysis.
class AnalysisResult {
  const AnalysisResult({
    required this.riskLevel,
    required this.indicators,
    required this.recommendation,
    required this.headline,
    required this.mode,
    required this.kind,
    required this.inputPreview,
    required this.analyzedAt,
    this.aiSummary,
    this.aiObservations = const [],
  });

  final RiskLevel riskLevel;

  /// Every signal found, including informational context.
  final List<Indicator> indicators;

  /// Practical next step for the user.
  final String recommendation;

  /// One-line explanation of what this risk level means right now.
  final String headline;

  final AnalysisMode mode;

  final InputKind kind;

  /// The analysed input, trimmed for display.
  final String inputPreview;

  final DateTime analyzedAt;

  /// Optional plain-language explanation produced by an external AI model.
  final String? aiSummary;

  /// Optional extra observations produced by an external AI model.
  final List<String> aiObservations;

  /// Signals that actually raised the risk (warning + critical).
  List<Indicator> get reasons {
    final list = indicators
        .where((i) => i.severity != IndicatorSeverity.info)
        .toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return list;
  }

  /// Context notes that did not raise the risk level.
  List<Indicator> get contextNotes =>
      indicators.where((i) => i.severity == IndicatorSeverity.info).toList();

  int get criticalCount =>
      indicators.where((i) => i.severity == IndicatorSeverity.critical).length;

  int get warningCount =>
      indicators.where((i) => i.severity == IndicatorSeverity.warning).length;

  /// Number of signals that actually influenced the risk level.
  int get signalCount => criticalCount + warningCount;

  bool get usedAi => aiSummary != null;
}

/// Thrown when the user submits an empty input.
class EmptyInputException implements Exception {
  const EmptyInputException();

  @override
  String toString() => 'Please paste or type something to analyse first.';
}
