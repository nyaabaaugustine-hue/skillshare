import 'package:flutter/material.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/shared/widgets/premium_button.dart';

import 'course_models.dart';

/// Runs a single course step: it walks the learner through the step's blocks
/// and reports a score when the step is finished.
class CourseLessonScreen extends StatefulWidget {
  const CourseLessonScreen({super.key, required this.step, this.onCompleted});

  final CourseStep step;

  /// Called once when the learner finishes the step. The value is 0-100.
  final ValueChanged<int>? onCompleted;

  @override
  State<CourseLessonScreen> createState() => _CourseLessonScreenState();
}

class _CourseLessonScreenState extends State<CourseLessonScreen> {
  int _index = 0;
  bool _satisfied = false;
  int _pendingScore = 100;
  int _hintLevel = 0;
  final List<int> _scores = <int>[];

  List<CourseBlock> get _blocks => widget.step.blocks;

  @override
  void initState() {
    super.initState();
    _resetForCurrentBlock();
  }

  bool _autoSatisfied(CourseBlock block) =>
      block is ReadingBlock || block is VideoBlock;

  void _resetForCurrentBlock() {
    _satisfied = _blocks.isEmpty || _autoSatisfied(_blocks[_index]);
    _pendingScore = 100;
    _hintLevel = 0;
  }

  List<String> _hintsFor(CourseBlock block) => switch (block) {
    CodeBlock b => b.hints,
    PromptBlock b => b.hints,
    _ => const <String>[],
  };

  void _satisfy(int score) {
    final clamped = score.clamp(0, 100);
    setState(() {
      _satisfied = true;
      _pendingScore = clamped;
    });
  }

