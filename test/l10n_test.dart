import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scam_detection_field/analysis/analysis_engine.dart';
import 'package:scam_detection_field/app.dart';
import 'package:scam_detection_field/l10n/app_strings.dart';
import 'package:scam_detection_field/l10n/app_strings_ar.dart';
import 'package:scam_detection_field/l10n/strings_scope.dart';
import 'package:scam_detection_field/models/analysis_result.dart';
import 'package:scam_detection_field/screens/result_screen.dart';
import 'package:scam_detection_field/services/ai_explainer.dart';

const _scamLink =
    'http://paypal-secure-login.verify-account.xyz/session/update';

const _scamMessage =
    'URGENT! Your bank account will be suspended in 24 hours. Send your OTP '
    'and password to verify, then click the link to claim your reward: '
    'http://claim-prize.verify-account.xyz/win';

/// A scam written only in Arabic. The rules are English-only, so this must
/// NOT be detected - and the app must say so rather than pretend otherwise.
const _arabicScamMessage =
    'عاجل جداً! سيتم إغلاق حسابك خلال 24 ساعة. أرسل كلمة المرور ورمز OTP '
    'لإتمام التحقق فوراً.';

final _arabicScript = RegExp(r'[\u0600-\u06FF]');

void main() {
  const english = EnglishStrings();
  const arabic = ArabicStrings();

  Future<void> pumpApp(
    WidgetTester tester, {
    AppStrings? initial,
    Size size = const Size(500, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScamDetectionApp(initialStrings: initial));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('language metadata', () {
    test('English is the default and is left-to-right', () {
      expect(english.languageCode, 'en');
      expect(english.isRtl, isFalse);
      expect(english.languageName, 'English');
    });

    test('Arabic declares right-to-left', () {
      expect(arabic.languageCode, 'ar');
      expect(arabic.isRtl, isTrue);
      expect(arabic.languageName, 'العربية');
    });

    test('the supported list exposes exactly the shipped languages', () {
      final codes =
          buildSupportedStrings().map((s) => s.languageCode).toList();
      expect(codes, ['en', 'ar']);
    });
  });

  group('Arabic is a real translation, not a copy of English', () {
    test('every core UI string is non-empty and actually Arabic', () {
      final values = <String>[
        arabic.heroTitle,
        arabic.heroBody,
        arabic.tryLinkExample,
        arabic.tryMessageExample,
        arabic.tabLink,
        arabic.tabMessage,
        arabic.linkFieldLabel,
        arabic.messageFieldLabel,
        arabic.errorEmptyInput,
        arabic.errorLinkContainsSpaces,
        arabic.analyseButton,
        arabic.analysingButton,
        arabic.switchToMessage,
        arabic.howItWorksTitle,
        arabic.homeDisclaimer,
        arabic.infoSheetTitle,
        arabic.infoSheetBody,
        arabic.resultTitle,
        arabic.analyseAnother,
        arabic.whyThisResult,
        arabic.contextNotes,
        arabic.whatToDo,
        arabic.aboutThisAnalysis,
        arabic.noSignalsTitle,
        arabic.copyReport,
        arabic.reportCopied,
        arabic.limitationNote,
        arabic.languageSheetTitle,
        arabic.riskLabel(RiskLevel.low),
        arabic.riskLabel(RiskLevel.medium),
        arabic.riskLabel(RiskLevel.high),
        arabic.analysisKind(InputKind.link),
        arabic.analysisKind(InputKind.message),
        arabic.sourceLabel(IndicatorSource.link),
        arabic.sourceLabel(IndicatorSource.message),
        arabic.headline(RiskLevel.high, 3),
        arabic.recommendation(RiskLevel.high,
            wantsSecrets: true, wantsMoney: true, hasLink: true),
      ];

      for (final value in values) {
        expect(value.trim(), isNotEmpty);
        expect(
          _arabicScript.hasMatch(value),
          isTrue,
          reason: 'expected Arabic script in: $value',
        );
      }
    });

    test('Arabic strings differ from their English counterparts', () {
      final pairs = <(String, String)>[
        (english.heroTitle, arabic.heroTitle),
        (english.resultTitle, arabic.resultTitle),
        (english.whatToDo, arabic.whatToDo),
        (english.copyReport, arabic.copyReport),
        (english.riskLabel(RiskLevel.high), arabic.riskLabel(RiskLevel.high)),
        (
          english.headline(RiskLevel.high, 3),
          arabic.headline(RiskLevel.high, 3),
        ),
      ];
      for (final (en, ar) in pairs) {
        expect(en, isNot(equals(ar)));
      }
    });

    test('Arabic count agreement is handled, not naive concatenation', () {
      expect(arabic.signalCount(1), 'إشارة واحدة');
      expect(arabic.signalCount(2), 'إشارتان');
      expect(arabic.signalCount(5), '5 إشارات');
      expect(arabic.signalCount(14), '14 إشارة');
    });
  });

  group('the Arabic detection-coverage limitation', () {
    test('is shown in Arabic and hidden in English', () {
      expect(english.detectionCoverageNote, isNull);
      expect(arabic.detectionCoverageNote, isNotNull);
      expect(
        _arabicScript.hasMatch(arabic.detectionCoverageNote!),
        isTrue,
      );
    });

    testWidgets('appears on the Arabic home screen', (tester) async {
      await pumpApp(tester, initial: arabic);

      expect(find.byKey(const ValueKey('coverage-note')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not appear on the English home screen', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const ValueKey('coverage-note')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is repeated on the Arabic result screen', (tester) async {
      await pumpApp(tester, initial: arabic);

      await tapVisible(tester, find.text(arabic.tryMessageExample));
      await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

      expect(find.byKey(const ValueKey('coverage-note')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('risk level and signals are identical in both languages', () {
    final engine = AnalysisEngine();

    test('a suspicious link scores HIGH with the same ids in both', () async {
      final en = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: english);
      final ar = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);

      expect(en.riskLevel, RiskLevel.high);
      expect(ar.riskLevel, en.riskLevel,
          reason: 'the display language must never change the risk level');
      expect(ar.indicators.map((i) => i.id).toList(),
          en.indicators.map((i) => i.id).toList());
      expect(
        ar.indicators.map((i) => i.severity).toList(),
        en.indicators.map((i) => i.severity).toList(),
      );
      expect(ar.criticalCount, en.criticalCount);
      expect(ar.warningCount, en.warningCount);
      expect(ar.signalCount, en.signalCount);
    });

    test('a suspicious message scores HIGH with the same ids in both',
        () async {
      final en = await engine.analyze(
          input: _scamMessage, kind: InputKind.message, strings: english);
      final ar = await engine.analyze(
          input: _scamMessage, kind: InputKind.message, strings: arabic);

      expect(ar.riskLevel, en.riskLevel);
      expect(ar.indicators.map((i) => i.id).toList(),
          en.indicators.map((i) => i.id).toList());
      expect(
        ar.indicators.map((i) => i.severity).toList(),
        en.indicators.map((i) => i.severity).toList(),
      );
    });

    test('a benign message stays LOW in both', () async {
      const input = 'Thanks, the invoice has been paid. Have a good day.';
      final en =
          await engine.analyze(input: input, kind: InputKind.message);
      final ar = await engine.analyze(
          input: input, kind: InputKind.message, strings: arabic);

      expect(en.riskLevel, RiskLevel.low);
      expect(ar.riskLevel, RiskLevel.low);
    });
  });

  group('Arabic output is actually translated', () {
    final engine = AnalysisEngine();

    test('headline and recommendation come back in Arabic', () async {
      final ar = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);

      expect(_arabicScript.hasMatch(ar.headline), isTrue);
      expect(_arabicScript.hasMatch(ar.recommendation), isTrue);
      expect(ar.headline, isNot(equals(english.headline(RiskLevel.high, 3))));
    });

    test('indicator titles and explanations come back in Arabic', () async {
      final ar = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);

      expect(ar.indicators, isNotEmpty);
      for (final indicator in ar.indicators) {
        expect(
          _arabicScript.hasMatch(indicator.title),
          isTrue,
          reason: '${indicator.id} title should be Arabic',
        );
        expect(
          _arabicScript.hasMatch(indicator.explanation),
          isTrue,
          reason: '${indicator.id} explanation should be Arabic',
        );
      }
    });

    test('the cash-claim indicator is localised too', () async {
      final ar = await engine.analyze(
          input: 'Claim your 500 USD reward.',
          kind: InputKind.message,
          strings: arabic);

      final claim =
          ar.indicators.firstWhere((i) => i.id == 'money_claim', orElse: () {
        throw StateError('money_claim missing, got ${ar.indicators}');
      });
      expect(_arabicScript.hasMatch(claim.title), isTrue,
          reason: 'money_claim title should be Arabic');
      expect(_arabicScript.hasMatch(claim.explanation), isTrue,
          reason: 'money_claim explanation should be Arabic');
      expect(claim.severity, IndicatorSeverity.warning);
      expect(ar.riskLevel, RiskLevel.low);
    });

    test('interpolated values survive translation', () async {
      final ar = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);

      // paypal appears in the example domain and must be kept verbatim,
      // together with the official domain the rule compares it against.
      final impersonation = ar.indicators
          .firstWhere((i) => i.id == 'brand_impersonation');
      expect(impersonation.explanation, contains('paypal'));
      expect(impersonation.explanation, contains('paypal.com'));
      expect(impersonation.title, contains('paypal'));

      // The suspicious TLD is a fact, not prose, so it must stay in Latin.
      final tld = ar.indicators.firstWhere((i) => i.id == 'suspicious_tld');
      expect(tld.explanation, contains('xyz'));
    });

    test('English analysis is untouched by the Arabic work', () async {
      final en = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: english);

      expect(_arabicScript.hasMatch(en.headline), isFalse);
      expect(_arabicScript.hasMatch(en.recommendation), isFalse);
      for (final indicator in en.indicators) {
        expect(_arabicScript.hasMatch(indicator.title), isFalse);
        expect(_arabicScript.hasMatch(indicator.explanation), isFalse);
      }
    });
  });

  group('the honest limit of Arabic support', () {
    final engine = AnalysisEngine();

    test('an Arabic-only scam message is NOT detected by the rules',
        () async {
      final ar = await engine.analyze(
          input: _arabicScamMessage, kind: InputKind.message, strings: arabic);

      expect(
        ar.indicators
            .where((i) => i.severity == IndicatorSeverity.critical),
        isEmpty,
        reason: 'the rules match English only, so no critical signal may be '
            'invented for Arabic wording',
      );
      expect(ar.riskLevel, isNot(RiskLevel.high));
    });

    test('the engine still reports the caveat rather than hiding it',
        () async {
      expect(arabic.detectionCoverageNote, contains('الإنجليزية'));
    });
  });

  group('right-to-left layout', () {
    testWidgets('the app is LTR in English', (tester) async {
      await pumpApp(tester);

      final context = tester.element(find.byType(Scaffold));
      expect(Directionality.of(context), TextDirection.ltr);
    });

    testWidgets('the app is RTL in Arabic', (tester) async {
      await pumpApp(tester, initial: arabic);

      final context = tester.element(find.byType(Scaffold));
      expect(Directionality.of(context), TextDirection.rtl);
    });

    testWidgets('the result screen is RTL in Arabic', (tester) async {
      await pumpApp(tester, initial: arabic);

      await tapVisible(tester, find.text(arabic.tryLinkExample));
      await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

      expect(find.text(arabic.riskLabel(RiskLevel.high)), findsOneWidget);
      final context = tester.element(find.byType(Scaffold));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  });

  group('language switching', () {
    testWidgets('switching to Arabic updates the UI immediately, no restart',
        (tester) async {
      await pumpApp(tester);

      expect(find.text(english.heroTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-note')), findsNothing);

      await tapVisible(
          tester, find.byKey(const ValueKey('language-button')));
      await tapVisible(tester, find.byKey(const ValueKey('lang-ar')));

      // Same session, same widget tree - only the strings changed.
      expect(find.text(arabic.heroTitle), findsOneWidget);
      expect(find.text(english.heroTitle), findsNothing);
      expect(find.text(arabic.analyseButton), findsOneWidget);
      expect(find.byKey(const ValueKey('coverage-note')), findsOneWidget);

      final context = tester.element(find.byType(Scaffold));
      expect(Directionality.of(context), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching back to English restores the original text',
        (tester) async {
      await pumpApp(tester);

      await tapVisible(
          tester, find.byKey(const ValueKey('language-button')));
      await tapVisible(tester, find.byKey(const ValueKey('lang-ar')));
      expect(find.text(arabic.heroTitle), findsOneWidget);

      await tapVisible(
          tester, find.byKey(const ValueKey('language-button')));
      await tapVisible(tester, find.byKey(const ValueKey('lang-en')));

      expect(find.text(english.heroTitle), findsOneWidget);
      expect(find.text(arabic.heroTitle), findsNothing);
      final context = tester.element(find.byType(Scaffold));
      expect(Directionality.of(context), TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a result analysed in Arabic is rendered in Arabic',
        (tester) async {
      await pumpApp(tester);

      await tapVisible(
          tester, find.byKey(const ValueKey('language-button')));
      await tapVisible(tester, find.byKey(const ValueKey('lang-ar')));

      await tapVisible(tester, find.text(arabic.tryMessageExample));
      await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

      expect(find.text(arabic.riskLabel(RiskLevel.high)), findsOneWidget);
      expect(find.byKey(const ValueKey('recommendation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('copy report', () {
    final engine = AnalysisEngine();

    test('follows the selected language', () async {
      final result = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);
      final report = ResultScreen(result: result).buildReport(arabic);

      expect(report, contains(arabic.riskLabel(RiskLevel.high)));
      expect(report, contains(arabic.reportWhyHeading));
      expect(report, contains(arabic.reportWhatToDoHeading));
      expect(report, contains(arabic.reportNoteHeading));
      expect(_arabicScript.hasMatch(report), isTrue);
    });

    test('preserves the entered text and URLs exactly', () async {
      final result = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: arabic);
      final report = ResultScreen(result: result).buildReport(arabic);

      expect(report, contains(_scamLink));
    });

    test('English report is unchanged', () async {
      final result = await engine.analyze(
          input: _scamLink, kind: InputKind.link, strings: english);
      final report = ResultScreen(result: result).buildReport(english);

      expect(report, contains('Scam Detection Field - HIGH RISK'));
      expect(report, contains('Why:'));
      expect(report, contains('What to do:'));
      expect(report, contains(_scamLink));
      expect(_arabicScript.hasMatch(report), isFalse);
    });
  });

  group('Arabic security advice is a warning, never an instruction', () {
    // The bare imperative for "send" must never appear in advice except
    // inside the negated form "لا ترسل" ("do not send").
    String withoutNegatedSend(String s) => s.replaceAll('لا ترسل', '');

    test('the Arabic secrets warning explicitly tells the user NOT to send',
        () {
      for (final level in RiskLevel.values) {
        final rec = arabic.recommendation(
          level,
          wantsSecrets: true,
          wantsMoney: true,
          hasLink: true,
        );
        expect(
          rec,
          contains('لا ترسل كلمة المرور'),
          reason: 'risk level $level must forbid sending credentials, '
              'but got: $rec',
        );
        expect(
          withoutNegatedSend(rec).contains('أرسل'),
          isFalse,
          reason: 'risk level $level reads as an instruction to send: $rec',
        );
      }
    });

    test('no recommendation branch in Arabic can read as "send"', () {
      for (final level in RiskLevel.values) {
        for (final secrets in [true, false]) {
          for (final money in [true, false]) {
            for (final link in [true, false]) {
              final rec = arabic.recommendation(
                level,
                wantsSecrets: secrets,
                wantsMoney: money,
                hasLink: link,
              );
              expect(
                withoutNegatedSend(rec).contains('أرسل'),
                isFalse,
                reason: 'bare imperative "send" in: $rec',
              );
            }
          }
        }
      }
    });

    test('no Arabic indicator, headline or advice can read as "send"',
        () async {
      final engine = AnalysisEngine();
      final ar = await engine.analyze(
        input: _scamMessage,
        kind: InputKind.message,
        strings: arabic,
      );

      final texts = <String>[
        ar.headline,
        ar.recommendation,
        for (final i in ar.indicators) ...[i.title, i.explanation],
      ];
      for (final text in texts) {
        expect(
          withoutNegatedSend(text).contains('أرسل'),
          isFalse,
          reason: 'bare imperative "send" in: $text',
        );
      }
    });

    test('the English secrets warning keeps its "Never send" wording', () {
      final rec = english.recommendation(
        RiskLevel.high,
        wantsSecrets: true,
        wantsMoney: true,
        hasLink: true,
      );
      expect(rec, contains('Never send a password, PIN or verification code'));
    });
  });

  group('no overflow on small phones', () {
    const small = Size(360, 640);

    testWidgets('Arabic home screen fits a 360x640 phone', (tester) async {
      await pumpApp(tester, initial: arabic, size: small);

      expect(find.text(arabic.heroTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('English home screen fits a 360x640 phone', (tester) async {
      await pumpApp(tester, size: small);

      expect(find.text(english.heroTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic result screen fits a 360x640 phone', (tester) async {
      await pumpApp(tester, initial: arabic, size: small);

      await tapVisible(tester, find.text(arabic.tryMessageExample));
      await tapVisible(tester, find.byKey(const ValueKey('analyze-button')));

      expect(find.text(arabic.riskLabel(RiskLevel.high)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AI fallback status is visible, in both languages', () {
    // The provider answers 429 on purpose, from a mock - no real key and no
    // network access, so this stays deterministic.
    Future<AnalysisResult> fallbackResult(AppStrings strings) =>
        AnalysisEngine(
          explainer: AiExplainer(
            const AiConfig(
              apiKey: 'test-key',
              baseUrl: 'https://example.invalid/v1',
              model: 'test-model',
            ),
            client: MockClient((r) async => http.Response(
                  'busy',
                  429,
                  headers: {'content-type': 'text/plain'},
                )),
          ),
        ).analyze(input: _scamLink, kind: InputKind.link, strings: strings);

    Future<void> pumpResult(
      WidgetTester tester,
      AnalysisResult result,
      AppStrings strings,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            // Matches the real app, where the scope sits above MaterialApp and
            // decides the writing direction for the whole tree.
            textDirection:
                strings.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: StringsScope(
              strings: strings,
              onChanged: (_) {},
              child: ResultScreen(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the English reason is shown beside the fallback note',
        (tester) async {
      final result = await fallbackResult(english);
      expect(result.mode, AnalysisMode.rulesWithAiFallback);
      expect(result.aiFailure, AiFailure.rateLimited);

      await pumpResult(tester, result, english);

      expect(find.byKey(const ValueKey('ai-failure-note')), findsOneWidget);
      expect(
        find.text(english.aiFailureNote(result.aiFailure!)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Arabic reason is rendered in Arabic', (tester) async {
      final result = await fallbackResult(arabic);

      await pumpResult(tester, result, arabic);

      final note =
          tester.widget<Text>(find.byKey(const ValueKey('ai-failure-note')));
      expect(note.data, arabic.aiFailureNote(AiFailure.rateLimited));
      expect(_arabicScript.hasMatch(note.data!), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a result with no AI failure shows no failure reason',
        (tester) async {
      // No key configured, so nothing was attempted and nothing failed.
      final result = await AnalysisEngine()
          .analyze(input: _scamLink, kind: InputKind.link, strings: english);
      expect(result.mode, AnalysisMode.rulesOnly);
      expect(result.aiFailure, isNull);

      await pumpResult(tester, result, english);

      expect(find.byKey(const ValueKey('ai-failure-note')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a successful AI step shows no failure reason either',
        (tester) async {
      final okBody = jsonEncode({
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
      });

      final result = await AnalysisEngine(
        explainer: AiExplainer(
          const AiConfig(
            apiKey: 'test-key',
            baseUrl: 'https://example.invalid/v1',
            model: 'test-model',
          ),
          client: MockClient((r) async => http.Response(
                okBody,
                200,
                headers: {'content-type': 'application/json'},
              )),
        ),
      ).analyze(input: _scamLink, kind: InputKind.link, strings: english);

      expect(result.mode, AnalysisMode.rulesAndAi);
      expect(result.aiFailure, isNull);

      await pumpResult(tester, result, english);

      expect(find.byKey(const ValueKey('ai-failure-note')), findsNothing);
    });

    test('the copied report keeps the fallback status too', () async {
      final result = await fallbackResult(arabic);
      final report = ResultScreen(result: result).buildReport(arabic);

      expect(
        report,
        contains(arabic.modeText(AnalysisMode.rulesWithAiFallback)),
      );
      expect(report, contains(arabic.aiFailureNote(AiFailure.rateLimited)));
    });

    test('every failure category has its own note, in both languages', () {
      final englishNotes = <String, AiFailure>{};
      final arabicNotes = <String, AiFailure>{};
      for (final failure in AiFailure.values) {
        final en = english.aiFailureNote(failure);
        final ar = arabic.aiFailureNote(failure);

        expect(en, isNotEmpty, reason: failure.name);
        expect(en, startsWith('Reason:'), reason: failure.name);
        expect(ar, isNotEmpty, reason: failure.name);
        expect(_arabicScript.hasMatch(ar), isTrue,
            reason: 'must actually be translated: ${failure.name}');

        englishNotes[en] = failure;
        arabicNotes[ar] = failure;
      }
      expect(englishNotes.length, AiFailure.values.length,
          reason: 'distinct categories must not collapse into one sentence');
      expect(arabicNotes.length, AiFailure.values.length);
    });
  });
}
