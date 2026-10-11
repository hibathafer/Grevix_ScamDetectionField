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

/// Why the optional AI step did not produce an explanation.
///
/// This is a fixed category and nothing else: it never carries the API key,
/// the request URL, a response body or any other value that could leak a
/// secret or dump provider output into the UI and logs.
enum AiFailure {
  /// The provider did not answer inside the request timeout.
  timeout,

  /// The request could not be sent at all (offline, DNS, refused connection).
  network,

  /// The provider answered 429 - too many requests.
  rateLimited,

  /// The provider answered with another error status.
  apiError,

  /// The provider answered 200, but the body was not the JSON we can read.
  badResponse,

  /// Anything else that was caught and could not be classified.
  unknown,
}

/// One transparent, explainable warning signal.
class Indicator {
  const Indicator({
    required this.id,
    required this.title,
    required this.explanation,
    required this.severity,
    required this.source,
    this.params = const <String, String>{},
  });

  /// Stable identifier, used for de-duplication and tests.
  ///
  /// The id never changes with the display language: it identifies the rule.
  final String id;

  /// Short human label, e.g. "Urgency language".
  ///
  /// Always produced in English by the rules. The display layer may replace it
  /// with a translated equivalent; see [AppStrings.indicatorTitle].
  final String title;

  /// Plain-English reason this signal matters.
  ///
  /// Always produced in English by the rules. The display layer may replace it
  /// with a translated equivalent; see [AppStrings.indicatorExplanation].
  final String explanation;

  final IndicatorSeverity severity;

  final IndicatorSource source;

  /// Values that were interpolated into [title] / [explanation], keyed by a
  /// stable name (`brand`, `tld`, `count`, ...).
  ///
  /// Kept separately so a translated string can be rebuilt from the same
  /// facts instead of being scraped out of the English sentence.
  final Map<String, String> params;

  Indicator copyWith({
    IndicatorSource? source,
    String? title,
    String? explanation,
    Map<String, String>? params,
  }) =>
      Indicator(
        id: id,
        title: title ?? this.title,
        explanation: explanation ?? this.explanation,
        severity: severity,
        source: source ?? this.source,
        params: params ?? this.params,
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
    this.aiFailure,
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

  /// Why the AI step produced nothing, or `null` when no failure happened.
  ///
  /// `null` covers both "no AI key was configured, so nothing was attempted"
  /// ([AnalysisMode.rulesOnly]) and "the AI step succeeded"
  /// ([AnalysisMode.rulesAndAi]). Only [AnalysisMode.rulesWithAiFallback]
  /// carries a reason here.
  final AiFailure? aiFailure;

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
