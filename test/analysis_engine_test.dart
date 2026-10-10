import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scam_detection_field/analysis/analysis_engine.dart';
import 'package:scam_detection_field/analysis/input_classifier.dart';
import 'package:scam_detection_field/models/analysis_result.dart';
import 'package:scam_detection_field/services/ai_explainer.dart';

const _scamLink = 'http://paypal-secure-login.verify-account.xyz/session/update';

const _scamMessage =
    'URGENT! Your bank account will be suspended in 24 hours. Send your OTP '
    'and password to verify, then click the link to claim your reward: '
    'http://claim-prize.verify-account.xyz/win';

AiExplainer _explainerWith(http.Client client) => AiExplainer(
      const AiConfig(
        apiKey: 'test-key',
        baseUrl: 'https://example.invalid/v1',
        model: 'test-model',
      ),
      client: client,
    );

void main() {
  group('input detection', () {
    test('detects a link versus a message', () {
      expect(detectInputKind('https://example.com/x'), InputKind.link);
      expect(detectInputKind('www.example.com/x'), InputKind.link);
      expect(detectInputKind('example.com/x'), InputKind.link);
      expect(detectInputKind('hey, are we still on for tomorrow?'),
          InputKind.message);
      expect(detectInputKind(''), InputKind.message);
    });

    test('pulls links out of a message and ignores e-mail addresses', () {
      final urls = extractUrls(
          'mail me at john@example.com or open https://example.com/a and '
          'also www.foo.com/b');
      expect(urls, contains('https://example.com/a'));
      expect(urls, contains('www.foo.com/b'));
      expect(urls.any((u) => u.contains('example.com/a')), isTrue);
      expect(urls.any((u) => u.startsWith('john@')), isFalse);
    });

    test('finds a bare domain inside a sentence', () {
      final urls = extractUrls('please check example.com today');
      expect(urls, contains('example.com'));
    });
  });

  group('AnalysisEngine - rules only', () {
    final engine = AnalysisEngine(
      explainer: AiExplainer(AiConfig.empty()),
    );

    test('empty input throws a friendly error', () async {
      expect(
        () => engine.analyze(input: '   ', kind: InputKind.message),
        throwsA(isA<EmptyInputException>()),
      );
    });

    test('a suspicious link comes back as HIGH with reasons and advice',
        () async {
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.riskLevel, RiskLevel.high);
      expect(result.reasons, isNotEmpty);
      expect(result.recommendation, isNotEmpty);
      expect(result.headline, isNotEmpty);
      expect(result.mode, AnalysisMode.rulesOnly);
      expect(result.aiSummary, isNull);
      for (final reason in result.reasons) {
        expect(reason.explanation.length, greaterThan(30));
      }
    });

    test('a benign message comes back as LOW', () async {
      final result = await engine.analyze(
          input: 'Thanks, the invoice has been paid. Have a good day.',
          kind: InputKind.message);

      expect(result.riskLevel, RiskLevel.low);
      expect(result.reasons, isEmpty);
      expect(result.headline.toLowerCase(), contains('no obvious warning'));
      expect(result.recommendation.toLowerCase(), contains('official channel'));
    });

    test('a link plus a request for information is escalated', () async {
      final result =
          await engine.analyze(input: _scamMessage, kind: InputKind.message);

      expect(result.riskLevel, RiskLevel.high);
      expect(result.indicators.map((i) => i.id),
          contains('combined_link_request'));
      expect(result.indicators.map((i) => i.id), contains('sensitive_request'));
      expect(result.recommendation.toLowerCase(), contains('password'));
    });

    test('garbage input does not crash the engine', () async {
      final result = await engine.analyze(
          input: '### ??? !!! @@@ 00000 ...', kind: InputKind.message);
      expect(result.indicators, isA<List<Indicator>>());
      expect(result.recommendation, isNotEmpty);
    });

    test('a non-URL pasted into the link analysis still returns a result',
        () async {
      final result = await engine.analyze(
          input: 'please call me back when you can', kind: InputKind.link);
      expect(result.riskLevel, isNotNull);
      expect(result.recommendation, isNotEmpty);
    });
  });

  group('AnalysisEngine - AI integration', () {
    test('a successful AI call adds wording but never changes the risk level',
        () async {
      final explainer = _explainerWith(MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'test-model');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'summary':
                        'This message pressures you to act fast and asks for '
                            'a password, which real banks never do.',
                    'observations': [
                      'Urgency is used to stop you thinking',
                      'A password is being requested',
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesAndAi);
      expect(result.aiSummary, contains('pressures you'));
      expect(result.aiObservations, hasLength(2));
      expect(result.riskLevel, RiskLevel.high);
    });

    test('an API error falls back to the rules without crashing', () async {
      final explainer =
          _explainerWith(MockClient((request) async => http.Response(
                'rate limited',
                429,
                headers: {'content-type': 'text/plain'},
              )));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesWithAiFallback);
      expect(result.aiSummary, isNull);
      expect(result.riskLevel, RiskLevel.high);
      expect(result.reasons, isNotEmpty);
    });

    test('a network failure falls back to the rules without crashing',
        () async {
      final explainer = _explainerWith(
        MockClient((request) async => throw http.ClientException('offline')),
      );

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamMessage, kind: InputKind.message);

      expect(result.mode, AnalysisMode.rulesWithAiFallback);
      expect(result.riskLevel, RiskLevel.high);
      expect(result.recommendation, isNotEmpty);
    });

    test('an invalid AI response falls back to the rules', () async {
      final explainer =
          _explainerWith(MockClient((request) async => http.Response(
                '{"unexpected":"shape"}',
                200,
                headers: {'content-type': 'application/json'},
              )));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, isNot(AnalysisMode.rulesAndAi));
      expect(result.riskLevel, RiskLevel.high);
    });
  });
}