  void _advance() {
    _scores.add(_satisfied ? _pendingScore : 100);
    final last = _index >= _blocks.length - 1;
    if (last) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _resetForCurrentBlock();
    });
  }

  void _finish() {
    final score = _scores.isEmpty
        ? 100
        : (_scores.reduce((a, b) => a + b) / _scores.length).round();
    widget.onCompleted?.call(score);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = _blocks.length;
    final isLast = _index >= total - 1;
    final progress = total == 0 ? 1.0 : (_index + 1) / total;
    final currentBlock = _blocks.isEmpty ? null : _blocks[_index];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.step.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.step.kind.label} - STEP ${(_index + 1)} OF $total',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: SkillBridgeColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: SkillBridgeColors.codeSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    SkillBridgeColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (currentBlock == null)
                    const _BlockCard(
                      title: 'Nothing to study yet',
                      child: Text(
                        'This step has no published content yet.',
                        style: TextStyle(color: SkillBridgeColors.textMuted),
                      ),
                    )
                  else ...[
                    _BlockCard(
                      title: "What you'll learn",
                      child: Text(
                        '${widget.step.title}: ${widget.step.subtitle}',
                        style: const TextStyle(
                          color: SkillBridgeColors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _blockView(currentBlock),
                  ],
                  if (currentBlock != null &&
                      _hintsFor(currentBlock).isNotEmpty)
                    _ProgressiveHint(
                      hints: _hintsFor(currentBlock),
                      revealed: _hintLevel,
                      onReveal: () => setState(() {
                        _hintLevel = (_hintLevel + 1).clamp(
                          0,
                          _hintsFor(currentBlock).length,
                        );
                      }),
                    ),
                  if (_satisfied && currentBlock is CodeBlock)
                    _CompletionSummary(block: currentBlock),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: PremiumButton(
            label: isLast ? 'FINISH LESSON' : 'CONTINUE',
            icon: isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
            gold: isLast,
            onPressed: _satisfied ? _advance : null,
          ),
        ),
      ),
    );
  }

  Widget _blockView(CourseBlock block) {
    return switch (block) {
      ReadingBlock b => _ReadingView(block: b),
      VideoBlock b => _VideoView(block: b, onWatched: () => _satisfy(100)),
      CodeBlock b => _CodeView(
        block: b,
        exerciseId: widget.step.id,
        onCompleted: _satisfy,
      ),
      QuizBlock b => _QuizView(block: b, onAnswered: _satisfy),
      PromptBlock b => _PromptView(block: b, onSatisfied: _satisfy),
      ApiBlock b => _ApiView(block: b, onSatisfied: _satisfy),
      ProjectBlock b => _ProjectView(block: b, onSatisfied: _satisfy),
      AssessmentBlock b => _AssessmentView(block: b, onScored: _satisfy),
    };
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProgressiveHint extends StatelessWidget {
  const _ProgressiveHint({
    required this.hints,
    required this.revealed,
    required this.onReveal,
  });

  final List<String> hints;
  final int revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final complete = revealed >= hints.length;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: SkillBridgeColors.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Need a nudge?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SkillBridgeColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$revealed/${hints.length}',
                style: const TextStyle(
                  color: SkillBridgeColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (revealed > 0) ...[
            const SizedBox(height: 8),
            for (final hint in hints.take(revealed))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $hint',
                  style: const TextStyle(
                    color: SkillBridgeColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: complete ? null : onReveal,
            icon: Icon(
              complete ? Icons.check_rounded : Icons.lightbulb_outline,
            ),
            label: Text(complete ? 'All hints shown' : 'Show next hint'),
          ),
        ],
      ),
    );
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView({required this.block});

  final ReadingBlock block;

  @override
  Widget build(BuildContext context) {
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in block.paragraphs) ...[
            Text(
              paragraph,
              style: const TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (block.tip != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SkillBridgeColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: SkillBridgeColors.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: SkillBridgeColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      block.tip!,
                      style: const TextStyle(
                        color: SkillBridgeColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.block, required this.onWatched});

  final VideoBlock block;

  /// Called when the learner returns from the player. The block is already
  /// satisfied (video steps are skippable); this only refreshes the score.
  final VoidCallback onWatched;

  @override
  Widget build(BuildContext context) {
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.subtitle,
            style: const TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.of(context).pushNamed(
                  '/lms-video',
                  arguments: <String, String>{
                    'title': block.heading,
                    'subtitle': block.subtitle,
                    'publicId': block.publicId,
                  },
                );
                onWatched();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2436), Color(0xFF101620)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: SkillBridgeColors.outline),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 62,
                    color: SkillBridgeColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Streamed from your LMS. Captions and progress are reported back '
            'through the same library.',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({
    required this.block,
    required this.exerciseId,
    required this.onCompleted,
  });

  final CodeBlock block;
  final String exerciseId;
  final ValueChanged<int> onCompleted;

  Exercise _exercise() => Exercise(
    id: exerciseId,
    title: block.heading,
    instructions: block.brief,
    starterCode: block.starterCode,
    requirements: block.requirements,
    hints: block.hints,
    expectedOutput: block.expectedOutput,
  );

  @override
  Widget build(BuildContext context) {
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Short explanation'),
          Text(
            block.brief,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (block.workedExample != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Worked example'),
            _CodePreview(code: block.workedExample!),
          ],
          const SizedBox(height: 16),
          const _SectionLabel('Try it'),
          Text(
            'Use the starter code to complete this task:',
            style: const TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _CodePreview(code: block.starterCode),
          const SizedBox(height: 14),
          const Text(
            'REQUIREMENTS',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          for (final requirement in block.requirements)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: SkillBridgeColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      requirement,
                      style: const TextStyle(
                        color: SkillBridgeColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (block.expectedOutput != null) ...[
            const SizedBox(height: 12),
            Text(
              'Expected output: ${block.expectedOutput}',
              style: const TextStyle(
                color: SkillBridgeColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 16),
          PremiumButton(
            icon: Icons.code_rounded,
            label: 'TRY IT IN THE CODE EDITOR',
            onPressed: () async {
              await Navigator.of(context).pushNamed(
                '/editor',
                arguments: <String, dynamic>{
                  'exercise': _exercise(),
                  'practice': PracticeSession(
                    block: block,
                    onCompleted: onCompleted,
                  ),
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: SkillBridgeColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CompletionSummary extends StatelessWidget {
  const _CompletionSummary({required this.block});

  final CodeBlock block;

  @override
  Widget build(BuildContext context) {
    final whyItWorks = block.whyItWorks;
    final takeaway = block.takeaway;
    if (whyItWorks == null && takeaway == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _BlockCard(
        title: 'Nice work!',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (whyItWorks != null) ...[
              const _SectionLabel('Why this works'),
              Text(
                whyItWorks,
                style: const TextStyle(
                  color: SkillBridgeColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (takeaway != null) ...[
              if (whyItWorks != null) const SizedBox(height: 14),
              const _SectionLabel('What you can now do'),
              Text(
                takeaway,
                style: const TextStyle(
                  color: SkillBridgeColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SkillBridgeColors.codeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.5,
          color: Color(0xFFB8C7E0),
        ),
      ),
    );
  }
}

class _QuizView extends StatefulWidget {
  const _QuizView({required this.block, required this.onAnswered});

  final QuizBlock block;
  final ValueChanged<int> onAnswered;

  @override
  State<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<_QuizView> {
  int? _selected;
  bool _checked = false;

  bool get _correct => _selected == widget.block.correctIndex;

  void _check() {
    if (_selected == null) return;
    setState(() => _checked = true);
    widget.onAnswered(_correct ? 100 : 60);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.question,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < block.options.length; i++)
            _Choice(
              label: block.options[i],
              selected: _selected == i,
              revealed: _checked,
              isCorrect: i == block.correctIndex,
              onTap: _checked ? null : () => setState(() => _selected = i),
            ),
          if (_checked) ...[
            const SizedBox(height: 12),
            _Feedback(correct: _correct, text: block.explanation),
          ] else ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _selected == null ? null : _check,
                child: const Text('Check answer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptView extends StatefulWidget {
  const _PromptView({required this.block, required this.onSatisfied});

  final PromptBlock block;
  final ValueChanged<int> onSatisfied;

  @override
  State<_PromptView> createState() => _PromptViewState();
}

class _PromptViewState extends State<_PromptView> {
  final TextEditingController _controller = TextEditingController();
  bool _checked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _containsAll(String text) {
    final lower = text.toLowerCase();
    return widget.block.mustInclude.every(
      (phrase) => lower.contains(phrase.toLowerCase()),
    );
  }

  bool get _meetsLength =>
      _controller.text.trim().length >= widget.block.minLength;

  bool get _met => _containsAll(_controller.text) && _meetsLength;

  void _onChanged(String _) {
    setState(() {});
    if (_met) widget.onSatisfied(100);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.task,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            maxLines: 7,
            minLines: 5,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 13.5,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Write your prompt here...',
              hintStyle: const TextStyle(color: SkillBridgeColors.textMuted),
              filled: true,
              fillColor: SkillBridgeColors.codeSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SkillBridgeColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SkillBridgeColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SkillBridgeColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_controller.text.trim().length} / ${block.minLength} characters minimum',
            style: TextStyle(
              color: _meetsLength
                  ? SkillBridgeColors.success
                  : SkillBridgeColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'MUST INCLUDE',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          for (final phrase in block.mustInclude)
            _RequirementRow(
              label: phrase,
              met: _controller.text.toLowerCase().contains(
                phrase.toLowerCase(),
              ),
            ),
          if (block.hints.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'HINTS',
              style: TextStyle(
                color: SkillBridgeColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            for (final hint in block.hints)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- $hint',
                  style: const TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (_checked && !_met)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _Feedback(
                correct: false,
                text:
                    'Cover every "must include" phrase and reach the minimum '
                    'length, then check again.',
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                setState(() => _checked = true);
                if (_met) widget.onSatisfied(100);
              },
              child: const Text('Check prompt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: met
                ? SkillBridgeColors.success
                : SkillBridgeColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: met
                    ? SkillBridgeColors.textPrimary
                    : SkillBridgeColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiView extends StatefulWidget {
  const _ApiView({required this.block, required this.onSatisfied});

  final ApiBlock block;
  final ValueChanged<int> onSatisfied;

  @override
  State<_ApiView> createState() => _ApiViewState();
}

class _ApiViewState extends State<_ApiView> {
  int? _endpoint;
  final Set<String> _fields = <String>{};
  String? _error;
  bool _sent = false;

  void _send() {
    final block = widget.block;
    final endpointOk = _endpoint == block.correctEndpointIndex;
    final fieldsOk = block.requiredFields.every(
      (field) => _fields.contains(field),
    );
    if (!endpointOk) {
      setState(() {
        _error = 'That endpoint does not create a completion. Try again.';
        _sent = false;
      });
      return;
    }
    if (!fieldsOk) {
      setState(() {
        _error = 'The request is missing a required field.';
        _sent = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _sent = true;
    });
    widget.onSatisfied(100);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.brief,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ENDPOINT',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < block.endpoints.length; i++)
            _Choice(
              label: block.endpoints[i],
              selected: _endpoint == i,
              revealed: false,
              isCorrect: false,
              monospace: true,
              onTap: () => setState(() => _endpoint = i),
            ),
          const SizedBox(height: 16),
          const Text(
            'REQUEST BODY',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final field in block.payloadFields)
                FilterChip(
                  label: Text(
                    field,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  selected: _fields.contains(field),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _fields.add(field);
                    } else {
                      _fields.remove(field);
                    }
                  }),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Feedback(correct: false, text: _error!),
          ],
          if (_sent) ...[
            const SizedBox(height: 12),
            const _Feedback(correct: true, text: 'Request accepted.'),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _send, child: const Text('Send request')),
        ],
      ),
    );
  }
}

class _ProjectView extends StatefulWidget {
  const _ProjectView({required this.block, required this.onSatisfied});

  final ProjectBlock block;
  final ValueChanged<int> onSatisfied;

  @override
  State<_ProjectView> createState() => _ProjectViewState();
}

class _ProjectViewState extends State<_ProjectView> {
  final Set<String> _done = <String>{};

  bool _allChecked() => widget.block.checklist.every(_done.contains);

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.brief,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (block.starterCode != null) ...[
            const SizedBox(height: 14),
            _CodePreview(code: block.starterCode!),
          ],
          const SizedBox(height: 16),
          const Text(
            'CHECKLIST',
            style: TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in block.checklist)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (_done.contains(item)) {
                    _done.remove(item);
                  } else {
                    _done.add(item);
                  }
                });
                if (_allChecked()) widget.onSatisfied(100);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _done.contains(item)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: _done.contains(item)
                          ? SkillBridgeColors.primary
                          : SkillBridgeColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: SkillBridgeColors.textPrimary,
                          fontSize: 13.5,
                          height: 1.4,
                          decoration: _done.contains(item)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (block.starterCode != null) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) => FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  '/editor',
                  arguments: Exercise(
                    id: 'course-project',
                    title: block.heading,
                    instructions: block.brief,
                    starterCode: block.starterCode!,
                    requirements: block.checklist,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Open starter in editor'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssessmentView extends StatefulWidget {
  const _AssessmentView({required this.block, required this.onScored});

  final AssessmentBlock block;
  final ValueChanged<int> onScored;

  @override
  State<_AssessmentView> createState() => _AssessmentViewState();
}

class _AssessmentViewState extends State<_AssessmentView> {
  final Map<int, int> _answers = <int, int>{};
  bool _submitted = false;
  int _percent = 0;

  void _submit() {
    final questions = widget.block.questions;
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correctIndex) correct++;
    }
    final percent = questions.isEmpty
        ? 100
        : ((correct / questions.length) * 100).round();
    setState(() {
      _submitted = true;
      _percent = percent;
    });
    widget.onScored(percent);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final allAnswered = _answers.length == block.questions.length;
    return _BlockCard(
      title: block.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var q = 0; q < block.questions.length; q++) ...[
            Text(
              '${q + 1}. ${block.questions[q].question}',
              style: const TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (var o = 0; o < block.questions[q].options.length; o++)
              _Choice(
                label: block.questions[q].options[o],
                selected: _answers[q] == o,
                revealed: _submitted,
                isCorrect: o == block.questions[q].correctIndex,
                onTap: _submitted
                    ? null
                    : () => setState(() => _answers[q] = o),
              ),
            if (_submitted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Feedback(
                  correct: _answers[q] == block.questions[q].correctIndex,
                  text: block.questions[q].explanation,
                ),
              ),
            const SizedBox(height: 18),
          ],
          if (!_submitted)
            FilledButton(
              onPressed: allAnswered ? _submit : null,
              child: const Text('Submit assessment'),
            )
          else
            _Feedback(
              correct: _percent >= 70,
              text:
                  'You scored $_percent%. '
                  '${_percent >= 70 ? 'Nice work.' : 'Review and run it again.'}',
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.revealed,
    required this.isCorrect,
    required this.onTap,
    this.monospace = false,
  });

  final String label;
  final bool selected;
  final bool revealed;
  final bool isCorrect;
  final VoidCallback? onTap;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    Color border = SkillBridgeColors.outline;
    Color background = SkillBridgeColors.codeSurface;
    if (selected) {
      border = SkillBridgeColors.primary;
      background = SkillBridgeColors.primary.withValues(alpha: 0.14);
    }
    if (revealed) {
      if (isCorrect) {
        border = SkillBridgeColors.success;
        background = SkillBridgeColors.success.withValues(alpha: 0.14);
      } else if (selected) {
        border = SkillBridgeColors.error;
        background = SkillBridgeColors.error.withValues(alpha: 0.14);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: SkillBridgeColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.35,
                    fontFamily: monospace ? 'monospace' : null,
                  ),
                ),
              ),
              if (revealed && isCorrect)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: SkillBridgeColors.success,
                ),
              if (revealed && selected && !isCorrect)
                const Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: SkillBridgeColors.error,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.text});

  final bool correct;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = correct ? SkillBridgeColors.success : SkillBridgeColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.info_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
