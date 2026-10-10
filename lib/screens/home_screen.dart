import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analysis/analysis_engine.dart';
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
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _setError('Paste or type something to analyse first.');
      return;
    }
    if (_kind == InputKind.link && RegExp(r'\s').hasMatch(text)) {
      _setError(
        'A website address should not contain spaces. Switch to the Message '
        'tab to analyse a full message.',
      );
      return;
    }

    _setError(null);
    setState(() => _loading = true);

    final AnalysisResult confirmed;
    try {
      confirmed = await _engine.analyze(input: text, kind: _kind);
    } on EmptyInputException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Something went wrong while analysing. Please try again.';
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
    final isLink = _kind == InputKind.link;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scam Detection Field'),
        actions: [
          IconButton(
            tooltip: 'How it works',
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
                segments: const [
                  ButtonSegment(
                    value: InputKind.link,
                    label: Text('Link'),
                    icon: Icon(Icons.link_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: InputKind.message,
                    label: Text('Message'),
                    icon: Icon(Icons.sms_outlined, size: 18),
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
                  labelText: isLink ? 'Suspicious link' : 'Suspicious message',
                  hintText: isLink
                      ? 'Paste the link here, for example\nhttp://...'
                      : 'Paste the full message here...',
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
                label: Text(_loading ? 'Analysing...' : 'Analyse it'),
              ),
              const SizedBox(height: 22),
              const _HowItWorksCard(),
              const SizedBox(height: 16),
              const Text(
                'This tool highlights common warning signs. It cannot '
                'guarantee that something is or is not a scam - when in '
                'doubt, verify through an official channel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF7A8798)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this app works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              '1. You paste a link or a message you received.\n\n'
              '2. Built-in rules check the address and the wording against '
              'well-known scam patterns: urgency, threats, requests for '
              'passwords or codes, fake prizes, impersonation and suspicious '
              'domain structures.\n\n'
              '3. You get a risk level, the exact reasons behind it, and a '
              'practical next step.\n\n'
              'Every reason shown in the result comes from a rule you can '
              'read, not from a hidden score. If an AI explanation is '
              'configured, it only adds wording - it never changes the risk '
              'level.\n\n'
              'The app does not open, visit or download any link.',
              style: TextStyle(fontSize: 14.5, height: 1.55, color: Color(0xFF46566B)),
            ),
          ],
        ),
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
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppTheme.brand, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Why should I be suspicious of this?',
                  style: TextStyle(
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
          const Text(
            'Paste a link or a message you received. You get a clear risk '
            'level, the exact reasons behind it, and what to do next - in '
            'plain language.',
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF46566B)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.link_rounded, size: 17),
                label: const Text('Try a suspicious link'),
                onPressed: exampleBusy ? null : () => onExample(InputKind.link),
              ),
              ActionChip(
                avatar: const Icon(Icons.sms_outlined, size: 17),
                label: const Text('Try a suspicious message'),
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
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSwitchToMessage,
                child: const Text('Switch to Message'),
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
    const steps = [
      ('1', 'Paste', 'A link or the full message you received.'),
      ('2', 'Check', 'Transparent rules look for known scam patterns.'),
      ('3', 'Decide', 'Risk level, reasons and a safe next step.'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How it works',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
