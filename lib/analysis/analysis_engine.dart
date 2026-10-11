import '../l10n/app_strings.dart';
import '../models/analysis_result.dart';
import '../services/ai_explainer.dart';
import 'input_classifier.dart';
import 'message_rules.dart';
import 'risk_scorer.dart';
import 'url_rules.dart';

/// Orchestrates the whole analysis:
/// deterministic rules -> risk level -> recommendation -> optional AI wording.
///
/// **Localization boundary:** the rules always run in English and always set
/// the risk level. [AppStrings] only decides what the user *reads*. Neither
/// `Indicator.id`, `Indicator.severity` nor the computed [RiskLevel] can be
/// influenced by the display language.
class AnalysisEngine {
  AnalysisEngine({AiExplainer? explainer, AppStrings? strings})
      : explainer = explainer ?? AiExplainer.fromEnvironment(),
        strings = strings ?? const EnglishStrings();

  final AiExplainer explainer;

  /// Default display language. Tests that build an engine without strings
  /// keep the original English behaviour.
  final AppStrings strings;

  /// Signals strong enough on their own to make "link + request" a critical
  /// combination. A bare `fee_request` is deliberately excluded: mentioning a
  /// fee and including a link is also the shape of ordinary delivery
  /// notifications, so that pair alone must not jump to HIGH.
  static const _escalationIds = {'sensitive_request', 'payment_demand'};

  /// Signals that mean money is actually being demanded. `sensitive_request`
  /// is deliberately **not** here: a message asking for a password must not be
  /// answered with "do not transfer money" for a transfer it never mentioned.
  static const _moneyRequestIds = {'payment_demand', 'fee_request'};

  /// Signals that mean a rule found a file the link would download, so the
  /// advice can name the real threat instead of a generic "page".
  static const _downloadIds = {'dangerous_download', 'archive_download'};

  static int _severityRank(IndicatorSeverity severity) => switch (severity) {
        IndicatorSeverity.info => 0,
        IndicatorSeverity.warning => 1,
        IndicatorSeverity.critical => 2,
      };

  Future<AnalysisResult> analyze({
    required String input,
    required InputKind kind,
    AppStrings? strings,
  }) async {
    /// Per-call override, so a running app can switch language without
    /// rebuilding the engine.
    final l10n = strings ?? this.strings;

    final text = input.trim();
    if (text.isEmpty) throw const EmptyInputException();

    final indicators = <Indicator>[];
    List<String> urls = const [];

    if (kind == InputKind.link) {
      indicators.addAll(analyzeLink(text));
    } else {
      indicators.addAll(analyzeMessage(text));
      urls = extractUrls(text);
      for (final url in urls) {
        indicators.addAll(analyzeLink(url));
      }
      if (urls.isNotEmpty) {
        indicators.add(const Indicator(
          id: 'link_in_message',
          title: 'Message contains a link',
          explanation:
              'There is a link inside this message. The text around a link is '
              'often written only to make you click it, so judge both.',
          severity: IndicatorSeverity.info,
          source: IndicatorSource.link,
        ));
      }
      final asksForSomething =
          indicators.any((i) => _escalationIds.contains(i.id));
      if (urls.isNotEmpty && asksForSomething) {
        indicators.add(const Indicator(
          id: 'combined_link_request',
          title: 'Link combined with a request for money or information',
          explanation:
              'The message links somewhere and at the same time asks for '
              'money or personal details. That combination is one of the most '
              'common shapes of a scam message.',
          severity: IndicatorSeverity.critical,
          source: IndicatorSource.message,
        ));
      }
    }

    // A rule can fire on several links; show each signal only once. When the
    // same rule fires twice with different severities - for example a private
    // IP and then a public one in the same message - the more severe finding
    // is kept, so deduplication can never hide a critical signal.
    final deduped = <Indicator>[];
    for (final indicator in indicators) {
      final index = deduped.indexWhere((d) => d.id == indicator.id);
      if (index == -1) {
        deduped.add(indicator);
      } else if (_severityRank(indicator.severity) >
          _severityRank(deduped[index].severity)) {
        deduped[index] = indicator;
      }
    }

    // Scoring happens on the untouched rule output, before any translation.
    final level = RiskScorer.level(deduped);
    final signals = RiskScorer.signalCount(deduped);

    // Only the wording is replaced; id and severity are carried through.
    final displayIndicators = deduped.map(l10n.localizeIndicator).toList();

    final recommendation = l10n.recommendation(
      level,
      wantsSecrets: deduped.any(
        (i) => i.id == 'sensitive_request' || i.id == 'sensitive_words',
      ),
      wantsMoney: deduped.any(
        (i) =>
            _moneyRequestIds.contains(i.id) ||
            i.id == 'combined_link_request',
      ),
      // Only true when a link is actually present, so the advice never tells
      // the user not to open a link the message does not contain.
      hasLink: kind == InputKind.link ||
          deduped.any(
            (i) =>
                i.id == 'link_in_message' || i.source == IndicatorSource.link,
          ),
      hasDownload: deduped.any((i) => _downloadIds.contains(i.id)),
    );

    var mode = AnalysisMode.rulesOnly;
    String? aiSummary;
    var aiObservations = const <String>[];

    if (explainer.config.enabled) {
      try {
        final explanation = await explainer.explain(
          input: text,
          kind: kind,
          riskLevel: level,
          indicators: deduped,
        );
        if (explanation != null) {
          mode = AnalysisMode.rulesAndAi;
          aiSummary = explanation.summary;
          aiObservations = explanation.observations;
        } else {
          mode = AnalysisMode.rulesWithAiFallback;
        }
      } catch (_) {
        // Network problem, timeout, bad response, rate limit...
        mode = AnalysisMode.rulesWithAiFallback;
      }
    }

    return AnalysisResult(
      riskLevel: level,
      indicators: displayIndicators,
      recommendation: recommendation,
      headline: l10n.headline(level, signals),
      mode: mode,
      kind: kind,
      inputPreview: text,
      analyzedAt: DateTime.now(),
      aiSummary: aiSummary,
      aiObservations: aiObservations,
    );
  }
}
