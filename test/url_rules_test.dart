import 'package:flutter_test/flutter_test.dart';
import 'package:scam_detection_field/analysis/risk_scorer.dart';
import 'package:scam_detection_field/analysis/url_rules.dart';
import 'package:scam_detection_field/models/analysis_result.dart';

void main() {
  group('analyzeLink - safe addresses', () {
    test('a normal https address produces no warning or critical signal', () {
      final findings = analyzeLink('https://www.google.com/search?q=weather');
      expect(findings.where((i) => i.severity != IndicatorSeverity.info),
          isEmpty);
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('a bare domain without scheme is still understood', () {
      final findings = analyzeLink('example.com/help');
      expect(findings.where((i) => i.severity != IndicatorSeverity.info),
          isEmpty);
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('an empty input returns no findings and does not throw', () {
      expect(analyzeLink(''), isEmpty);
      expect(analyzeLink('     '), isEmpty);
    });

    test('an official brand domain is not flagged as impersonation', () {
      final findings = analyzeLink('https://www.paypal.com/signin');
      final brandSignals =
          findings.where((i) => i.id.startsWith('brand')).toList();
      expect(brandSignals, isEmpty);
      expect(RiskScorer.level(findings), RiskLevel.low);
    });
  });

  group('analyzeLink - suspicious addresses', () {
    test('credential wording plus a brand is a critical signal', () {
      final findings =
          analyzeLink('http://paypal-secure-login.verify-account.xyz/session/update');
      expect(findings.map((i) => i.id), contains('brand_impersonation'));
      expect(findings.map((i) => i.id), contains('suspicious_domain_words'));
      expect(findings.map((i) => i.id), contains('suspicious_tld'));
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('a public IP address as host is critical', () {
      final findings = analyzeLink('http://45.67.89.123/update-account');
      expect(findings.map((i) => i.id), contains('ip_host'));
      final ip = findings.firstWhere((i) => i.id == 'ip_host');
      expect(ip.severity, IndicatorSeverity.critical);
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('a private IP address is only a warning, not critical', () {
      final findings = analyzeLink('http://192.168.1.1/admin');
      final ip = findings.firstWhere((i) => i.id == 'ip_host');
      expect(ip.severity, IndicatorSeverity.warning);
      expect(RiskScorer.level(findings), isNot(RiskLevel.high));
    });

    test('text before @ hides the real destination', () {
      final findings = analyzeLink('http://paypal.com@evil-example.xyz/pay');
      expect(findings.map((i) => i.id), contains('userinfo_at'));
      expect(findings.firstWhere((i) => i.id == 'userinfo_at').severity,
          IndicatorSeverity.critical);
    });

    test('punycode / homograph addresses are critical', () {
      final findings = analyzeLink('https://xn--pypal-4ve.com/signin');
      expect(findings.map((i) => i.id), contains('homograph'));
    });

    test('the brand placed before the real domain is critical', () {
      final findings = analyzeLink('https://paypal.com.evil-host.ru/login');
      expect(findings.map((i) => i.id), contains('spoofed_structure'));
    });

    test('a link shortener only raises a warning', () {
      final findings = analyzeLink('https://bit.ly/3abcdef');
      expect(findings.map((i) => i.id), contains('shortener'));
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('a downloadable executable is critical', () {
      final findings = analyzeLink('https://files.example-secure.top/invoice.apk');
      expect(findings.map((i) => i.id), contains('dangerous_download'));
    });

    test('a password in the query string is critical', () {
      final findings =
          analyzeLink('https://account-check.example.com/?password=hunter2');
      expect(findings.map((i) => i.id), contains('credential_in_query'));
    });

    test('a plain http connection is only a warning', () {
      final findings = analyzeLink('http://example.com/news');
      final httpSignal = findings.firstWhere((i) => i.id == 'http_scheme');
      expect(httpSignal.severity, IndicatorSeverity.warning);
      expect(RiskScorer.level(findings), RiskLevel.low);
    });
  });

  group('analyzeLink - unexpected input', () {
    test('non-URL text never throws and never invents a critical signal', () {
      final findings = analyzeLink('please call me back when you can');
      expect(
        findings.where((i) => i.severity == IndicatorSeverity.critical),
        isEmpty,
      );
    });

    test('a broken address is reported instead of crashing', () {
      final findings = analyzeLink('http://');
      expect(findings.map((i) => i.id), contains('malformed'));
    });

    test('every finding carries a plain-English explanation', () {
      final findings =
          analyzeLink('http://paypal-secure-login.verify-account.xyz/update');
      for (final finding in findings) {
        expect(finding.explanation.length, greaterThan(30),
            reason: '${finding.id} must explain itself');
        expect(finding.title, isNotEmpty);
      }
    });
  });
}
