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

  group('negation - advice against disclosure is not a request', () {
    List<String> idsOf(List<Indicator> findings) =>
        findings.map((f) => f.id).toList();

    // 1. A security-awareness message must not be read as a request.
    test('a warning never to share an OTP is not a request', () {
      final findings = analyzeMessage('Never share your OTP with anyone.');
      expect(idsOf(findings), isNot(contains('sensitive_request')));
      expect(RiskScorer.level(findings), RiskLevel.low);
      // It is still honest that the message mentions a code.
      expect(idsOf(findings), contains('sensitive_words'));
    });

    // 2. An explicitly negated action is advice, not pressure to act.
    test('a negated password instruction raises no action pressure', () {
      final findings =
          analyzeMessage('Do not send your password to this number.');
      expect(idsOf(findings), isNot(contains('call_to_action')));
      expect(idsOf(findings), isNot(contains('sensitive_request')));
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('other directly negated actions are not pressure either', () {
      const warnings = [
        'Do not click the link in this message.',
        'Do not reply with your details.',
        'Please do not update your account details.',
        'Do not download the attached file.',
      ];
      for (final message in warnings) {
        expect(idsOf(analyzeMessage(message)),
            isNot(contains('call_to_action')),
            reason: 'negated advice reported as pressure: $message');
      }
    });

    // 3. A consequence attached to the negation makes it coercion - but only
    //    when the penalty is the price of refusing.
    test('a conditional threat still demands the secret and stays HIGH', () {
      final findings = analyzeMessage(
          'If you do not send your PIN, your account will be closed.');
      expect(idsOf(findings), contains('threat'));
      expect(
        idsOf(findings),
        contains('sensitive_request'),
        reason: 'a conditional penalty turns the negation into a demand',
      );
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('a penalty alone does not turn a warning into a request', () {
      // The penalty here is not the price of refusing to hand anything over,
      // so this stays advice against disclosure.
      const warnings = [
        'Never share your PIN, or your account will be closed.',
        'Never share your password, or you will be charged.',
      ];
      for (final message in warnings) {
        final findings = analyzeMessage(message);
        expect(
          idsOf(findings),
          isNot(contains('sensitive_request')),
          reason: 'a mentioned penalty alone was treated as coercion: $message',
        );
        expect(RiskScorer.level(findings), isNot(RiskLevel.high),
            reason: message);
      }

      // The account-closing penalty is still reported, for what it is.
      expect(
        idsOf(analyzeMessage(
            'Never share your PIN, or your account will be closed.')),
        contains('threat'),
      );
    });

    test('other conditional phrasings are still demands', () {
      const coerced = [
        "If you don't send your PIN today, your account will be blocked.",
        'Unless you send your OTP, your account will be closed.',
      ];
      for (final message in coerced) {
        final findings = analyzeMessage(message);
        expect(idsOf(findings), contains('sensitive_request'),
            reason: message);
        expect(RiskScorer.level(findings), RiskLevel.high, reason: message);
      }
    });

    test('a plain prohibition still stays LOW', () {
      const plain = [
        'Never share your PIN or password with anyone.',
        'Do not send your password to anyone claiming to be from the bank.',
      ];
      for (final message in plain) {
        final findings = analyzeMessage(message);
        expect(idsOf(findings), isNot(contains('sensitive_request')),
            reason: message);
        expect(RiskScorer.level(findings), isNot(RiskLevel.high),
            reason: message);
      }
    });

    // 4. A request in one sentence and a code in the next is still caught.
    test('a request is connected to a code given in another sentence', () {
      final findings =
          analyzeMessage('Please send this to verify. Your code: 482913');
      expect(idsOf(findings), contains('sensitive_request'));
      expect(RiskScorer.level(findings), RiskLevel.high);
    });

    test('a code handed over without any request is still not a request',
        () {
      final findings = analyzeMessage('Your OTP: 482913. Do not share it '
          'with anyone.');
      expect(idsOf(findings), isNot(contains('sensitive_request')));
      expect(RiskScorer.level(findings), RiskLevel.low);
    });

    test('genuine requests are unaffected by the negation handling', () {
      const requests = [
        'Please send your password.',
        'Send us your OTP now.',
        'Do not hesitate to provide your bank details.',
        "Don't forget to share your verification code to continue.",
        'Your account cannot be unlocked unless you send your PIN.',
        'We cannot proceed until you send your OTP.',
        'Do not delay and send your password now.',
      ];
      for (final message in requests) {
        expect(idsOf(analyzeMessage(message)), contains('sensitive_request'),
            reason: 'genuine request lost: $message');
        expect(RiskScorer.level(analyzeMessage(message)), RiskLevel.high,
            reason: message);
      }
    });

    test('an un-negated push to act is still reported', () {
      final findings = analyzeMessage('Click here to claim your prize.');
      expect(idsOf(findings), contains('call_to_action'));
    });
  });
}
