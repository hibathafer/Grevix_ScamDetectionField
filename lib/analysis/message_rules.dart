import '../models/analysis_result.dart';

// Deterministic, fully transparent message rules.
//
// Each rule matches a recognisable social-engineering pattern and returns an
// [Indicator] that explains the pattern in plain English.

Indicator _hit(
  String id,
  String title,
  String explanation,
  IndicatorSeverity severity,
) =>
    Indicator(
      id: id,
      title: title,
      explanation: explanation,
      severity: severity,
      source: IndicatorSource.message,
    );

/// Matches a message against every rule and returns the signals found.
List<Indicator> analyzeMessage(String text) {
  final findings = <Indicator>[];
  final message = text.trim();
  if (message.isEmpty) return findings;

  final lower = message.toLowerCase();

  bool any(List<RegExp> patterns) => patterns.any((p) => p.hasMatch(lower));

  // --- Urgency -----------------------------------------------------------
  if (any([
    RegExp(r'\burgent\b'),
    RegExp(r'\bimmediately\b'),
    RegExp(r'\bact now\b'),
    RegExp(r'\bright away\b'),
    RegExp(r'\basap\b'),
    RegExp(r'\bwithin \d+ (minute|hour|day|week)s?\b'),
    RegExp(r'\bin \d+ (minute|hour|day)s?\b'),
    RegExp(r'\bexpires? (today|now|soon|in )'),
    RegExp(r'\blast chance\b'),
    RegExp(r"\bdo(n't| not) (delay|wait)\b"),
    RegExp(r'\blimited time\b'),
    RegExp(r"\bbefore it (is|'s) too late\b"),
    RegExp(r'\bfinal notice\b'),
    RegExp(r'\btime[- ]sensitive\b'),
    RegExp(r'\bonly today\b'),
    RegExp(r'\bhurry\b'),
  ])) {
    findings.add(_hit(
      'urgency',
      'Creates urgency and time pressure',
      'The message pushes you to act immediately. Pressure is used to stop '
          'you pausing to check whether the request is genuine.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Threats -----------------------------------------------------------
  if (any([
    RegExp(r'\baccount will be (closed|suspended|blocked|locked|terminated)\b'),
    RegExp(r'\b(suspend|lock|block|terminat)\w* (your|the) account\b'),
    RegExp(r'\baccount (has been|is) (suspended|locked|blocked|disabled)\b'),
    RegExp(r'\blegal action\b'),
    RegExp(r'\bcourt (order|warrant)\b'),
    RegExp(r'\barrest\b'),
    RegExp(r'\bimprison'),
    RegExp(r'\bdeport'),
    RegExp(r'\bwill be (reported|cancelled)\b'),
    RegExp(r'\bunauthori[sz]ed (activity|transaction|access)\b'),
    RegExp(r'\bsuspicious activity (detected|on your)\b'),
    RegExp(r'\byour (account|card|access) (is|has been) (compromised|at risk)\b'),
    RegExp(r'\b(penalty|fined|fine will be)\b'),
    RegExp(r'\bimmediate (penalty|action) will be taken\b'),
  ])) {
    findings.add(_hit(
      'threat',
      'Threatens loss, penalty or punishment',
      'The message warns that something bad will happen to you unless you '
          'comply. Fear is one of the most common social-engineering tools.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Explicit request for private information --------------------------
  final asksForSecrets = any([
    RegExp(
        r'\b(send|share|provide|enter|reply( with)?|submit|give|type|text me|whatsapp me|confirm)\b[^.!?]{0,60}\b(password|passcode|pin|otp|one[- ]time (password|code)|verification code|login credentials?|credentials|cvv|card number|bank details|iban|account number|seed phrase|recovery code)\b'),
    RegExp(
        r'\b(password|passcode|otp|verification code|one[- ]time code|cvv|card number|bank details)\b[^.!?]{0,40}\b(is|are|will be)?\s*(required|needed|necessary)\b'),
    RegExp(r'\b(code|otp|pin)\s*[:\-]?\s*\d{4,8}\b'),
    RegExp(r'\bverify (your )?(identity|account) by (sharing|sending|providing)\b'),
  ]);
  if (asksForSecrets) {
    findings.add(_hit(
      'sensitive_request',
      'Asks for private information',
      'The message asks you to send a password, PIN, verification code or '
          'bank detail. Legitimate organisations never ask for these in a '
          'message.',
      IndicatorSeverity.critical,
    ));
  } else if (any([
    RegExp(r'\bpasswords?\b'),
    RegExp(r'\botp\b'),
    RegExp(r'\bone[- ]time (password|code)\b'),
    RegExp(r'\bverification code\b'),
    RegExp(r'\bcvv\b'),
    RegExp(r'\bcard number\b'),
    RegExp(r'\bbank details\b'),
    RegExp(r'\biban\b'),
    RegExp(r'\bnational id\b'),
    RegExp(r'\bpassport number\b'),
    RegExp(r'\bseed phrase\b'),
  ])) {
    findings.add(_hit(
      'sensitive_words',
      'Mentions private account information',
      'The message talks about passwords, codes or card details. If it also '
          'links somewhere or asks you to confirm something, treat it as '
          'suspicious.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Money demands -----------------------------------------------------
  if (any([
    RegExp(r'\bgift cards?\b'),
    RegExp(r'\bsteam card\b'),
    RegExp(r'\bitunes card\b'),
    RegExp(r'\bbitcoin\b'),
    RegExp(r'\bcrypto(currency)?\b'),
    RegExp(r'\busdt\b'),
    RegExp(r'\bwestern union\b'),
    RegExp(r'\bmoneygram\b'),
    RegExp(r'\bwire transfer\b'),
    RegExp(r'\bsend (me )?(the )?money\b'),
    RegExp(r'\btransfer (the )?funds?\b'),
    RegExp(r'\bdeposit (the|a) (amount|fee|payment)\b'),
    RegExp(r'\bpay (the|a) (small )?(amount|sum)\b'),
  ])) {
    findings.add(_hit(
      'payment_demand',
      'Demands an unusual form of payment',
      'The message asks for money in a hard-to-trace form such as gift cards, '
          'crypto or a wire transfer. Genuine services do not work that way.',
      IndicatorSeverity.critical,
    ));
  }

  // --- Fees to release something ----------------------------------------
  if (any([
    RegExp(r'\bdelivery fee\b'),
    RegExp(r'\bcustoms fee\b'),
    RegExp(r'\brelease fee\b'),
    RegExp(r'\bactivation fee\b'),
    RegExp(r'\bprocessing fee\b'),
    RegExp(r'\bpay (the|a) fee\b'),
    RegExp(r'\bfee (must|has) be (paid|settled)\b'),
    RegExp(r'\bunlock fee\b'),
    RegExp(r'\badmin(istrative)? fee\b'),
  ])) {
    findings.add(_hit(
      'fee_request',
      'Asks you to pay a fee to release something',
      'The message asks for a payment before you can receive a package, '
          'refund, prize or account access. Upfront "release" fees are a '
          'classic scam pattern.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Prize / reward bait ------------------------------------------------
  if (any([
    RegExp(r'\byou (have )?won\b'),
    RegExp(r'\bcongratulations\b'),
    RegExp(r'\blottery\b'),
    RegExp(r'\bjackpot\b'),
    RegExp(r'\bclaim your (prize|reward|gift|voucher|coupon)\b'),
    RegExp(r'\byou are (a |the )?winner\b'),
    RegExp(r'\bselected (you|winner)\b'),
    RegExp(r'\bfree (iphone|smartphone|voucher|coupon|gift)\b'),
    RegExp(r'\bwinner of\b'),
  ])) {
    findings.add(_hit(
      'prize_reward',
      'Offers a prize or reward you never entered for',
      'The message promises money or a prize out of nowhere. Fake winnings '
          'are used to make people pay "fees" or hand over account details.',
      IndicatorSeverity.critical,
    ));
  }

  // --- Impersonation of an authority -------------------------------------
  if (any([
    RegExp(r'\bpolice\b'),
    RegExp(r'\bimmigration\b'),
    RegExp(r'\bcustoms (office|authority|department)\b'),
    RegExp(r'\btax (office|authority|agency|department)\b'),
    RegExp(r'\bir[s1]\b'),
    RegExp(r'\bhmrc\b'),
    RegExp(r'\bgovernment (office|agency|department|body)\b'),
    RegExp(r'\bministry of\b'),
    RegExp(r'\bfrom the (bank|head office|customer (care|service))\b'),
    RegExp(r'\b(dhl|fedex|aramex|usps|ups)\b'),
    RegExp(r'\baccount (department|team|section)\b'),
    RegExp(r'\bhr department\b'),
    RegExp(r'\bour (director|ceo|manager)\b'),
  ])) {
    findings.add(_hit(
      'impersonation',
      'Claims to be an official or trusted body',
      'The message presents itself as coming from an authority, bank or '
          'courier. Real organisations verify you through official channels, '
          'not by sending links in messages.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Secrecy ------------------------------------------------------------
  if (any([
    RegExp(r"\bdo(n't| not) tell (anyone|anybody|any person)\b"),
    RegExp(r'\bkeep this (confidential|secret|private)\b'),
    RegExp(r'\bbetween you and me\b'),
    RegExp(r"\bdo(n't| not) inform\b"),
    RegExp(r'\bwithout telling (anyone|anybody|anyone else)\b'),
    RegExp(r'\bthis (offer|deal) is (confidential|private)\b'),
  ])) {
    findings.add(_hit(
      'secrecy',
      'Asks you to keep it secret',
      'The message discourages you from telling anyone. Scammers rely on '
          'silence so nobody has a chance to warn you.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Too good to be true -------------------------------------------------
  if (any([
    RegExp(r'\b100% (free|guaranteed|profit|safe|risk[- ]free)\b'),
    RegExp(r'\bguaranteed (income|profit|return|earnings)\b'),
    RegExp(r'\bdouble your money\b'),
    RegExp(r'\bearn \d+'),
    RegExp(r'\bpassive income\b'),
    RegExp(r'\bwork from home\b'),
    RegExp(r'\bno experience needed\b'),
    RegExp(r'\brisk[- ]free (money|profit|income)\b'),
    RegExp(r'\beasy money\b'),
  ])) {
    findings.add(_hit(
      'too_good',
      'Sounds too good to be true',
      'The message promises unusually easy money or a risk-free result. Real '
          'returns always carry conditions and risk.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Pushes you to click / download / reply ----------------------------
  if (any([
    RegExp(r'\bclick (the )?(link|here|below|button|now)\b'),
    RegExp(r'\bopen (the )?(link|attachment|file)\b'),
    RegExp(r'\bscan the qr\b'),
    RegExp(r'\breply with your\b'),
    RegExp(r'\bsend (me )?your\b'),
    RegExp(r'\bdownload (the )?(attached|attachment|file|app|document)\b'),
    RegExp(r'\bupdate your (details|information|account|profile)\b'),
    RegExp(r'\bconfirm your (details|information|account|identity)\b'),
    RegExp(r'\bverify (now|immediately|your account)\b'),
  ])) {
    findings.add(_hit(
      'call_to_action',
      'Pushes you to click, open or reply',
      'The message drives you toward one quick action. Scams need you to act '
          'before you think, so one obvious next step is expected.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Generic greeting ---------------------------------------------------
  if (any([
    RegExp(r'^\s*dear (customer|user|member|sir|madam|subscriber|account holder|valued)'),
    RegExp(r'^\s*to whom it may concern'),
    RegExp(r'\bdear customer\b'),
  ])) {
    findings.add(_hit(
      'generic_greeting',
      'Generic greeting instead of your name',
      'The message starts by addressing everyone the same way. Organisations '
          'that really know you normally use your name or account reference.',
      IndicatorSeverity.info,
    ));
  }

  // --- Chain forwarding ---------------------------------------------------
  if (any([
    RegExp(r'\bforward this to\b'),
    RegExp(r'\bshare with (all|everyone|all of) your contacts\b'),
    RegExp(r'\bsend to \d+ (people|contacts|friends)\b'),
  ])) {
    findings.add(_hit(
      'chain_forward',
      'Asks you to forward it to other people',
      'The message wants to spread itself through your contacts, a pattern '
          'that has circulated in chain-letter scams for decades.',
      IndicatorSeverity.warning,
    ));
  }

  // --- Off-platform contact ----------------------------------------------
  if (any([
    RegExp(r'\b(contact|message|text|ping) me (on|via|through) (whatsapp|telegram|signal)\b'),
    RegExp(r'\bonly on (whatsapp|telegram|signal)\b'),
  ])) {
    findings.add(_hit(
      'off_platform',
      'Moves the conversation off the official channel',
      'The message wants you to continue somewhere that is harder to verify '
          'or report, which is a common step in investment and romance scams.',
      IndicatorSeverity.info,
    ));
  }

  return findings;
}
