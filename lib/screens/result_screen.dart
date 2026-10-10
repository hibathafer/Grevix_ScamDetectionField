import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../theme/app_theme.dart';
import '../widgets/indicator_tile.dart';
import '../widgets/risk_header.dart';
import '../widgets/section_card.dart';
import 'home_screen.dart';

/// Shows the full, explainable result of one analysis.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final reasons = result.reasons;
    final notes = result.contextNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis result'),
        actions: [
          IconButton(
            tooltip: 'Analyse another',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RiskHeader(result: result),
              const SizedBox(height: 14),
              if (result.aiSummary != null) _AiCard(result: result),
              SectionCard(
                title: 'Why this result',
                icon: Icons.rule_rounded,
                child: reasons.isEmpty
                    ? const _NoSignals()
                    : Column(
                        children: [
                          for (final indicator in reasons)
                            IndicatorTile(indicator: indicator),
                        ],
                      ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Context notes',
                  icon: Icons.notes_rounded,
                  child: Column(
                    children: [
                      for (final indicator in notes)
                        IndicatorTile(indicator: indicator),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SectionCard(
                title: 'What you should do',
                icon: Icons.directions_outlined,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.riskColor(result.riskLevel)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.recommendation,
                    key: const ValueKey('recommendation'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFF26364D),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'About this analysis',
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modeText(result.mode),
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Color(0xFF46566B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Limitation: this result highlights common warning '
                      'signs. It cannot prove that something is safe, and it '
                      'does not open or download any link. Always verify '
                      'unexpected requests through an official channel.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF7A8798),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Analysed ${result.analyzedAt.hour.toString().padLeft(2, '0')}:'
                      '${result.analyzedAt.minute.toString().padLeft(2, '0')}'
                      ' - ${result.indicators.length} rule checks matched '
                      'their patterns.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF95A1B2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('again-button'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Text('Analyse another'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      key: const ValueKey('copy-button'),
                      onPressed: () => _copyReport(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Text('Copy report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeText(AnalysisMode mode) => switch (mode) {
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

  String buildReport() {
    final buffer = StringBuffer()
      ..writeln('Scam Detection Field - ${AppTheme.riskLabel(result.riskLevel)}')
      ..writeln('Input (${result.kind.name}):')
      ..writeln(result.inputPreview.length > 400
          ? '${result.inputPreview.substring(0, 400)}...'
          : result.inputPreview)
      ..writeln()
      ..writeln('Why:');

    if (result.reasons.isEmpty) {
      buffer.writeln('- No warning signs matched.');
    } else {
      for (final i in result.reasons) {
        buffer.writeln('- ${i.title}: ${i.explanation}');
      }
    }
    if (result.aiSummary != null) {
      buffer
        ..writeln()
        ..writeln('AI explanation:')
        ..writeln(result.aiSummary);
    }
    buffer
      ..writeln()
      ..writeln('What to do:')
      ..writeln(result.recommendation)
      ..writeln()
      ..writeln(
        'Note: highlights common warning signs only - not a guarantee that '
        'something is or is not a scam.',
      );
    return buffer.toString();
  }

  Future<void> _copyReport(BuildContext context) async {
    await copyToClipboard(buildReport());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Report copied to clipboard')),
      );
  }
}

class _NoSignals extends StatelessWidget {
  const _NoSignals();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.low.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.low.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.low, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'None of the built-in warning patterns matched this input. That '
              'is a good sign, but it is not a guarantee - stay careful with '
              'unexpected requests.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Color(0xFF46566B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'AI explanation',
          icon: Icons.auto_awesome_outlined,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE9FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'external model',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B3FBF),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.aiSummary!,
                key: const ValueKey('ai-summary'),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF26364D),
                ),
              ),
              if (result.aiObservations.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final observation in result.aiObservations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.fiber_manual_record_rounded,
                              size: 7, color: Color(0xFF5B3FBF)),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            observation,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: Color(0xFF46566B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
