import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analysis/analysis_engine.dart';
import '../app.dart';
import '../l10n/strings_scope.dart';
import '../models/analysis_result.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

/// The one and only entry screen: understand -> paste -> analyse.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.engine});

  /// Injectable for tests; a normal instance is created when omitted.
  final AnalysisEngine? engine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  late final AnalysisEngine _engine = widget.engine ?? AnalysisEngine();

  InputKind _kind = InputKind.link;
  bool _loading = false;
  String? _error;

  static const String _exampleLink =
      'http://paypal-secure-login.verify-account.xyz/session/update';
  static const String _exampleMessage =
      'URGENT! Your bank account will be suspended in 24 hours. Send your '
      'OTP and password to verify, then click the link to claim your 500 USD '
      'reward: http://claim-prize.verify-account.xyz/win';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setError(String? value) {
    if (mounted) setState(() => _error = value);
  }

  Future<void> _analyze() async {
    // Captured before the first await so the result is rendered in whichever
    // language was active when the user pressed the button.
    final l10n = StringsScope.read(context);

    final text = _controller.text.trim();
    if (text.isEmpty) {
      _setError(l10n.errorEmptyInput);
      return;
    }
    if (_kind == InputKind.link && RegExp(r'\s').hasMatch(text)) {
      _setError(l10n.errorLinkContainsSpaces);
      return;
    }

    _setError(null);
    setState(() => _loading = true);

    final AnalysisResult confirmed;
    try {
      confirmed = await _engine.analyze(
        input: text,
        kind: _kind,
        strings: l10n,
      );
    } on EmptyInputException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      return;
    } catch (e) {
      // An AI failure never reaches here - the engine catches it and returns
      // the rule-based result. So this is a genuine defect. Do not tell the
      // user to "type something first" for a problem they did not cause, and
      // do not print the exception message, which could carry anything.
      debugPrint('Analysis failed unexpectedly (${e.runtimeType})');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l10n.errorUnexpected;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _controller.clear();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(result: confirmed),
      ),
    );
  }

  void _useExample(InputKind kind) {
    setState(() {
      _kind = kind;
      _error = null;
      _controller.text = kind == InputKind.link ? _exampleLink : _exampleMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StringsScope.of(context);
    final isLink = _kind == InputKind.link;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.languageTooltip,
            key: const ValueKey('language-button'),
            icon: const Icon(Icons.translate_rounded),
            onPressed: _showLanguageSheet,
          ),
          IconButton(
            tooltip: l10n.howItWorksTooltip,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(
                onExample: _useExample,
                exampleBusy: _loading,
              ),
              const SizedBox(height: 18),
              SegmentedButton<InputKind>(
                segments: [
                  ButtonSegment(
                    value: InputKind.link,
                    label: Text(l10n.tabLink),
                    icon: const Icon(Icons.link_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: InputKind.message,
                    label: Text(l10n.tabMessage),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('input-field'),
                controller: _controller,
                minLines: 5,
                maxLines: 9,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => _setError(null),
                decoration: InputDecoration(
                  labelText:
                      isLink ? l10n.linkFieldLabel : l10n.messageFieldLabel,
                  hintText:
                      isLink ? l10n.linkFieldHint : l10n.messageFieldHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorBox(
                  message: _error!,
                  onSwitchToMessage: _kind == InputKind.link
                      ? () => setState(() {
                            _kind = InputKind.message;
                            _error = null;
                          })
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('analyze-button'),
                onPressed: _loading ? null : _analyze,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shield_rounded),
                label: Text(_loading ? l10n.analysingButton : l10n.analyseButton),
              ),
              const SizedBox(height: 22),
              const _HowItWorksCard(),
              const SizedBox(height: 16),
              Text(
                l10n.homeDisclaimer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: Color(0xFF7A8798)),
              ),
              // Honest note about which languages the rules actually cover.
              if (l10n.detectionCoverageNote != null) ...[
                const SizedBox(height: 12),
                _CoverageNote(text: l10n.detectionCoverageNote!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Switches language for the rest of the session. Nothing is persisted, so
  /// the next launch starts in English again.
  void _showLanguageSheet() {
    final current = StringsScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                child: Text(
                  current.languageSheetTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (final option in buildSupportedStrings())
                ListTile(
                  key: ValueKey('lang-${option.languageCode}'),
                  title: Text(option.languageName),
                  trailing: option.languageCode == current.languageCode
                      ? const Icon(Icons.check_rounded, color: AppTheme.brand)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (current.languageCode != option.languageCode) {
                      StringsScope.requestChange(context, option);
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showInfo() {
    final l10n = StringsScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.infoSheetTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.infoSheetBody,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.55, color: Color(0xFF46566B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverageNote extends StatelessWidget {
  const _CoverageNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D9A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.language_rounded,
              color: AppTheme.medium, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('coverage-note'),
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: Color(0xFF6B4E12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onExample, required this.exampleBusy});

  final void Function(InputKind kind) onExample;
  final bool exampleBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = StringsScope.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.brandSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD3E0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppTheme.brand, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.heroTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12203A),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.heroBody,
            style:
                const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF46566B)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.link_rounded, size: 17),
                label: Text(l10n.tryLinkExample),
                onPressed: exampleBusy ? null : () => onExample(InputKind.link),
              ),
              ActionChip(
                avatar: const Icon(Icons.sms_outlined, size: 17),
                label: Text(l10n.tryMessageExample),
                onPressed:
                    exampleBusy ? null : () => onExample(InputKind.message),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onSwitchToMessage});

  final String message;
  final VoidCallback? onSwitchToMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = StringsScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3C2C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.high, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  key: const ValueKey('error-text'),
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Color(0xFF8C2F2F)),
                ),
              ),
            ],
          ),
          if (onSwitchToMessage != null)
            Align(
              alignment: l10n.isRtl ? Alignment.centerLeft : Alignment.centerRight,
              child: TextButton(
                onPressed: onSwitchToMessage,
                child: Text(l10n.switchToMessage),
              ),
            ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final l10n = StringsScope.of(context);
    final steps = [
      ('1', l10n.stepPaste, l10n.stepPasteBody),
      ('2', l10n.stepCheck, l10n.stepCheckBody),
      ('3', l10n.stepDecide, l10n.stepDecideBody),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.howItWorksTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppTheme.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        step.$1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: Color(0xFF46566B),
                          ),
                          children: [
                            TextSpan(
                              text: '${step.$2} ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF12203A),
                              ),
                            ),
                            TextSpan(text: step.$3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Exposed for the demo / tests: clipboard helper for sharing a result.
Future<void> copyToClipboard(String text) => Clipboard.setData(
      ClipboardData(text: text),
    );
