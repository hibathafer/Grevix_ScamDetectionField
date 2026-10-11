import '../models/analysis_result.dart';

/// Every user-visible string in the app, plus the few sentences the analysis
/// engine writes into a result.
///
/// Two implementations exist: [EnglishStrings] (default) and
/// `ArabicStrings`. Adding a language means adding one class; no widget
/// changes are required.
///
/// The *detection rules* always run and produce English text. These classes
/// only decide what the user reads, and only the `Indicator.id`,
/// `Indicator.severity` and `RiskLevel` decide the outcome.
abstract class AppStrings {
  const AppStrings();

  /// BCP-47 language code, e.g. `en` or `ar`.
  String get languageCode;

  /// True when text must be laid out right-to-left.
  bool get isRtl;

  /// Endonym shown in the language switcher (always in its own language).
  String get languageName;

  // -------------------------------------------------------------------------
  // App chrome
  // -------------------------------------------------------------------------

  String get appTitle;

  String get howItWorksTooltip;

  String get languageTooltip;

  // -------------------------------------------------------------------------
  // Home screen
  // -------------------------------------------------------------------------

  String get heroTitle;

  String get heroBody;

  String get tryLinkExample;

  String get tryMessageExample;

  String get tabLink;

  String get tabMessage;

  String get linkFieldLabel;

  String get messageFieldLabel;

  String get linkFieldHint;

  String get messageFieldHint;

  String get errorEmptyInput;

  /// Shown when the Link tab is given something that is not a website
  /// address - free text, a malformed address, a missing host, or a scheme
  /// other than http/https. Nothing is scored in that case, so no risk level
  /// is produced.
  ///
  /// Replaces the old `errorLinkContainsSpaces`: one message for every
  /// invalid link is clearer than three, and the Message tab is offered
  /// separately by the error box.
  String get errorInvalidUrl;

  /// Shown when analysis fails for a reason that is neither an empty input
  /// nor a malformed link - so the user is never told "type something first"
  /// for a problem they did not cause.
  String get errorUnexpected;

  String get switchToMessage;

  String get analyseButton;

  String get analysingButton;

  String get howItWorksTitle;

  String get stepPaste;

  String get stepPasteBody;

  String get stepCheck;

  String get stepCheckBody;

  String get stepDecide;

  String get stepDecideBody;

  String get homeDisclaimer;

  String get infoSheetTitle;

  String get infoSheetBody;

  /// Shown only in languages whose *detection* coverage is incomplete.
  ///
  /// `null` hides the note. English returns `null` because every rule is
  /// written for English text.
  String? get detectionCoverageNote;

  // -------------------------------------------------------------------------
  // Language switcher
  // -------------------------------------------------------------------------

  String get languageSheetTitle;

  // -------------------------------------------------------------------------
  // Result screen
  // -------------------------------------------------------------------------

  String get resultTitle;

  String get analyseAnother;

  String get aiExplanationTitle;

  String get aiExternalBadge;

  String get whyThisResult;

  String get contextNotes;

  String get whatToDo;

  String get aboutThisAnalysis;

  String get noSignalsTitle;

  String get copyReport;

  String get reportCopied;

  String get limitationNote;

  /// Rendered **only** for a link result, in the "About this analysis" card.
  ///
  /// A tester read a reassuring LOW RISK on his own website as "free of
  /// vulnerabilities". This says in one sentence what the app actually did -
  /// read the address, never open the site - so the result cannot be read as
  /// a security scan.
  String get linkScanScopeNote;

  /// `analysedAt` is already formatted as `HH:MM` in 24-hour local time.
  String analysedAt(String time, int checks);

  String modeText(AnalysisMode mode);

  /// One line naming *why* the AI wording step produced nothing.
  ///
  /// Rendered only when `result.aiFailure != null`, i.e. only alongside
  /// [AnalysisMode.rulesWithAiFallback]. It must describe the fixed
  /// [AiFailure] category and never echo a key, a URL or a response body.
  String aiFailureNote(AiFailure failure);

  // -------------------------------------------------------------------------
  // Risk header
  // -------------------------------------------------------------------------

  String riskLabel(RiskLevel level);

  String analysisKind(InputKind kind);

  String signalCount(int count);

  String strongSignalCount(int count);

  String warningCount(int count);

  String contextNoteCount(int count);

  // -------------------------------------------------------------------------
  // Indicator source tag
  // -------------------------------------------------------------------------

  String sourceLabel(IndicatorSource source);

  // -------------------------------------------------------------------------
  // Engine output
  // -------------------------------------------------------------------------

  /// One-line meaning of a risk level, given how many non-info signals fired.
  String headline(RiskLevel level, int signalCount);

  /// Practical next step, assembled from the level and which signals fired.
  ///
  /// [hasLink] must be true only when a link is really present and
  /// [hasDownload] only when a rule found a file the link would download.
  /// The wording must never mention a link or a download the input does not
  /// contain, so both default to `false`.
  String recommendation(
    RiskLevel level, {
    required bool wantsSecrets,
    required bool wantsMoney,
    required bool hasLink,
    bool hasDownload = false,
  });

