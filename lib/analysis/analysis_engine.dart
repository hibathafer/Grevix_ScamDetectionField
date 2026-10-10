import '../models/analysis_result.dart';
import '../services/ai_explainer.dart';
import 'input_classifier.dart';
import 'message_rules.dart';
import 'risk_scorer.dart';
import 'url_rules.dart';

/// Orchestrates the whole analysis:
/// deterministic rules -> risk level -> recommendation -> optional AI wording.
class AnalysisEngine {
  AnalysisEngine({AiExplainer? explainer})
      : explainer = explainer ?? AiExplainer.fromEnvironment();

  final AiExplainer explainer;

  static const _infoRequestIds = {
    'sensitive_request',
    'payment_demand',
    'fee_request',
  };

  Future<AnalysisResult> analyze({
    required String input,
    required InputKind kind,
  }) async {
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
      final asksForSomething = indicators.any((i) => _infoRequestIds.contains(i.id));
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

    // A rule can fire on several links; show each signal only once.
    final seen = <String>{};
    final deduped =
        indicators.where((indicator) => seen.add(indicator.id)).toList();

    final level = RiskScorer.level(deduped);
    final recommendation = _recommendation(level, deduped, kind);

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
      indicators: deduped,
      recommendation: recommendation,
      headline: _headline(level, deduped),
      mode: mode,
      kind: kind,
      inputPreview: text,
      analyzedAt: DateTime.now(),
      aiSummary: aiSummary,
      aiObservations: aiObservations,
    );
  }

  String _headline(RiskLevel level, List<Indicator> indicators) {
    final signals =
        indicators.where((i) => i.severity != IndicatorSeverity.info).length;
    switch (level) {
      case RiskLevel.high:
        return 'Strong warning signs matched. Do not act before you verify.';
      case RiskLevel.medium:
        return 'Some warning signs matched. Pause and check before you act.';
      case RiskLevel.low:
        return signals == 0
            ? 'No obvious warning signs were found in this input.'
            : 'Only minor signals found - nothing clearly suspicious.';
    }
  }

  String _recommendation(
    RiskLevel level,
    List<Indicator> indicators,
    InputKind kind,
  ) {
    final wantsSecrets =
        indicators.any((i) => i.id == 'sensitive_request' || i.id == 'sensitive_words');
    final wantsMoney = indicators
        .any((i) => _infoRequestIds.contains(i.id) || i.id == 'combined_link_request');
    final hasLink = kind == InputKind.link ||
        indicators.any((i) => i.id == 'link_in_message' || i.source == IndicatorSource.link);

    final buffer = StringBuffer();
    switch (level) {
      case RiskLevel.high:
        buffer.write(
          'Do not open the link, reply, or send anything. Verify the sender '
          'through a separate, official channel - their real website or a '
          'phone number you already had - before you do anything.',
        );
        break;
      case RiskLevel.medium:
        buffer.write(
          'Pause before acting. Check who really sent this and confirm the '
          'request through an official channel you look up yourself, not '
          'through the link or number inside the message.',
        );
        break;
      case RiskLevel.low:
        buffer.write(
          'No strong warning signs were found, but that does not prove it is '
          'safe. If the message is unexpected, confirm it through an official '
          'channel before you click, pay or reply.',
        );
        break;
    }

    if (wantsSecrets) {
      buffer.write(
        ' Never send a password, PIN or verification code - no legitimate '
        'company asks for them in a message.',
      );
    }
    if (wantsMoney) {
      buffer.write(
        ' Do not transfer money or pay any fee requested in this message.',
      );
    }
    if (hasLink && level != RiskLevel.low) {
      buffer.write(
        ' Do not type your details into any page this link opens.',
      );
    }
    return buffer.toString();
  }
}
