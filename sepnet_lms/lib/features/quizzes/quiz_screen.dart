import 'package:flutter/material.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/lessons/inline_code_text.dart';
import 'package:skillbridge_python_lab/features/quizzes/quiz.dart';

/// A single formative quiz question with selectable answers and inline feedback.
///
/// The optional callback reports a local 0/100 result to the caller. It is not
/// an official grade or a server-verified achievement.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.quiz,
    this.onAnswered,
    super.key,
  });

  final Quiz quiz;
  final ValueChanged<int>? onAnswered;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _selectedIndex;
  bool _checked = false;

  bool get _isCorrect => _selectedIndex == widget.quiz.correctIndex;

  void _checkAnswer() {
    if (_selectedIndex == null || _checked || widget.quiz.options.isEmpty) return;
    setState(() => _checked = true);
    widget.onAnswered?.call(_isCorrect ? 100 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipBackground = isDark
        ? const Color(0xFFE8EDF4)
        : AppTheme.codeSurface;
    final chipForeground = isDark
        ? const Color(0xFF111A26)
        : const Color(0xFFF2F5F9);
    final chipBorder = isDark
        ? const Color(0xFFB9C4D2)
        : const Color(0xFF243447);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InlineCodeText(
                    widget.quiz.prompt,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.quiz.options.isEmpty)
                    Text(
                      'No answer choices are available for this question yet.',
                      style: TextStyle(color: context.appColors.textMuted),
                    )
                  else
                    for (var index = 0;
                        index < widget.quiz.options.length;
                        index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _AnswerChoice(
                          text: widget.quiz.options[index].text,
                          selected: _selectedIndex == index,
                          checked: _checked,
                          correct: index == widget.quiz.correctIndex,
                          background: chipBackground,
                          foreground: chipForeground,
                          border: chipBorder,
                          onTap: _checked
                              ? null
                              : () => setState(() => _selectedIndex = index),
                        ),
                      ),
                  if (_checked) ...[
                    const SizedBox(height: 14),
                    _AnswerFeedback(
                      correct: _isCorrect,
                      answer: widget.quiz.correctOption.text,
                      explanation: widget.quiz.explanation,
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _checked
                          ? 'This is practice feedback, not an official grade.'
                          : 'Select an answer, then tap CHECK.',
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _selectedIndex == null || _checked
                          ? null
                          : _checkAnswer,
                      child: Text(_checked ? 'ANSWER CHECKED' : 'CHECK'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerChoice extends StatelessWidget {
  const _AnswerChoice({
    required this.text,
    required this.selected,
    required this.checked,
    required this.correct,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool checked;
  final bool correct;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = checked && correct
        ? SkillBridgeColors.success
        : checked && selected
        ? SkillBridgeColors.error
        : selected
        ? SkillBridgeColors.primary
        : border;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tone, width: selected || (checked && correct) ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: checked && correct ? SkillBridgeColors.success : foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (checked && correct)
                const Icon(Icons.check_circle_rounded, color: SkillBridgeColors.success),
              if (checked && selected && !correct)
                const Icon(Icons.cancel_rounded, color: SkillBridgeColors.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({
    required this.correct,
    required this.answer,
    required this.explanation,
  });

  final bool correct;
  final String answer;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final message = correct ? 'Correct!' : 'Not quite. The correct answer is "$answer".';
    final color = correct ? SkillBridgeColors.success : SkillBridgeColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation!,
              style: TextStyle(color: context.appColors.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