  /// Translated title for [indicator], or `null` to keep the rule's English.
  String? indicatorTitle(Indicator indicator);

  /// Translated explanation for [indicator], or `null` to keep the rule's
  /// English.
  String? indicatorExplanation(Indicator indicator);

  /// Applies [indicatorTitle] / [indicatorExplanation]; id and severity are
  /// never modified.
  Indicator localizeIndicator(Indicator indicator) {
    final title = indicatorTitle(indicator);
    final explanation = indicatorExplanation(indicator);
    if (title == null && explanation == null) return indicator;
    return indicator.copyWith(
      title: title,
      explanation: explanation,
    );
  }

  // -------------------------------------------------------------------------
  // Plain-text report
  // -------------------------------------------------------------------------

  String reportHeader(RiskLevel level);

  String reportInputLabel(InputKind kind);

  String get reportWhyHeading;

  String get reportNoSignals;

  String reportReasonLine(String title, String explanation);

  String get reportAiHeading;

  String get reportWhatToDoHeading;

  String get reportNoteHeading;

  String get reportNoteBody;
}

/// Default language. Every string here is byte-for-byte the original MVP
/// text, which is why the existing test suite still passes unchanged.
class EnglishStrings extends AppStrings {
  const EnglishStrings();

  @override
  String get languageCode => 'en';

  @override
  bool get isRtl => false;

  @override
  String get languageName => 'English';

  @override
  String get appTitle => 'Scam Detection Field';

  @override
  String get howItWorksTooltip => 'How it works';

  @override
  String get languageTooltip => 'Language';

  @override
  String get heroTitle => 'Why should I be suspicious of this?';

  @override
  String get heroBody =>
      'Paste a link or a message you received. You get a clear risk level, '
      'the exact reasons behind it, and what to do next - in plain language.';

  @override
  String get tryLinkExample => 'Try a suspicious link';

  @override
  String get tryMessageExample => 'Try a suspicious message';

  @override
  String get tabLink => 'Link';

  @override
  String get tabMessage => 'Message';

  @override
  String get linkFieldLabel => 'Suspicious link';

  @override
  String get messageFieldLabel => 'Suspicious message';

  @override
  String get linkFieldHint => 'Paste the link here, for example\nhttp://...';

  @override
  String get messageFieldHint => 'Paste the full message here...';

  @override
  String get errorEmptyInput => 'Paste or type something to analyse first.';

  @override
  String get errorInvalidUrl =>
      'Invalid URL — Please enter a valid website link to analyze.';

  @override
  String get errorUnexpected =>
      'Something went wrong while analysing. Nothing was sent anywhere - '
      'please try again.';

  @override
  String get switchToMessage => 'Switch to Message';

  @override
  String get analyseButton => 'Analyse it';

  @override
  String get analysingButton => 'Analysing...';

  @override
  String get howItWorksTitle => 'How it works';

  @override
  String get stepPaste => 'Paste';

  @override
  String get stepPasteBody => 'A link or the full message you received.';

  @override
  String get stepCheck => 'Check';

  @override
  String get stepCheckBody =>
      'Transparent rules look for known scam patterns.';

  @override
  String get stepDecide => 'Decide';

  @override
  String get stepDecideBody => 'Risk level, reasons and a safe next step.';

  @override
  String get homeDisclaimer =>
      'This tool highlights common warning signs. It cannot guarantee that '
      'something is or is not a scam - when in doubt, verify through an '
      'official channel.';

  @override
  String get infoSheetTitle => 'How this app works';

  @override
  String get infoSheetBody =>
      '1. You paste a link or a message you received.\n\n'
      '2. Built-in rules check the address and the wording against well-known '
      'scam patterns: urgency, threats, requests for passwords or codes, fake '
      'prizes, impersonation and suspicious domain structures.\n\n'
      '3. You get a risk level, the exact reasons behind it, and a practical '
      'next step.\n\n'
      'Every reason shown in the result comes from a rule you can read, not '
      'from a hidden score. If an AI explanation is configured, it only adds '
      'wording - it never changes the risk level.\n\n'
      'The app does not open, visit or download any link.';

  /// English covers every rule, so no warning is needed.
  @override
  String? get detectionCoverageNote => null;

  @override
  String get languageSheetTitle => 'Choose language';

  @override
  String get resultTitle => 'Analysis result';

  @override
  String get analyseAnother => 'Analyse another';

  @override
  String get aiExplanationTitle => 'AI explanation';

  @override
  String get aiExternalBadge => 'external model';

  @override
  String get whyThisResult => 'Why this result';

  @override
  String get contextNotes => 'Context notes';

  @override
  String get whatToDo => 'What you should do';

  @override
  String get aboutThisAnalysis => 'About this analysis';

  @override
  String get noSignalsTitle =>
      'None of the built-in warning patterns matched this input. That is a '
      'good sign, but it is not a guarantee - stay careful with unexpected '
      'requests.';

  @override
  String get copyReport => 'Copy report';

  @override
  String get reportCopied => 'Report copied to clipboard';

  @override
  String get limitationNote =>
      'Limitation: this result highlights common warning signs. It cannot '
      'prove that something is safe, and it does not open or download any '
      'link. Always verify unexpected requests through an official channel.';

