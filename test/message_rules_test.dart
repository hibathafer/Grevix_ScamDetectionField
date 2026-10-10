import 'package:flutter_test/flutter_test.dart';
import 'package:scam_detection_field/analysis/message_rules.dart';
import 'package:scam_detection_field/analysis/risk_scorer.dart';
import 'package:scam_detection_field/models/analysis_result.dart';

void main() {
  group('analyzeMessage - everyday messages', () {
    test('a normal conversation produces no risk signals', () {
      final findings = analyzeMessage('Hey, are we still meeting at 5pm?');
      expect(findings.where((i) => i.severity != IndicatorSeverity.info),
          isEmpty);
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('an empty message returns nothing and does not throw', () {
      expect(analyzeMessage(''), isEmpty);
      expect(analyzeMessage('      '), isEmpty);
    });

    test('a work message with an attachment is not treated as critical', () {
      final findings = analyzeMessage(
          'Please review the attached report and send me your comments.');
      expect(
          findings.where((i) => i.severity == IndicatorSeverity.critical),
          isEmpty);
      expect(RiskScorer.level(findings), isNot(RiskLevel.high));
    });

    test('merely mentioning a password is only a warning', () {
      final findings =
          analyzeMessage('You can change your password in account settings.');
      expect(findings.map((i) => i.id), contains('sensitive_words'));
      expect(findings.map((i) => i.id), isNot(contains('sensitive_request')));
      expect(RiskScorer.level(findings), isNot(RiskLevel.high));
    });
  });

  group('analyzeMessage - scam patterns', () {
    test('asking for a password is a critical signal', () {
      final findings = analyzeMessage(
          'Please send me your password so I can verify the account.');
      expect(findings.map((i) => i.id), contains('sensitive_request'));
      expect(findings.firstWhere((i) => i.id == 'sensitive_request').severity,
          IndicatorSeverity.critical);
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('a 4-digit verification code on its own is caught', () {
      final findings =
          analyzeMessage('Your code: 482913. Share it to confirm your login.');
      expect(findings.map((i) => i.id), contains('sensitive_request'));
    });

    test('urgency and threats are detected', () {
      final findings = analyzeMessage(
          'URGENT: your account will be suspended in 24 hours.');
      expect(findings.map((i) => i.id), contains('urgency'));
      expect(findings.map((i) => i.id), contains('threat'));
    });

    test('fake prizes are a critical signal', () {
      final findings = analyzeMessage(
          'Congratulations! You have won the lottery. Claim your prize now.');
      expect(findings.map((i) => i.id), contains('prize_reward'));
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('gift card payment demands are critical', () {
      final findings = analyzeMessage(
          'Send the payment as a gift card so we can release your funds.');
      expect(findings.map((i) => i.id), contains('payment_demand'));
    });

    test('secrecy requests are detected', () {
      final findings = analyzeMessage(
          'Do not tell anyone about this offer, keep it confidential.');
      expect(findings.map((i) => i.id), contains('secrecy'));
    });

    test('too-good-to-be-true offers are detected', () {
      final findings =
          analyzeMessage('Earn 5000 per day with guaranteed profit!');
      expect(findings.map((i) => i.id), contains('too_good'));
    });
  });

  group('analyzeMessage - unexpected input', () {
    test('random symbols and emoji do not crash the rules', () {
      final findings = analyzeMessage('### ??? 😱💥 @@@ 12345 !!!!');
      expect(findings, isA<List<Indicator>>());
    });

    test('very long noisy text is handled', () {
      final findings = analyzeMessage(List.filled(500, 'hello world').join(' '));
      expect(findings, isA<List<Indicator>>());
    });

    test('every finding carries a plain-English explanation', () {
      final findings = analyzeMessage(
          'URGENT: send me your password to claim your prize now!');
      for (final finding in findings) {
        expect(finding.explanation.length, greaterThan(30),
            reason: '${finding.id} must explain itself');
      }
    });
  });
}
