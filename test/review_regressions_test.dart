import 'package:flutter_test/flutter_test.dart';
import 'package:scam_detection_field/analysis/analysis_engine.dart';
import 'package:scam_detection_field/analysis/message_rules.dart';
import 'package:scam_detection_field/analysis/risk_scorer.dart';
import 'package:scam_detection_field/analysis/url_rules.dart';
import 'package:scam_detection_field/l10n/app_strings_ar.dart';
import 'package:scam_detection_field/models/analysis_result.dart';

// Regression tests for the issues raised in the independent code review.
//
// Each group pins the behaviour that was reported, so a future change cannot
// silently reintroduce it.

List<String> ids(List<Indicator> findings) => findings.map((f) => f.id).toList();

/// Matches Arabic script, used to check that translated text really is
/// translated rather than falling back to English.
final _arabicScript = RegExp(r'[؀-ۿ]');

void main() {
  group('review: security warnings are not requests for secrets', () {
    test('an OTP delivery warning is not an ask for private information', () {
      final f = analyzeMessage(
          'Your OTP is 482913. Do not share it with anyone.');
      expect(ids(f), isNot(contains('sensitive_request')));
      expect(ids(f), contains('sensitive_words'));
      expect(RiskScorer.level(f), RiskLevel.low);
    });

    test('a warning never to share a PIN or password is not an ask', () {
      final f = analyzeMessage('Never share your PIN or password with anyone.');
      expect(ids(f), isNot(contains('sensitive_request')));
      expect(ids(f), contains('sensitive_words'));
      expect(RiskScorer.level(f), RiskLevel.low);
    });

    test('other prohibitive phrasings are also not asks', () {
      for (final message in [
        'Do not send your password to anyone claiming to be from the bank.',
        'Never share your verification code with anybody.',
        'Nobody should ever give out their PIN.',
      ]) {
        expect(
          ids(analyzeMessage(message)),
          isNot(contains('sensitive_request')),
          reason: 'prohibitive message wrongly flagged: $message',
        );
      }
    });

    test('a genuine request for a password is still critical', () {
      final f = analyzeMessage(
          'Please send your password and verification code to confirm your '
          'identity.');
      expect(ids(f), contains('sensitive_request'));
      expect(
        f.firstWhere((i) => i.id == 'sensitive_request').severity,
        IndicatorSeverity.critical,
      );
      expect(RiskScorer.level(f), RiskLevel.high);
    });

    test('a genuine request for an OTP is still critical', () {
      final f = analyzeMessage('Send us your OTP now to secure your account.');
      expect(ids(f), contains('sensitive_request'));
      expect(RiskScorer.level(f), RiskLevel.high);
    });
  });

  group('review: brand matching must not fire on substrings', () {
    // Every one of these used to be reported as brand impersonation because
    // the check was a raw substring test on the host.
    const falsePositives = {
      'purchase-account.com': 'chase',
      'pineapple.com': 'apple',
      'login.microsoftonline.com': 'microsoft',
      'amazon.co.uk': 'amazon',
    };

    falsePositives.forEach((domain, embeddedBrand) {
      test('$domain is not impersonating "$embeddedBrand"', () {
        final f = analyzeLink(domain);
        expect(
          ids(f).where((id) => id.startsWith('brand')),
          isEmpty,
          reason: '$domain must not be reported as a brand match',
        );
        expect(
          f.any((i) => i.severity == IndicatorSeverity.critical),
          isFalse,
          reason: '$domain must not be given a critical signal',
        );
        expect(RiskScorer.level(f), isNot(RiskLevel.high));
      });
    });

    test('a real lookalike is still caught as impersonation', () {
      final f = analyzeLink('http://paypal-secure-login.verify-account.xyz/');
      expect(ids(f), contains('brand_impersonation'));
      expect(RiskScorer.level(f), RiskLevel.high);
    });

    test('a brand used as a fake sub-domain is still critical', () {
      final f = analyzeLink('http://paypal.com.secure-login.xyz/');
      expect(ids(f), contains('spoofed_structure'));
    });

    test('the official domain itself is never flagged', () {
      for (final official in ['paypal.com', 'amazon.co.uk', 'google.com']) {
        expect(
          ids(analyzeLink('https://$official/')).where((i) => i.startsWith('brand')),
          isEmpty,
          reason: '$official is legitimate',
        );
      }
    });
  });

  group('review: query text must not drive file-extension rules', () {
    test('a .com query value is not read as a program download', () {
      final f = analyzeLink('http://example.com/page?ref=site.com');
      expect(ids(f), isNot(contains('dangerous_download')));
      expect(RiskScorer.level(f), isNot(RiskLevel.high));
    });

    test('file.exe?id=1 is not reported as a download', () {
      expect(ids(analyzeLink('file.exe?id=1')),
          isNot(contains('dangerous_download')));
    });

    test('a genuine executable in the path is still critical', () {
      final f = analyzeLink('http://example.com/download/report.exe');
      expect(ids(f), contains('dangerous_download'));
      expect(
        f.firstWhere((i) => i.id == 'dangerous_download').severity,
        IndicatorSeverity.critical,
      );
    });

    test('a checkpoint word in the path is still found when a query follows',
        () {
      final f = analyzeLink('http://example.com/login?next=/home');
      expect(ids(f), contains('checkpoint_path'));
    });

    test('a normal page carries no checkpoint signal', () {
      expect(ids(analyzeLink('http://example.com/products/list')),
          isNot(contains('checkpoint_path')));
    });
  });

  group('review: subtle scam messages', () {
    test('a parcel release-fee message is flagged, but not as HIGH', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your parcel is held. Pay a small fee at the link to release it.',
        kind: InputKind.message,
      );
      expect(r.indicators.map((i) => i.id), contains('fee_request'));
      expect(
        r.riskLevel,
        isNot(RiskLevel.high),
        reason: 'one fee warning on its own is not enough evidence for HIGH',
      );
      // The explanation must describe the signal actually detected.
      final fee = r.indicators.firstWhere((i) => i.id == 'fee_request');
      expect(fee.title.toLowerCase(), contains('fee'));
    });

    test('an unsolicited reward claim is not automatically HIGH', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );
      expect(
        r.riskLevel,
        isNot(RiskLevel.high),
        reason: 'a short reward line alone is not enough evidence for HIGH',
      );
    });
  });

  group('review: counts agree and evidence is not double counted', () {
    const inputs = [
      'http://paypal-secure-login.verify-account.xyz/session/update',
      'http://45.67.89.123/update-account',
      'http://192.168.1.1/admin',
      'URGENT! Your account will be suspended. Send your OTP to '
          'http://verify-account.xyz/login',
      'Thanks, the invoice is paid.',
    ];

    test('the same arithmetic holds for every input', () async {
      final engine = AnalysisEngine();
      for (final input in inputs) {
        final kind =
            input.startsWith('http') ? InputKind.link : InputKind.message;
        final r = await engine.analyze(input: input, kind: kind);
        final sum = r.criticalCount + r.warningCount + r.contextNotes.length;
        expect(
          sum,
          r.indicators.length,
          reason: 'counts disagree for: $input',
        );
        expect(r.signalCount, r.indicators.length - r.contextNotes.length,
            reason: 'signal count disagrees for: $input');
      }
    });

    test('the brand signal and the word signal never repeat the same words',
        () {
      final f =
          analyzeLink('http://paypal-secure-login.verify-account.xyz/session/update');
      final brand = f.where((i) => i.id == 'brand_impersonation');
      final words = f.where((i) => i.id == 'suspicious_domain_words');
      if (brand.isNotEmpty && words.isNotEmpty) {
        final brandWords =
            (brand.first.params['words'] ?? '').split(', ').toSet();
        final domainWords =
            (words.first.params['words'] ?? '').split(', ').toSet();
        expect(
          domainWords.difference(brandWords),
          isNotEmpty,
          reason: 'the word signal must add evidence the brand signal lacks',
        );
      }
    });

    test('extra credential wording still raises a second, distinct signal',
        () {
      // "account" is not cited by the brand signal here, so it is genuinely
      // additional evidence and may be reported separately.
      final f = analyzeLink('http://paypal-secure-login.account.xyz/');
      expect(ids(f), contains('brand_impersonation'));
      expect(RiskScorer.level(f), RiskLevel.high);
    });
  });

  group('review 2: negation must not hide pressure to disclose', () {
    // A prohibition governing the verb directly is a warning against
    // disclosure. Anything that pressures the user must still be caught.
    const warningsAgainstDisclosure = [
      'Never share your PIN or password with anyone.',
      'Do not send your password to anyone claiming to be from the bank.',
    ];

    test('plain prohibitions are not treated as requests', () {
      for (final message in warningsAgainstDisclosure) {
        final f = analyzeMessage(message);
        expect(ids(f), isNot(contains('sensitive_request')), reason: message);
        expect(RiskScorer.level(f), isNot(RiskLevel.high), reason: message);
      }
    });

    test('the curly apostrophe is handled the same as a straight one', () {
      for (final message in [
        "Don't share your PIN or password with anyone.",
        'Don\u2019t share your PIN or password with anyone.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), isNot(contains('sensitive_request')), reason: message);
        expect(RiskScorer.level(f), isNot(RiskLevel.high), reason: message);
      }
    });

    test('a code beside a number is not a request on its own', () {
      for (final message in [
        'Your OTP: 482913. Do not share it with anyone.',
        'Your OTP is 482913. Do not share it with anyone.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), isNot(contains('sensitive_request')), reason: message);
        expect(RiskScorer.level(f), isNot(RiskLevel.high), reason: message);
      }
    });

    test('a line break inside a sentence does not hide a request', () {
      final f = analyzeMessage('Please reply with\nyour OTP.');
      expect(ids(f), contains('sensitive_request'));
      expect(RiskScorer.level(f), RiskLevel.high);
    });

    test('pressure wording is still detected despite a leading negation', () {
      const pressured = [
        "Don't forget to share your verification code to continue.",
        'Do not hesitate to provide your bank details.',
        'Your account cannot be unlocked unless you send your PIN.',
        'We cannot proceed until you send your OTP.',
        'Do not delay and send your password now.',
      ];
      for (final message in pressured) {
        final f = analyzeMessage(message);
        expect(
          ids(f),
          contains('sensitive_request'),
          reason: 'pressure message wrongly treated as safe: $message',
        );
        expect(RiskScorer.level(f), RiskLevel.high, reason: message);
      }
    });

    test('unambiguous requests stay critical', () {
      for (final message in [
        'Please send your password.',
        'Send us your OTP now.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), contains('sensitive_request'), reason: message);
        expect(
          f.firstWhere((i) => i.id == 'sensitive_request').severity,
          IndicatorSeverity.critical,
          reason: message,
        );
      }
    });

    test('a code handed over with a request is still critical', () {
      final f =
          analyzeMessage('Your code: 482913. Share it to confirm your login.');
      expect(ids(f), contains('sensitive_request'));
    });
  });

  group('review 2: brand lookalikes and path/query boundaries', () {
    test('credential wording glued to a brand label is still caught', () {
      for (final domain in ['paypalsecure-login.com', 'securepaypal.com']) {
        final f = analyzeLink(domain);
        expect(ids(f), contains('brand_impersonation'), reason: domain);
        expect(RiskScorer.level(f), RiskLevel.high, reason: domain);
      }
    });

    test('lookalikes that only borrow a brand shape are not impersonation',
        () {
      // Documented limitation: label-exact matching does not catch these, but
      // they are still reported through other signals where applicable.
      for (final domain in [
        'pineapple.com',
        'login.microsoftonline.com',
        'appleid-verify.xyz',
        'amazonsupport.top',
      ]) {
        final f = analyzeLink(domain);
        expect(
          ids(f).where((id) => id.startsWith('brand')),
          isEmpty,
          reason: '$domain must not be reported as a brand match',
        );
      }
    });

    test('query text alone does not raise a path checkpoint warning', () {
      expect(ids(analyzeLink('https://example.com/search?q=update+account')),
          isNot(contains('checkpoint_path')));
    });

    test('a checkout path is not read as a brand mention', () {
      final f = analyzeLink('https://example.com/purchase/confirm');
      expect(ids(f).where((id) => id.startsWith('brand')), isEmpty);
    });

    test('a later public IP is not hidden by an earlier private one',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'try http://192.168.1.1/admin or http://45.67.89.123/update',
        kind: InputKind.message,
      );
      final ipHost = r.indicators.where((i) => i.id == 'ip_host').toList();
      expect(ipHost, hasLength(1));
      expect(
        ipHost.single.severity,
        IndicatorSeverity.critical,
        reason: 'deduplication kept the private warning and hid the critical',
      );
      expect(r.riskLevel, RiskLevel.high);
    });
  });

  group('review 3: escalation needs sufficient evidence', () {
    test('a fee mention plus a link does not jump to HIGH by itself',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your parcel is held. Pay a small fee at the link to release '
            'it. http://example.com/pay',
        kind: InputKind.message,
      );
      expect(r.indicators.map((i) => i.id), contains('fee_request'));
      expect(
        r.riskLevel,
        isNot(RiskLevel.high),
        reason: 'fee + link alone is not enough evidence for HIGH',
      );
      // It is still reported, just not escalated.
      expect(r.indicators.map((i) => i.id),
          isNot(contains('combined_link_request')));
    });

    test('a link plus a genuine request for money or details is still '
        'escalated', () async {
      final r = await AnalysisEngine().analyze(
        input: 'URGENT! Your bank account will be suspended in 24 hours. Send '
            'your OTP and password to verify, then click the link to claim '
            'your reward: http://claim-prize.verify-account.xyz/win',
        kind: InputKind.message,
      );
      expect(r.indicators.map((i) => i.id),
          contains('combined_link_request'));
      expect(r.riskLevel, RiskLevel.high);
    });

    test('a congratulation on its own is not a fake prize', () {
      final f = analyzeMessage('Congratulations on the new job!');
      expect(ids(f), isNot(contains('prize_reward')));
      expect(RiskScorer.level(f), isNot(RiskLevel.high));
    });

    test('a real fake-prize message is still critical', () {
      final f = analyzeMessage(
          'Congratulations! You have won the lottery. Claim your prize now.');
      expect(ids(f), contains('prize_reward'));
      expect(RiskScorer.level(f), RiskLevel.high);
    });

    test('an unsolicited reward claim is not automatically HIGH', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );
      expect(r.riskLevel, isNot(RiskLevel.high));
    });
  });

  group('review 4: a concrete cash amount told to "claim"', () {
    test('a stated money amount gets a warning and stays LOW', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );

      final claim = r.indicators
          .firstWhere((i) => i.id == 'money_claim', orElse: () => throw '');
      expect(claim.severity, IndicatorSeverity.warning);
      expect(r.indicators, hasLength(1));
      expect(
        r.riskLevel,
        RiskLevel.low,
        reason: 'a single warning must not escalate the message',
      );
    });

    test('the explanation describes the actual trigger', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );
      final claim = r.indicators.firstWhere((i) => i.id == 'money_claim');

      expect(claim.title, contains('specific amount of money'));
      expect(claim.explanation, contains('claim a specific cash amount'));
      expect(
        claim.explanation,
        contains('common lure'),
        reason: 'it must say what makes the shape suspicious, not restate '
            'the severity',
      );
      // The app cannot know whether the user earned anything, and this
      // message never asks for a payment, so neither may be asserted.
      expect(
        claim.explanation,
        isNot(contains('did not earn')),
        reason: 'unsupported assumption about the reader',
      );
      expect(
        claim.explanation,
        isNot(contains('it asks for next')),
        reason: 'must not claim the message asks for something it does not',
      );
      expect(
        claim.explanation,
        isNot(contains('high risk')),
        reason: 'the explanation must not assert a severity it does not have',
      );
    });

    test('ordinary reward wording stays clean', () {
      const benign = [
        'Congratulations on your new job!',
        'You earned a reward for completing your training.',
        'Claim your 10% discount at checkout.',
        'Claim your 500 points before they expire.',
        'We are proud of you, congratulations again!',
      ];
      for (final message in benign) {
        final f = analyzeMessage(message);
        expect(
          ids(f),
          isEmpty,
          reason: 'benign message wrongly flagged: $message',
        );
        expect(RiskScorer.level(f), RiskLevel.low, reason: message);
      }
    });

    test('it does not overlap the existing "claim your prize" rule', () {
      // Pre-existing and deliberately unchanged: "claim your <prize noun>"
      // without any amount is already a critical prize signal. The new rule
      // must not add a second indicator on top of it.
      for (final message in [
        'Claim your prize now.',
        'Claim your reward for downloading the app.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), contains('prize_reward'), reason: message);
        expect(ids(f), isNot(contains('money_claim')), reason: message);
        expect(RiskScorer.level(f), RiskLevel.high, reason: message);
      }
    });

    test('other currencies are caught too', () {
      for (final message in [
        'Claim your 250 EUR prize.',
        'Claim this 1,000 dollars reward.',
        'Claim your 5000 IQD bonus now.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), contains('money_claim'), reason: message);
        expect(RiskScorer.level(f), RiskLevel.low, reason: message);
      }
    });

    test('it does not replace the stronger prize signal', () {
      final f = analyzeMessage(
          'Congratulations! You have won the lottery. Claim your prize now.');
      expect(ids(f), contains('prize_reward'));
      expect(RiskScorer.level(f), RiskLevel.high);
      expect(ids(f), isNot(contains('money_claim')));
    });
  });

  group('bug pass: reported manual-test failures', () {
    // Each case below was reported as a failure by hand. The first four are
    // pinned here because the fixes that made them pass were made in the
    // uncommitted working tree, so nothing recorded their behaviour yet.

    test('an OTP warning is not reported as asking for the OTP', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your OTP: 482913. Do not share it with anyone.',
        kind: InputKind.message,
      );

      expect(r.riskLevel, RiskLevel.low);
      expect(ids(r.indicators), isNot(contains('sensitive_request')));
      // It must still be honest that the message mentions a code.
      expect(ids(r.indicators), contains('sensitive_words'));
      expect(r.recommendation, isNot(contains('open the link')));
    });

    test('an ordinary congratulation raises nothing', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Congratulations on your new job!',
        kind: InputKind.message,
      );

      expect(r.riskLevel, RiskLevel.low);
      expect(r.indicators, isEmpty);
      expect(r.recommendation, contains('No strong warning signs'));
    });

    test('.com in a query value is not an executable download', () async {
      final r = await AnalysisEngine().analyze(
        input: 'https://example.com/page?ref=site.com',
        kind: InputKind.link,
      );

      expect(r.riskLevel, RiskLevel.low);
      expect(ids(r.indicators), isNot(contains('dangerous_download')));
      expect(r.indicators, isEmpty);
      expect(r.recommendation, isNot(contains('download')));
    });

    test('a stated reward amount shows a proportionate indicator', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );

      // LOW is correct, but "no warning signs matched" would be wrong - the
      // message does tell the user to claim money.
      expect(r.riskLevel, RiskLevel.low);
      expect(ids(r.indicators), contains('money_claim'));
      expect(r.indicators, hasLength(1));
      final claim = r.indicators.single;
      expect(claim.severity, IndicatorSeverity.warning);
      expect(claim.title, contains('specific amount of money'));
    });
  });

  group('bug pass: recommendations fit the input', () {
    // The recommendation must only give advice about what is actually there.

    const scamWithoutLink =
        'Your account will be suspended today. Send us your password and OTP '
        'to restore access immediately.';

    test('a HIGH message with no link is not told to leave the link alone',
        () async {
      final r = await AnalysisEngine()
          .analyze(input: scamWithoutLink, kind: InputKind.message);

      expect(r.riskLevel, RiskLevel.high);
      expect(ids(r.indicators), isNot(contains('link_in_message')));
      expect(
        r.recommendation.contains('open the link'),
        isFalse,
        reason: 'there is no link in this message to open',
      );
      expect(
        r.recommendation.contains('any page this link opens'),
        isFalse,
        reason: 'there is no link in this message to open',
      );
      // The advice that does apply must still be there.
      expect(r.recommendation, contains('Never send a password, PIN'));
    });

    test('the same message with a link keeps the link advice', () async {
      final r = await AnalysisEngine().analyze(
        input: '$scamWithoutLink http://paypalsecure-login.com/verify',
        kind: InputKind.message,
      );

      expect(r.riskLevel, RiskLevel.high);
      expect(ids(r.indicators), contains('link_in_message'));
      expect(r.recommendation, contains('open the link'));
      expect(r.recommendation, contains('any page this link opens'));
    });

    test('an executable link is told not to download or run the file',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'https://example.com/download/report.exe',
        kind: InputKind.link,
      );

      expect(r.riskLevel, RiskLevel.high);
      expect(ids(r.indicators), contains('dangerous_download'));
      expect(
        r.recommendation,
        contains('Do not download or run the file'),
        reason: 'the critical signal is a program, so the advice must name it',
      );
      // The generic "page" advice must not replace the specific one.
      expect(r.recommendation, isNot(contains('any page this link opens')));
    });

    test('a normal link keeps the page advice and gets no download warning',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'https://paypalsecure-login.com/verify',
        kind: InputKind.link,
      );

      expect(ids(r.indicators), isNot(contains('dangerous_download')));
      expect(r.recommendation, isNot(contains('download or run')));
      expect(r.recommendation, contains('any page this link opens'));
    });

    test('a message asking for secrets is not warned about an unrequested fee',
        () async {
      final r = await AnalysisEngine()
          .analyze(input: scamWithoutLink, kind: InputKind.message);

      // This message demands a password and an OTP, never a payment.
      expect(
        r.recommendation.contains('Do not transfer money'),
        isFalse,
        reason: 'no money was requested, so the advice must not mention it',
      );
      expect(r.recommendation, contains('Never send a password, PIN'));
    });

    test('checkpoint wording is reported as an indicator, not as proof',
        () async {
      final f = analyzeLink('https://paypalsecure-login.com/verify');
      final checkpoint =
          f.firstWhere((i) => i.id == 'checkpoint_path');

      expect(
        checkpoint.explanation,
        isNot(contains('is where scammers ask')),
        reason: 'must not assert what the destination page does',
      );
      expect(checkpoint.explanation, contains('never opened'));
      expect(
        checkpoint.explanation,
        contains('not evidence'),
        reason: 'must say plainly that this is not proof',
      );
      // It must still name the wording it actually found.
      expect(checkpoint.explanation, contains('verify'));
      expect(checkpoint.params['words'], 'verify');
    });

    test('the preserved cases still detect exactly what they should',
        () async {
      final message = await AnalysisEngine().analyze(
        input: scamWithoutLink,
        kind: InputKind.message,
      );
      expect(message.riskLevel, RiskLevel.high);
      expect(ids(message.indicators),
          containsAll(['urgency', 'threat', 'sensitive_request']));

      final lookalike = analyzeLink('https://paypalsecure-login.com/verify');
      expect(ids(lookalike), contains('brand_impersonation'));
      expect(RiskScorer.level(lookalike), RiskLevel.high);

      final exe = analyzeLink('https://example.com/download/report.exe');
      expect(ids(exe), contains('dangerous_download'));
      expect(RiskScorer.level(exe), RiskLevel.high);
    });
  });

  group('bug pass: the Arabic advice matches', () {
    test('an Arabic HIGH message with no link mentions no link', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your account will be suspended today. Send us your password '
            'and OTP to restore access immediately.',
        kind: InputKind.message,
        strings: const ArabicStrings(),
      );

      expect(r.riskLevel, RiskLevel.high);
      expect(
        r.recommendation.contains('لا تفتح الرابط'),
        isFalse,
        reason: 'the message contains no link, so the advice must not name one',
      );
      expect(r.recommendation, contains('لا ترد'));
    });

    test('an Arabic executable link is told not to download the file',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'https://example.com/download/report.exe',
        kind: InputKind.link,
        strings: const ArabicStrings(),
      );

      expect(r.riskLevel, RiskLevel.high);
      expect(
        r.recommendation,
        contains('لا تُنزّل الملف'),
        reason: 'the Arabic advice must name the download too',
      );
    });
  });

  group('audit: crypto demands written with tickers', () {
    // The rule used to match only the full words "bitcoin", "crypto" and
    // "usdt", so the way these demands are actually written - a transfer verb
    // and an amount - produced no signal at all.

    test('a transfer verb with an amount and a ticker is caught', () {
      const demands = [
        'Send 0.5 BTC to this wallet to release your parcel.',
        'Pay 250 USDT now to unlock your account.',
        'Transfer 0.05 ETH within 1 hour to confirm your delivery.',
        'Deposit 1,000 USDT to claim your prize.',
      ];
      for (final message in demands) {
        final f = analyzeMessage(message);
        expect(ids(f), contains('payment_demand'), reason: message);
        expect(RiskScorer.level(f), RiskLevel.high, reason: message);
      }
    });

    test('a ticker beside an amount alone is not a demand', () {
      // Merely holding or mentioning a coin is not a request for money, so the
      // verb is required. This is what stops "I hold 3 ETH" becoming HIGH.
      const harmless = [
        'I hold 3 ETH in my portfolio.',
        'The ETH conference was great.',
        'We send daily reports at 5pm.',
        'Please pay the invoice by bank transfer.',
      ];
      for (final message in harmless) {
        final f = analyzeMessage(message);
        expect(ids(f), isNot(contains('payment_demand')), reason: message);
        expect(RiskScorer.level(f), RiskLevel.low, reason: message);
      }
    });

    test('the existing payment wording is unchanged', () {
      for (final message in [
        'Buy gift cards and send me the codes now.',
        'Send the money by bitcoin to release your parcel.',
      ]) {
        final f = analyzeMessage(message);
        expect(ids(f), contains('payment_demand'), reason: message);
        expect(RiskScorer.level(f), RiskLevel.high, reason: message);
      }
    });
  });

  group('audit: explanations state only what the rules actually know', () {
    test('a code warning does not accuse the message of asking for it',
        () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your OTP: 482913. Do not share it with anyone.',
        kind: InputKind.message,
      );
      final words = r.indicators.firstWhere((i) => i.id == 'sensitive_words');

      expect(words.title, contains('password, PIN or verification code'));
      expect(
        words.explanation,
        contains('not a request'),
        reason: 'the message warns against sharing, so it must not read as '
            'an accusation',
      );
      expect(words.explanation, contains('may simply be warning'));
      expect(
        words.explanation,
        isNot(contains('asks you to send')),
        reason: 'the rule cannot know that, so it must not say it',
      );
    });

    test('a claimed amount is not described as unearned', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Claim your 500 USD reward.',
        kind: InputKind.message,
      );
      final claim = r.indicators.firstWhere((i) => i.id == 'money_claim');

      expect(
        claim.explanation,
        isNot(contains('did not earn')),
        reason: 'the app cannot know whether the reader earned it',
      );
      expect(claim.explanation, contains('common lure'));
      expect(claim.explanation, contains('check who sent it'));
      expect(r.riskLevel, RiskLevel.low);
    });

    test('the Arabic wording carries the same caveats', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Your OTP: 482913. Do not share it with anyone.',
        kind: InputKind.message,
        strings: const ArabicStrings(),
      );
      final words = r.indicators.firstWhere((i) => i.id == 'sensitive_words');

      expect(_arabicScript.hasMatch(words.title), isTrue);
      expect(_arabicScript.hasMatch(words.explanation), isTrue);
      expect(
        words.explanation,
        contains('هذه ليست طلباً'),
        reason: 'the Arabic must carry the same "not a request" caveat',
      );
      expect(r.riskLevel, RiskLevel.low);
    });

    test('a crypto demand with a ticker is still HIGH in Arabic', () async {
      final r = await AnalysisEngine().analyze(
        input: 'Send 0.5 BTC to this wallet to release your parcel.',
        kind: InputKind.message,
        strings: const ArabicStrings(),
      );
      expect(r.riskLevel, RiskLevel.high);
      expect(r.indicators.map((i) => i.id), contains('payment_demand'));
    });
  });
}