  @override
  String get linkScanScopeNote =>
      'This is not a security scan. The app reads the web address only and '
      'never opens or tests the website, so LOW RISK means no common warning '
      'signs were found in the link - not that the site is safe or free of '
      'vulnerabilities.';

  @override
  String analysedAt(String time, int checks) =>
      'Analysed $time - $checks rule checks matched their patterns.';

  @override
  String modeText(AnalysisMode mode) => switch (mode) {
        AnalysisMode.rulesOnly =>
          'The risk level and every reason above come from the app\'s '
              'built-in rules. No AI service is configured in this build.',
        AnalysisMode.rulesAndAi =>
          'The risk level and the reasons above come from the app\'s built-in '
              'rules. An external AI model was asked to add the plain-language '
              'explanation. The AI does not change the risk level.',
        AnalysisMode.rulesWithAiFallback =>
          'The risk level and the reasons above come from the app\'s built-in '
              'rules. An AI explanation was requested but could not be '
              'completed, so only the rules are shown.',
      };

  @override
  String aiFailureNote(AiFailure failure) => switch (failure) {
        AiFailure.timeout =>
          'Reason: the AI service did not answer within the time limit.',
        AiFailure.network =>
          'Reason: the AI service could not be reached from this device.',
        AiFailure.rateLimited =>
          'Reason: the AI service is handling too many requests right now.',
        AiFailure.apiError =>
          'Reason: the AI service returned an error.',
        AiFailure.badResponse =>
          'Reason: the AI service replied with something the app could not '
              'read.',
        AiFailure.unknown =>
          'Reason: the AI step stopped for an unexpected reason.',
      };

  @override
  String riskLabel(RiskLevel level) => switch (level) {
        RiskLevel.low => 'LOW RISK',
        RiskLevel.medium => 'MEDIUM RISK',
        RiskLevel.high => 'HIGH RISK',
      };

  @override
  String analysisKind(InputKind kind) => switch (kind) {
        InputKind.link => 'Link analysis',
        InputKind.message => 'Message analysis',
      };

  @override
  String signalCount(int count) => '$count signal${count == 1 ? '' : 's'}';

  @override
  String strongSignalCount(int count) =>
      '$count strong signal${count == 1 ? '' : 's'}';

  @override
  String warningCount(int count) => '$count warning${count == 1 ? '' : 's'}';

  @override
  String contextNoteCount(int count) =>
      '$count context note${count == 1 ? '' : 's'}';

  @override
  String sourceLabel(IndicatorSource source) => switch (source) {
        IndicatorSource.link => 'Link',
        IndicatorSource.message => 'Message',
      };

  @override
  String headline(RiskLevel level, int signalCount) => switch (level) {
        RiskLevel.high =>
          'Strong warning signs matched. Do not act before you verify.',
        RiskLevel.medium =>
          'Some warning signs matched. Pause and check before you act.',
        RiskLevel.low => signalCount == 0
            ? 'No obvious warning signs were found in this input.'
            : 'Only minor signals found - nothing clearly suspicious.',
      };

  @override
  String recommendation(
    RiskLevel level, {
    required bool wantsSecrets,
    required bool wantsMoney,
    required bool hasLink,
    bool hasDownload = false,
  }) {
    final buffer = StringBuffer();
    switch (level) {
      case RiskLevel.high:
        // The link wording appears only when a link is actually present; a
        // message with no link must not be told to leave a link alone.
        buffer.write(
          hasLink
              ? 'Do not open the link, reply, or send anything. Verify the '
                  'sender through a separate, official channel - their real '
                  'website or a phone number you already had - before you do '
                  'anything.'
              : 'Do not reply or send anything. Verify the sender through a '
                  'separate, official channel - their real website or a phone '
                  'number you already had - before you do anything.',
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
    if (hasDownload) {
      // Name the real threat instead of a generic "page": the critical signal
      // here is that a program would be installed.
      buffer.write(
        ' Do not download or run the file this link points to.',
      );
    } else if (hasLink && level != RiskLevel.low) {
      buffer.write(
        ' Do not type your details into any page this link opens.',
      );
    }
    return buffer.toString();
  }

  // English is the source language of the rules, so nothing is overridden.
  @override
  String? indicatorTitle(Indicator indicator) => null;

  @override
  String? indicatorExplanation(Indicator indicator) => null;

  @override
  String reportHeader(RiskLevel level) =>
      'Scam Detection Field - ${riskLabel(level)}';

  @override
  String reportInputLabel(InputKind kind) => 'Input (${kind.name}):';

  @override
  String get reportWhyHeading => 'Why:';

  @override
  String get reportNoSignals => '- No warning signs matched.';

  @override
  String reportReasonLine(String title, String explanation) =>
      '- $title: $explanation';

  @override
  String get reportAiHeading => 'AI explanation:';

  @override
  String get reportWhatToDoHeading => 'What to do:';

  @override
  String get reportNoteHeading => 'Note:';

  @override
  String get reportNoteBody =>
      'highlights common warning signs only - not a guarantee that something '
      'is or is not a scam.';
}
