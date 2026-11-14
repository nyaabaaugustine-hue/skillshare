import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/core/errors/app_exception.dart';
import 'package:skillbridge_python_lab/features/home/connectivity_controller.dart';
import 'package:skillbridge_python_lab/features/settings/settings_controller.dart';
import 'package:skillbridge_python_lab/features/editor/editor_controller.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';
import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/python_runtime/execution_result.dart';

import 'widgets/code_editing_controller.dart';
import 'widgets/code_editor.dart';
import 'widgets/output_console.dart';
import 'widgets/shortcut_bar.dart';

/// Screen B + C + E: the Python editor, shortcut bar and output console.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.exercise, this.practice});

  final Exercise exercise;

  /// Set when opened from a course practice step: runs are checked against the
  /// step's requirements and the learner finishes the step from here instead of
  /// submitting to the LMS.
  final PracticeSession? practice;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final AppDependencies _deps;
  late final EditorController _editor;
  late final CodeEditingController _codeController;
  late final FocusNode _focusNode;

  bool _initialising = true;
  bool _showInstructions = true;
  String? _initialiseError;

  /// Whether we closed the instructions panel ourselves when the field gained
  /// focus, so we know it is safe to reopen on blur.
  bool _restoreInstructions = true;

  // Practice mode: the latest real run's verdict, and how many runs failed the
  // checks before it passed (which lowers the score the step earns).
  PracticeVerdict? _verdict;
  int _failedRuns = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _deps = context.read<AppDependencies>();
    _editor = EditorController(deps: _deps, exercise: widget.exercise);
    _codeController = CodeEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _codeController.addListener(_onCodeChanged);
    _editor.addListener(_onEditorChanged);
    _initialise();
  }

  /// Entering the field on a phone should get out of the learner's way: close
  /// the instructions panel so the code area keeps its height. Leaving the
  /// field restores it, but only if we were the ones who closed it.
  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      if (_showInstructions) {
        _restoreInstructions = true;
        setState(() => _showInstructions = false);
      }
    } else if (_restoreInstructions) {
      _restoreInstructions = false;
      setState(() => _showInstructions = true);
    }
  }

  Future<void> _initialise() async {
    if (mounted) {
      setState(() {
        _initialising = true;
        _initialiseError = null;
      });
    }
    try {
      await _editor.load();
      _codeController.text = _editor.code;
      _codeController.selection = TextSelection.collapsed(
        offset: _editor.code.length,
      );
    } catch (e) {
      _codeController.text = widget.exercise.starterCode;
      _codeController.selection = TextSelection.collapsed(
        offset: _codeController.text.length,
      );
      _initialiseError = e is AppException
          ? '${e.userMessage} You can still edit your code and try again.'
          : 'Your saved draft could not be loaded. You can still edit your '
              'code and try again.';
    } finally {
      _initialising = false;
      if (mounted) setState(() {});
    }
  }

  void _onCodeChanged() {
    if (_initialising) return;
    _editor.updateCode(_codeController.text);
    // An edit makes the last verdict stale; the learner must run again.
    if (_verdict != null && mounted) setState(() => _verdict = null);
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _codeController.removeListener(_onCodeChanged);
    _editor.removeListener(_onEditorChanged);
    _editor.dispose();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_initialising || _editor.isRunning || _editor.isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _showInstructions = false);
    if (widget.exercise.id == 'ex-input' && _editor.stdinText.isEmpty) {
      await _promptForInput();
    }
    if (!mounted) return;
    try {
      final result = await _editor.run();
      _evaluatePractice(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The program could not start. Check your code and try again.',
          ),
        ),
      );
    }
  }

  /// Practice mode only: checks the real output of the run just completed.
  void _evaluatePractice(ExecutionResult result) {
    final practice = widget.practice;
    if (practice == null || result.isCancelled || !mounted) return;
    final verdict = evaluatePractice(
      block: practice.block,
      code: _editor.code,
      result: result,
    );
    setState(() {
      _verdict = verdict;
      if (!verdict.passed) _failedRuns++;
    });
  }

  /// Awards the step. Each failed run before passing costs 10 points (floor 60),
  /// so the score reflects real effort and feeds the guardian report.
  void _finishPractice() {
    final practice = widget.practice;
    final verdict = _verdict;
    if (practice == null || verdict == null || !verdict.passed || _finished) {
      return;
    }
    _finished = true;
    final score = _failedRuns >= 4 ? 60 : 100 - _failedRuns * 10;
    practice.onCompleted(score);
    Navigator.of(context).pop();
  }

  Future<void> _promptForInput() async {
    final controller = TextEditingController(text: _editor.stdinText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Program input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This exercise uses input(). Type one answer per line.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (result != null) {
      _editor.setStdinText(result);
    }
  }

  Future<void> _submit() async {
    if (_initialising || _editor.isRunning || _editor.isSubmitting) return;
    try {
      await _editor.submit();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your work is safe. We could not submit it yet — please try again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    context.read<ConnectivityController>().refreshPendingCount();
    _showSubmitFeedback();
  }

  void _showSubmitFeedback() {
    final messenger = ScaffoldMessenger.of(context);
    final message = _editor.submitMessage ?? 'Submission saved.';
    Color background;
    IconData icon;
    switch (_editor.lastSubmitOutcome) {
      case SubmitOutcome.accepted:
        background = const Color(0xFF2E7D32);
        icon = Icons.verified;
      case SubmitOutcome.rejected:
        background = const Color(0xFFB71C1C);
        icon = Icons.refresh;
      case SubmitOutcome.queuedOffline:
        background = const Color(0xFF5D4037);
        icon = Icons.cloud_off;
      case SubmitOutcome.authExpired:
      case SubmitOutcome.failed:
      case null:
        background = const Color(0xFF37474F);
        icon = Icons.error_outline;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_initialising) return;
    try {
      await _editor.saveDraft();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not save the draft, but your code is still on screen.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved on this device.')),
    );
  }

  Future<void> _reset() async {
    if (_initialising || _editor.isRunning || _editor.isSubmitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset code?'),
        content: const Text(
          'This replaces your code with the starter code. Your saved draft will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _editor.resetToStarter();
      _codeController.text = _editor.code;
      _codeController.selection = TextSelection.collapsed(
        offset: _editor.code.length,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The starter code could not be restored. Your current code is still safe.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = context.watch<ConnectivityController>().isOnline;
    // Reading the inset here (rather than caching it) means the layout reacts
    // the instant the keyboard appears or hides, with no observer to keep in
    // sync. This is what lets us keep the editor visible above the keyboard.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exercise.title, style: const TextStyle(fontSize: 17)),
            if (!online)
              const Text(
                'Offline — your work is saved locally',
                style: TextStyle(fontSize: 11, color: Color(0xFFFFE0A3)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exercise details',
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                setState(() => _showInstructions = !_showInstructions),
          ),
          IconButton(
            tooltip: 'Save draft',
            icon: Icon(
              _editor.hasUnsavedChanges ? Icons.save : Icons.save_outlined,
            ),
            onPressed: _initialising ? null : _saveDraft,
          ),
          IconButton(
            tooltip: 'Reset code',
            icon: const Icon(Icons.restart_alt),
            onPressed:
                _initialising || _editor.isRunning || _editor.isSubmitting
                ? null
                : _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Focus mode: while the soft keyboard is up, every fixed row above
            // the editor is height the learner cannot see code with. Drop the
            // preview + instructions entirely and let the editor take the room.
            if (!keyboardVisible) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/course_previews/python_quick_start.png',
                    width: double.infinity,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (_showInstructions) _InstructionsCard(exercise: widget.exercise),
            ],
            if (_initialiseError != null)
              _RuntimeWarning(message: _initialiseError!, onRetry: _initialise),
            Expanded(
              // The editor is the reason this screen exists, so it grows. It
              // keeps a floor so even a short landscape phone still shows a few
              // rows with the console open.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: _initialising
                    ? Center(
                        // Scrollable: with the instructions panel open the slot
                        // can be shorter than the indicator, which otherwise
                        // overflows the flex.
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Loading your code…',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The Python runner starts when you press Run.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : CodeEditor(
                        controller: _codeController,
                        focusNode: _focusNode,
                        fontSize: context
                            .watch<SettingsController>()
                            .editorFontSize,
                        indentUnit: context
                            .watch<SettingsController>()
                            .indentUnit,
                      ),
              ),
            ),
            // Keyboard up: a one-line console keeps recent output glanceable
            // without stealing the editor's height.
            SizedBox(
              height: keyboardVisible
                  ? 84
                  : (_verdict == null ? 160 : 100),
              child: OutputConsole(
                result: _editor.result,
                isRunning: _editor.isRunning,
                compact: keyboardVisible,
              ),
            ),
            // The checklist is post-run feedback the learner reads between
            // edits, not while typing; hiding it while the keyboard is up keeps
            // a short phone from overflowing.
            if (_verdict != null && !keyboardVisible)
              _ChecklistPanel(verdict: _verdict!),
            ShortcutBar(controller: _codeController, focusNode: _focusNode),
            _ActionBar(
              isRunning: _editor.isRunning,
              isSubmitting: _editor.isSubmitting,
              onRun: _run,
              onStop: _editor.stop,
              onSubmit: _submit,
              practiceMode: widget.practice != null,
              canFinish: _verdict?.passed ?? false,
              onFinish: _finishPractice,
            ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _RuntimeWarning extends StatelessWidget {
  const _RuntimeWarning({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2B16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A6728)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFFD180)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFE6B0)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.instructions, style: theme.textTheme.bodyMedium),
          if (exercise.requirements.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final requirement in exercise.requirements)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_box_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        requirement,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Live checklist for a practice step: one row per requirement, ticked or not
/// from the real output of the last run.
class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({required this.verdict});

  final PracticeVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final passed = verdict.passed;
    final color = passed ? SkillBridgeColors.success : SkillBridgeColors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 112),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    passed ? Icons.verified_rounded : Icons.rule_rounded,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      passed
                          ? 'All checks passed — nice work!'
                          : '${verdict.passedCount} of ${verdict.checks.length} checks passed',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final check in verdict.checks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        check.passed
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 15,
                        color: check.passed
                            ? SkillBridgeColors.success
                            : SkillBridgeColors.error,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          check.label,
                          style: const TextStyle(fontSize: 12.5, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isRunning,
    required this.isSubmitting,
    required this.onRun,
    required this.onStop,
    required this.onSubmit,
    this.practiceMode = false,
    this.canFinish = false,
    this.onFinish,
  });

  final bool isRunning;
  final bool isSubmitting;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onSubmit;

  /// Course practice: "Finish step" (enabled once the checks pass) replaces
  /// the LMS "Submit" button.
  final bool practiceMode;
  final bool canFinish;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: isRunning
                  ? FilledButton.icon(
                      onPressed: onStop,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                      ),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    )
                  : FilledButton.icon(
                      onPressed: onRun,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run'),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: practiceMode
                  ? FilledButton.icon(
                      onPressed: canFinish ? onFinish : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: SkillBridgeColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: SkillBridgeColors.surfaceHigh,
                      ),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Finish step'),
                    )
                  : OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Submit'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
