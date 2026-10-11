import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

    test('a non-URL pasted into the link tab is refused, not scored', () async {
      // Regression: this used to return LOW RISK, which reads as "you are
      // safe" for a check that never ran.
      await expectLater(
        engine.analyze(
            input: 'please call me back when you can', kind: InputKind.link),
        throwsA(isA<InvalidUrlException>()),
      );
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

    test('the same code can drive an OpenAI-compatible Gemini endpoint',
        () async {
      // Checked against Google's own "OpenAI compatibility" page
      // (ai.google.dev/gemini-api/docs/openai): base URL
      // https://generativelanguage.googleapis.com/v1beta/openai/, POST to
      // /chat/completions, `Authorization: Bearer <key>`, a `messages` array,
      // and the answer read back from choices[0].message.content.
      //
      // It uses a mock client, so no network call is made and no real key is
      // involved.
      const geminiBase =
          'https://generativelanguage.googleapis.com/v1beta/openai/';
      const geminiModel = 'gemini-3.8-flash';
      late Uri called;
      late Map<String, String> sentHeaders;
      late Map<String, dynamic> sentBody;

      final explainer = AiExplainer(
        const AiConfig(
          apiKey: 'not-a-real-key',
          baseUrl: geminiBase,
          model: geminiModel,
        ),
        client: MockClient((request) async {
          called = request.url;
          sentHeaders = request.headers;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary':
                          'A short, plain-language summary that the parser '
                              'will accept without any problem.',
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final explanation = await explainer.explain(
        input: _scamLink,
        kind: InputKind.link,
        riskLevel: RiskLevel.high,
        indicators: const [],
      );

      expect(
        called.toString(),
        'https://generativelanguage.googleapis.com/v1beta/openai/'
        'chat/completions',
        reason: 'the trailing slash must not produce a doubled or missing '
            'path segment',
      );
      expect(
        sentHeaders['Authorization'],
        'Bearer not-a-real-key',
        reason: 'Gemini authenticates the OpenAI-compatible surface with a '
            'Bearer token, not with an x-goog-api-key header',
      );
      expect(sentHeaders['Content-Type'], contains('application/json'));
      expect(sentBody['model'], geminiModel,
          reason: 'the model id must be passed through unchanged');
      expect(sentBody['max_tokens'], greaterThanOrEqualTo(512),
          reason: 'Gemini 3.x spends part of the output budget on internal '
              'reasoning, so a tight cap can leave nothing for the answer');
      expect(sentBody['messages'], isA<List>());
      final roles =
          (sentBody['messages'] as List).map((m) => (m as Map)['role']).toList();
      expect(roles, containsAll(['system', 'user']));

      expect(explanation, isNotNull);
      expect(explanation!.summary, contains('plain-language summary'));
    });

    test('the committed AI config template carries no secret', () {
      // env.ai.example.ps1 is the file a developer copies to fill in a key.
      // It is committed, so it must stay empty - this test stops a real key
      // from ever being pasted into it and pushed.
      final file = File('env.ai.example.ps1');
      expect(file.existsSync(), isTrue,
          reason: 'the template must stay in the repository');

      final text = file.readAsStringSync();
      expect(text, isNot(contains(RegExp(r'AIza[0-9A-Za-z_\-]{30,}'))),
          reason: 'a Google-style key must never appear in the template');
      expect(text, isNot(contains(RegExp(r'sk-[0-9A-Za-z]{20,}'))),
          reason: 'an OpenAI-style key must never appear in the template');

      final assignment =
          RegExp(r"\$GeminiApiKey\s*=\s*'([^']*)'").firstMatch(text);
      expect(assignment, isNotNull,
          reason: 'the template must keep the marked key line');
      expect(assignment!.group(1), isEmpty,
          reason: 'the committed template must ship with an empty key');

      // And the file that would actually hold a real key must stay ignored.
      final ignored = File('.gitignore').readAsStringSync();
      expect(ignored, contains('env.ai.ps1'),
          reason: 'the real config file must be git-ignored');
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

    // ------------------------------------------------------------------------
    // Phase 2 - resilient fallback.
    //
    // None of these tests opens a real network connection or uses a real
    // key: every provider answer is a MockClient, so the suite stays
    // deterministic and free of quota use.
    // ------------------------------------------------------------------------

    /// Runs one failing provider against the engine and returns the reason
    /// that was recorded, asserting on the way that the fallback really
    /// produced a usable assessment for a link the rules already score HIGH.
    Future<AiFailure> reasonFor(http.Client client) async {
      final engine = AnalysisEngine(explainer: _explainerWith(client));
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);
      expect(result.mode, AnalysisMode.rulesWithAiFallback,
          reason: 'a failing AI step must fall back, not fail the analysis');
      expect(result.aiSummary, isNull,
          reason: 'no AI wording may be shown when the AI step failed');
      expect(result.riskLevel, RiskLevel.high,
          reason: 'the rules must still assess the link on their own');
      expect(result.reasons, isNotEmpty);
      expect(result.recommendation, isNotEmpty);
      return result.aiFailure!;
    }

    http.Response reply(Object body) => http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );

    http.Response plain(String body, int status) => http.Response(
          body,
          status,
          headers: {'content-type': 'text/plain'},
        );

    test('each failure shape is classified instead of being swallowed',
        () async {
      expect(
        await reasonFor(
            MockClient((r) async => throw TimeoutException('slow'))),
        AiFailure.timeout,
      );
      expect(
        await reasonFor(
            MockClient((r) async => throw http.ClientException('offline'))),
        AiFailure.network,
      );
      expect(await reasonFor(MockClient((r) async => plain('busy', 429))),
          AiFailure.rateLimited);
      expect(await reasonFor(MockClient((r) async => plain('boom', 500))),
          AiFailure.apiError);
      expect(await reasonFor(MockClient((r) async => plain('not json', 200))),
          AiFailure.badResponse);
      expect(
          await reasonFor(
              MockClient((r) async => reply({'unexpected': 'shape'}))),
          AiFailure.badResponse);
      expect(await reasonFor(MockClient((r) async => reply({'choices': []}))),
          AiFailure.badResponse);
      expect(
        await reasonFor(MockClient((r) async => reply({
              'choices': [
                {'message': {'content': '   '}},
              ],
            }))),
        AiFailure.badResponse,
      );
      // Valid JSON in the wrong shape, so the parser cannot use it.
      expect(
        await reasonFor(MockClient((r) async => reply({
              'choices': [
                {'message': {'content': '{"summary": 12}'}},
              ],
            }))),
        AiFailure.badResponse,
      );
    });

    test('an unrecognised failure is reported as unknown, not invented',
        () async {
      // A StateError is neither a timeout nor http's own transport error, so
      // calling it a network problem would be a guess.
      expect(
        await reasonFor(MockClient((r) async => throw StateError('odd'))),
        AiFailure.unknown,
      );
    });

    test('a failed AI step leaves the whole rule-based result untouched',
        () async {
      final withFailingAi = AnalysisEngine(
        explainer: _explainerWith(
          MockClient((r) async => throw http.ClientException('offline')),
        ),
      );
      // No key at all - the deterministic baseline for the same input.
      final withoutAi =
          AnalysisEngine(explainer: AiExplainer(const AiConfig.empty()));

      for (final sample in const [
        (input: _scamLink, kind: InputKind.link),
        (input: _scamMessage, kind: InputKind.message),
      ]) {
        final label = '${sample.kind.name}: ${sample.input}';
        final failed = await withFailingAi.analyze(
            input: sample.input, kind: sample.kind);
        final baseline = await withoutAi.analyze(
            input: sample.input, kind: sample.kind);

        expect(failed.mode, AnalysisMode.rulesWithAiFallback, reason: label);
        expect(baseline.mode, AnalysisMode.rulesOnly, reason: label);
        expect(failed.riskLevel, baseline.riskLevel, reason: label);
        expect(failed.indicators.map((i) => i.id),
            baseline.indicators.map((i) => i.id),
            reason: label);
        expect(failed.recommendation, baseline.recommendation, reason: label);
        expect(failed.headline, baseline.headline, reason: label);
        expect(failed.indicators.map((i) => i.title),
            baseline.indicators.map((i) => i.title),
            reason: label);
      }
    });

    test('a missing key means nothing is attempted and no failure is claimed',
        () async {
      final engine =
          AnalysisEngine(explainer: AiExplainer(const AiConfig.empty()));
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesOnly);
      expect(result.aiFailure, isNull,
          reason: 'nothing was requested, so nothing failed');
      expect(result.riskLevel, RiskLevel.high);
    });

    test('a successful AI step records no failure', () async {
      final engine = AnalysisEngine(
        explainer: _explainerWith(MockClient((r) async => reply({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': 'A short, calm explanation for the reader.',
                      'observations': ['one point'],
                    }),
                  },
                },
              ],
            }))),
      );
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesAndAi);
      expect(result.aiFailure, isNull);
    });

    test('the configured key never reaches a failure report', () async {
      final explainer = _explainerWith(
          MockClient((r) async => plain('quota exceeded', 429)));

      AiException? caught;
      try {
        await explainer.explain(
          input: _scamMessage,
          kind: InputKind.message,
          riskLevel: RiskLevel.high,
          indicators: const [],
        );
      } on AiException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.failure, AiFailure.rateLimited);
      expect(caught.toString(), isNot(contains('test-key')));
      expect(caught.toString(), isNot(contains('Bearer')));
      expect(caught.detail, 'HTTP 429');
    });

    // Debug diagnostics for a real, live failure. A plain-language note only
    // says "the AI service returned an error", which cannot tell a bad key
    // from a bad model id from an outage, so the status code is carried onto
    // the result and shown in debug builds only.
    test('the HTTP status code is carried onto the result', () async {
      final explainer = _explainerWith(
          MockClient((r) async => plain('not found', 404)));
      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesWithAiFallback);
      expect(result.aiFailure, AiFailure.apiError);
      expect(result.aiFailureDetail, 'HTTP 404',
          reason: 'the status code tells a bad key from a bad model id');
      // The diagnostic never disturbs the assessment.
      expect(result.riskLevel, RiskLevel.high);
      expect(result.recommendation, isNotEmpty);
    });

    test('no failure detail can ever carry the configured key', () async {
      // A distinctive key, so an accidental echo cannot hide behind a common
      // test string.
      const key = 'test-key-never-print-me';

      Future<String?> detailFor(http.Client client) async {
        final engine = AnalysisEngine(
          explainer: AiExplainer(
            const AiConfig(
              apiKey: key,
              baseUrl: 'https://example.invalid/v1',
              model: 'test-model',
            ),
            client: client,
          ),
        );
        final result =
            await engine.analyze(input: _scamLink, kind: InputKind.link);
        return result.aiFailureDetail;
      }

      final details = <String?>[
        await detailFor(MockClient((r) async => plain('busy', 429))),
        await detailFor(MockClient((r) async => plain('boom', 500))),
        await detailFor(MockClient((r) async => plain('bad gateway', 502))),
        await detailFor(
            MockClient((r) async => throw TimeoutException('slow'))),
        await detailFor(
            MockClient((r) async => throw http.ClientException('offline'))),
        await detailFor(MockClient((r) async => plain('not json', 200))),
        await detailFor(MockClient((r) async => throw StateError('odd'))),
      ];

      for (final detail in details) {
        expect(detail, isNotNull,
            reason: 'every failure must carry something readable');
        expect(detail, isNot(contains(key)));
        expect(detail, isNot(contains('Bearer')));
        expect(detail, isNot(contains('Authorization')));
      }
    });

    // ------------------------------------------------------------------------
    // Google AI Studio fallback - the native generateContent path.
    //
    // The primary request stays the OpenAI-compatible endpoint. The native
    // path runs only after the primary fails with something the same key and
    // the same model can still recover from: never for a 429, never without
    // a configured key, and never after a success.
    // ------------------------------------------------------------------------

    const googleBase =
        'https://generativelanguage.googleapis.com/v1beta/openai/';
    const googleModel = 'gemini-3.8-flash';
    const nativeText =
        'This message pressures you to act fast and asks for a password, '
        'which a real bank never does. Do not reply to it.';

    AiExplainer googleExplainer(http.Client client) => AiExplainer(
          const AiConfig(
            apiKey: 'test-key',
            baseUrl: googleBase,
            model: googleModel,
          ),
          client: client,
        );

    /// A successful native `generateContent` body.
    http.Response nativeReply(String text) => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': text}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

    /// A successful OpenAI-compatible body.
    http.Response openAiReply(String summary) => reply({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'summary': summary,
                  'observations': ['Urgency is used to stop you thinking'],
                })
              }
            }
          ],
        });

    http.Response error(int status) => http.Response(
          'provider problem',
          status,
          headers: {'content-type': 'text/plain'},
        );

    test('a primary HTTP failure is rescued by the native fallback', () async {
      final urls = <Uri>[];
      final sent = <Map<String, String>>[];
      final explainer = googleExplainer(MockClient((request) async {
        urls.add(request.url);
        sent.add(request.headers);
        if (urls.length == 1) return error(500);
        return nativeReply(nativeText);
      }));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesAndAi,
          reason: 'the native path must rescue the wording step');
      expect(result.aiSummary, contains('pressures you'));
      expect(result.aiFailure, isNull);
      expect(result.riskLevel, RiskLevel.high);
      expect(urls, hasLength(2),
          reason: 'exactly one primary attempt and one fallback attempt');
      expect(urls[0].path, endsWith('/openai/chat/completions'));
      expect(urls[1].path, endsWith('/models/$googleModel:generateContent'),
          reason: 'the fallback must hit native generateContent');
      expect(sent[0]['Authorization'], 'Bearer test-key');
      expect(sent[1]['x-goog-api-key'], 'test-key',
          reason: 'the native surface authenticates with a header');
      expect(sent[1].containsKey('Authorization'), isFalse);
      expect(urls[1].query, isEmpty,
          reason: 'the key must never be placed in the query string');
    });

    test('a transport failure on the primary is rescued as well', () async {
      final urls = <Uri>[];
      final explainer = googleExplainer(MockClient((request) async {
        urls.add(request.url);
        if (urls.length == 1) throw http.ClientException('offline');
        return nativeReply(nativeText);
      }));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(result.mode, AnalysisMode.rulesAndAi);
      expect(result.aiFailure, isNull);
      expect(urls, hasLength(2));
      expect(result.riskLevel, RiskLevel.high);
    });

    test('when both the primary and the fallback fail the rules stand alone',
        () async {
      final urls = <Uri>[];
      final failing = AnalysisEngine(
        explainer: googleExplainer(MockClient((request) async {
          urls.add(request.url);
          return error(503);
        })),
      );
      final baseline =
          AnalysisEngine(explainer: AiExplainer(const AiConfig.empty()));

      final failed =
          await failing.analyze(input: _scamLink, kind: InputKind.link);
      final plain =
          await baseline.analyze(input: _scamLink, kind: InputKind.link);

      expect(urls, hasLength(2));
      expect(failed.mode, AnalysisMode.rulesWithAiFallback);
      expect(failed.aiFailure, AiFailure.apiError);
      expect(failed.aiFailureDetail, 'HTTP 503',
          reason: 'the configured primary path is what gets reported');
      expect(failed.aiSummary, isNull);
      expect(failed.riskLevel, plain.riskLevel, reason: 'level must not move');
      expect(failed.indicators.map((i) => i.id),
          plain.indicators.map((i) => i.id),
          reason: 'indicators must not move');
      expect(failed.recommendation, plain.recommendation,
          reason: 'advice must not move');
      expect(failed.headline, plain.headline);
    });

    test('HTTP 429 never triggers the fallback', () async {
      final urls = <Uri>[];
      final explainer = googleExplainer(MockClient((request) async {
        urls.add(request.url);
        return error(429);
      }));

      final engine = AnalysisEngine(explainer: explainer);
      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(urls, hasLength(1),
          reason: 'the quota belongs to the credential, so a second call '
              'would only be rejected again');
      expect(result.mode, AnalysisMode.rulesWithAiFallback);
      expect(result.aiFailure, AiFailure.rateLimited);
      expect(result.riskLevel, RiskLevel.high);
    });

    test('missing configuration makes neither request', () async {
      final urls = <Uri>[];
      final engine = AnalysisEngine(
        explainer: AiExplainer(
          const AiConfig.empty(),
          client: MockClient((request) async {
            urls.add(request.url);
            return nativeReply(nativeText);
          }),
        ),
      );

      final result =
          await engine.analyze(input: _scamLink, kind: InputKind.link);

      expect(urls, isEmpty, reason: 'no key means no socket at all');
      expect(result.mode, AnalysisMode.rulesOnly);
      expect(result.aiFailure, isNull);
      expect(result.aiSummary, isNull);
      expect(result.riskLevel, RiskLevel.high);
    });

    test('the rules never change whatever the AI outcome is', () async {
      final baseline = await AnalysisEngine(
              explainer: AiExplainer(const AiConfig.empty()))
          .analyze(input: _scamLink, kind: InputKind.link);

      Future<void> check(String label, http.Client client) async {
        final result = await AnalysisEngine(explainer: googleExplainer(client))
            .analyze(input: _scamLink, kind: InputKind.link);
        expect(result.riskLevel, baseline.riskLevel, reason: label);
        expect(result.indicators.map((i) => i.id),
            baseline.indicators.map((i) => i.id), reason: label);
        expect(result.recommendation, baseline.recommendation, reason: label);
        expect(result.headline, baseline.headline, reason: label);
      }

      await check('primary succeeds',
          MockClient((r) async => openAiReply('A clear summary of the risk.')));
      await check('fallback succeeds', MockClient((r) async {
        return r.url.path.contains('/openai/')
            ? error(500)
            : nativeReply(nativeText);
      }));
      await check('both fail', MockClient((r) async => error(500)));
      await check('rate limited', MockClient((r) async => error(429)));
      await check('both time out',
          MockClient((r) async => throw TimeoutException('slow')));
    });

    test('no failure detail from either path can carry the key', () async {
      const key = 'test-key-never-print-me';

      Future<String?> detailFor(http.Client client) async {
        final engine = AnalysisEngine(
          explainer: AiExplainer(
            const AiConfig(
              apiKey: key,
              baseUrl: googleBase,
              model: googleModel,
            ),
            client: client,
          ),
        );
        final result =
            await engine.analyze(input: _scamLink, kind: InputKind.link);
        return result.aiFailureDetail;
      }

      final details = <String?>[
        await detailFor(MockClient((r) async => error(500))),
        await detailFor(MockClient((r) async => error(429))),
        await detailFor(
            MockClient((r) async => throw TimeoutException('slow'))),
        await detailFor(
            MockClient((r) async => throw http.ClientException('offline'))),
        await detailFor(MockClient(
            (r) async => http.Response('not json', 200,
                headers: {'content-type': 'application/json'}))),
        await detailFor(MockClient((r) async => throw StateError('odd'))),
      ];

      for (final detail in details) {
        expect(detail, isNotNull, reason: 'every failure keeps a reason');
        expect(detail, isNot(contains(key)));
        expect(detail, isNot(contains('Bearer')));
        expect(detail, isNot(contains('Authorization')));
        expect(detail, isNot(contains('goog-api-key')));
      }
    });
  });
}
