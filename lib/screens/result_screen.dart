import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
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
    final l10n = StringsScope.of(context);
    final reasons = result.reasons;
    final notes = result.contextNotes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultTitle),
        actions: [
          IconButton(
            tooltip: l10n.analyseAnother,
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
                title: l10n.whyThisResult,
                icon: Icons.rule_rounded,
                child: reasons.isEmpty
                    ? _NoSignals(text: l10n.noSignalsTitle)
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
                  title: l10n.contextNotes,
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
                title: l10n.whatToDo,
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
                title: l10n.aboutThisAnalysis,
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.modeText(result.mode),
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Color(0xFF46566B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.limitationNote,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF7A8798),
                      ),
                    ),
                    // Repeat the language-coverage caveat on the result so a
                    // shared/screenshot result is never read out of context.
                    if (l10n.detectionCoverageNote != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.detectionCoverageNote!,
                        key: const ValueKey('coverage-note'),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF8A6A16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      l10n.analysedAt(
                        '${_two(result.analyzedAt.hour)}:'
                        '${_two(result.analyzedAt.minute)}',
                        result.indicators.length,
                      ),
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
                      child: Text(l10n.analyseAnother),
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
                      child: Text(l10n.copyReport),
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

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Plain-text report, in whichever language is active right now.
  ///
  /// The user's own input is reproduced verbatim (only truncated at 400
  /// characters for very long pastes), and URLs inside it are never rewritten.
  String buildReport(AppStrings l10n) {
    final buffer = StringBuffer()
      ..writeln(l10n.reportHeader(result.riskLevel))
      ..writeln(l10n.reportInputLabel(result.kind))
      ..writeln(result.inputPreview.length > 400
          ? '${result.inputPreview.substring(0, 400)}...'
          : result.inputPreview)
      ..writeln()
      ..writeln(l10n.reportWhyHeading);

    if (result.reasons.isEmpty) {
      buffer.writeln(l10n.reportNoSignals);
    } else {
      for (final i in result.reasons) {
        buffer.writeln(l10n.reportReasonLine(i.title, i.explanation));
      }
    }
    if (result.aiSummary != null) {
      buffer
        ..writeln()
        ..writeln(l10n.reportAiHeading)
        ..writeln(result.aiSummary);
    }
    buffer
      ..writeln()
      ..writeln(l10n.reportWhatToDoHeading)
      ..writeln(result.recommendation)
      ..writeln()
      ..writeln('${l10n.reportNoteHeading} ${l10n.reportNoteBody}');
    return buffer.toString();
  }

  Future<void> _copyReport(BuildContext context) async {
    final l10n = StringsScope.read(context);
    await copyToClipboard(buildReport(l10n));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.reportCopied)),
      );
  }
}

class _NoSignals extends StatelessWidget {
  const _NoSignals({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.low.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.low.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.low, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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
    final l10n = StringsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.aiExplanationTitle,
          icon: Icons.auto_awesome_outlined,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE9FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.aiExternalBadge,
              style: const TextStyle(
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
