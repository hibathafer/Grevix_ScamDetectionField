import 'package:flutter_test/flutter_test.dart';
import 'package:scam_detection_field/analysis/analysis_engine.dart';
import 'package:scam_detection_field/analysis/input_classifier.dart';
import 'package:scam_detection_field/models/analysis_result.dart';

// Feedback from a tester studying cybersecurity: pasting free text into the
// Link tab returned LOW RISK. Nothing usable had been checked, so the result
// must be an error, never a risk level.
//
// Everything here is pure Dart and offline - `validateLink` parses the
// address and never opens it.

void main() {
  final engine = AnalysisEngine();

  group('URL validation - valid addresses keep working exactly as before', () {
    test('every shape people actually paste is still analysed', () async {
      const valid = [
        'https://example.com',
        'http://example.com',
        'example.com',
        'www.example.com',
        'example.com/help',
        'example.com/path?q=1#frag',
        'https://sub.domain.example.co.uk/a/b',
        'http://paypal-secure-login.verify-account.xyz/session/update',
        'EXAMPLE.COM/Help',
      ];
      for (final url in valid) {
        final result = await engine.analyze(input: url, kind: InputKind.link);
        expect(result.riskLevel, isNotNull, reason: '$url must be analysed');
        expect(result.kind, InputKind.link, reason: url);
      }
    });

    test('https://example.com is still LOW RISK, unchanged', () async {
      final result =
          await engine.analyze(input: 'https://example.com', kind: InputKind.link);
      expect(result.riskLevel, RiskLevel.low);
      expect(result.headline, isNotEmpty);
    });

    test('raw IP hosts stay valid, because the rules flag them on purpose',
        () async {
      const addresses = [
        'http://192.168.0.1/login',
        'http://127.0.0.1:8080/admin',
      ];
      for (final url in addresses) {
        expect(validateLink(url), isNull, reason: '$url must not be refused');
        final result = await engine.analyze(input: url, kind: InputKind.link);
        expect(result.riskLevel, isNotNull, reason: url);
        expect(result.indicators.map((i) => i.id), contains('ip_host'),
            reason: 'validation must not hide the rule that flags it');
      }
    });

    test('an octet above 255 is not a host', () {
      expect(validateLink('http://999.1.1.1/x'), UrlRejection.malformed);
    });

    test('localhost is a real address, so it is not called invalid', () {
      expect(validateLink('http://localhost'), isNull);
      expect(validateLink('localhost:8080'), isNull);
    });
  });

  group('URL validation - random text is refused instead of scored', () {
    test('free text never reaches the scorer', () async {
      const garbage = [
        'please call me back when you can',
        'hello world',
        'this is not a link at all',
        '### ??? !!! @@@ 00000 ...',
        '...',
        'asdf',
        '3.14',
        'a.b',
        'example.c',
      ];
      for (final input in garbage) {
        await expectLater(
          engine.analyze(input: input, kind: InputKind.link),
          throwsA(isA<InvalidUrlException>()),
          reason: '"$input" is not a website address',
        );
      }
    });

    test('an invalid URL never receives a risk level', () async {
      // The exception is thrown before `RiskScorer.level` runs, so no level,
      // no signals and no recommendation are ever produced.
      Object? caught;
      try {
        await engine.analyze(input: 'random words here', kind: InputKind.link);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<InvalidUrlException>());
      expect(caught, isNot(isA<AnalysisResult>()));
    });
  });

  group('URL validation - malformed addresses and missing hosts', () {
    test('an address with no host is rejected', () {
      expect(validateLink('http://'), UrlRejection.missingHost);
      expect(validateLink('https://'), UrlRejection.missingHost);
      expect(validateLink('http:///path'), UrlRejection.missingHost);
    });

    test('a value with spaces is rejected as prose', () {
      expect(validateLink('not a url'), UrlRejection.hasSpaces);
      expect(validateLink(' example.com '), isNull,
          reason: 'surrounding spaces alone are just pasting noise');
      expect(validateLink('example.com/a b'), UrlRejection.hasSpaces);
    });

    test('anything unparseable is rejected as malformed', () {
      const malformed = ['...', 'http://...', '999.1.1.1', 'a.b', 'example.c'];
      for (final value in malformed) {
        expect(validateLink(value), isNotNull, reason: value);
      }
    });
  });

  group('URL validation - unsupported schemes', () {
    test('only http and https are accepted', () {
      const unsupported = [
        'ftp://example.com',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'mailto:someone@example.com',
        'data:text/html,hello',
        'ws://example.com',
      ];
      for (final value in unsupported) {
        expect(validateLink(value), UrlRejection.unsupportedScheme,
            reason: value);
      }
    });

    test('a rejected scheme also stops the engine', () async {
      await expectLater(
        engine.analyze(input: 'ftp://example.com', kind: InputKind.link),
        throwsA(isA<InvalidUrlException>()),
      );
      await expectLater(
        engine.analyze(input: 'javascript:alert(1)', kind: InputKind.link),
        throwsA(isA<InvalidUrlException>()),
      );
    });
  });

  group('URL validation - message mode is unaffected', () {
    test('the same free text is analysed normally as a message', () async {
      final result = await engine.analyze(
          input: 'please call me back when you can', kind: InputKind.message);
      expect(result.riskLevel, RiskLevel.low);
      expect(result.kind, InputKind.message);
      expect(result.recommendation, isNotEmpty);
    });

    test('a message is never refused for containing a bad link', () async {
      final result = await engine.analyze(
        input: 'open http:// and tell me what you see',
        kind: InputKind.message,
      );
      expect(result.kind, InputKind.message);
      expect(result.riskLevel, isNotNull);
    });
  });
}
