import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';

class UatSurveyDialog extends StatefulWidget {
  final String sessionId;
  const UatSurveyDialog({super.key, required this.sessionId});

  @override
  State<UatSurveyDialog> createState() => _UatSurveyDialogState();
}

class _UatSurveyDialogState extends State<UatSurveyDialog> {
  static const _questions = [
    _SurveyQuestion(
      id: 'functional_suitability',
      text: 'Can you edit videos using natural language?',
      characteristic: 'Functional suitability',
    ),
    _SurveyQuestion(
      id: 'performance_efficiency',
      text: 'Is editing faster than manual timeline editing?',
      characteristic: 'Performance efficiency',
    ),
    _SurveyQuestion(
      id: 'usability',
      text: 'Is the interface intuitive for non-editors?',
      characteristic: 'Usability',
    ),
    _SurveyQuestion(
      id: 'reliability',
      text: 'Do failed operations leave your project unchanged?',
      characteristic: 'Reliability',
    ),
    _SurveyQuestion(
      id: 'security',
      text: 'Are you comfortable with the local-only processing model?',
      characteristic: 'Security',
    ),
  ];

  static const _likertLabels = [
    'Strongly Disagree',
    'Disagree',
    'Neutral',
    'Agree',
    'Strongly Agree',
  ];

  late final Map<String, int> _responses;

  @override
  void initState() {
    super.initState();
    _responses = {for (final q in _questions) q.id: 2};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: ClipMindColors.bgSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ClipMindColors.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.quiz, size: 20, color: ClipMindColors.accentPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'User Acceptance Testing',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate each statement based on your experience '
                      'with ClipMind.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    for (final question in _questions) ...[
                      _QuestionCard(
                        question: question,
                        value: _responses[question.id]!,
                        onChanged: (v) =>
                            setState(() => _responses[question.id] = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: ClipMindColors.borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _exportResults,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export Results'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportResults() async {
    final result = {
      'session_id': widget.sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'iso_iec_25010_evaluation': {
        for (final question in _questions)
          question.id: {
            'characteristic': question.characteristic,
            'question': question.text,
            'rating': _responses[question.id],
            'label': _likertLabels[_responses[question.id]!],
          },
      },
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/uat_results_${widget.sessionId}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results saved to ${file.path}'),
          backgroundColor: ClipMindColors.statusReady,
        ),
      );
    }
  }
}

class _SurveyQuestion {
  final String id;
  final String text;
  final String characteristic;
  const _SurveyQuestion({
    required this.id,
    required this.text,
    required this.characteristic,
  });
}

class _QuestionCard extends StatelessWidget {
  final _SurveyQuestion question;
  final int value;
  final ValueChanged<int> onChanged;

  const _QuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ClipMindColors.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  question.characteristic,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ClipMindColors.accentPrimary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.text, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 36,
                    margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: value == i
                          ? ClipMindColors.accentPrimary
                          : ClipMindColors.bgBase,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: value == i
                            ? ClipMindColors.accentPrimary
                            : ClipMindColors.borderColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getShortLabel(i),
                      style: TextStyle(
                        color: value == i ? Colors.white : ClipMindColors.textMuted,
                        fontSize: 9,
                        fontWeight: value == i ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static const _shortLabels = ['SD', 'D', 'N', 'A', 'SA'];

  String _getShortLabel(int index) => _shortLabels[index];
}
