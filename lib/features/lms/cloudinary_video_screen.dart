import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';
import '../../integrations/cloudinary/cloudinary_config.dart';
import '../../shared/widgets/pressable.dart';
import '../course/practice_checks.dart';
import 'lesson_practice.dart';

class CloudinaryVideoScreen extends StatefulWidget {
  const CloudinaryVideoScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.publicId,
  });

  final String title;
  final String subtitle;
  final String publicId;

  @override
  State<CloudinaryVideoScreen> createState() => _CloudinaryVideoScreenState();
}

class _CloudinaryVideoScreenState extends State<CloudinaryVideoScreen> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() => _error = null);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(CloudinaryConfig.videoUrl(widget.publicId)),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _controller;
      setState(() => _controller = controller);
      await previous?.dispose();
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1018),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1018),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: SkillBridgeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: controller == null
          ? _LoadingOrError(
              error: _error,
              onRetry: _loadVideo,
              publicId: widget.publicId,
            )
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  const _LearningPathHeader(),
                  _VideoSurface(controller: controller, value: value),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Color(0xFFB8BAC6),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _LessonMeta(value: value),
                        const SizedBox(height: 20),
                        _InterwovenPractice(publicId: widget.publicId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.controller,
    required this.value,
    this.allowFullscreen = true,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool allowFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                if (!value.isPlaying)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: controller.play,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: SkillBridgeColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _PlaybackControls(
            controller: controller,
            value: value,
            allowFullscreen: allowFullscreen,
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.controller,
    required this.value,
    required this.allowFullscreen,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool allowFullscreen;

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    if (position > value.duration) return value.duration;
    return position;
  }

  Future<void> _seekBy(Duration offset) =>
      controller.seekTo(_clamp(value.position + offset));

  @override
  Widget build(BuildContext context) {
    final remaining = value.duration - value.position;
    final speed = value.playbackSpeed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
      child: Column(
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: SkillBridgeColors.accent,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _seekBy(const Duration(seconds: -10)),
                tooltip: 'Back 10 seconds',
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: value.isPlaying ? controller.pause : controller.play,
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              IconButton(
                onPressed: () => _seekBy(const Duration(seconds: 10)),
                tooltip: 'Forward 10 seconds',
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              ),
              Text(
                _formatTime(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Text(
                ' / ',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                _formatTime(value.duration),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showVolume(context),
                tooltip: 'Volume',
                icon: Icon(
                  value.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
              ),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: speed,
                onSelected: controller.setPlaybackSpeed,
                color: const Color(0xFF252735),
                itemBuilder: (_) => [
                  for (final item in [0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(
                      value: item,
                      child: Text(
                        '${item}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                icon: const Icon(Icons.speed_rounded, color: Colors.white),
              ),
              if (allowFullscreen)
                IconButton(
                  onPressed: () => _openFullscreen(context),
                  tooltip: 'Fullscreen',
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_formatTime(remaining)} remaining • HD',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showVolume(BuildContext context) async {
    var volume = value.volume;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF191B27),
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Row(
            children: [
              Icon(
                volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: SkillBridgeColors.accent,
              ),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: (next) {
                    setSheetState(() => volume = next);
                    controller.setVolume(next);
                  },
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: '${(volume * 100).round()}%',
                ),
              ),
              Text(
                '${(volume * 100).round()}%',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPlayer(controller: controller),
      ),
    );
  }
}

class _FullscreenPlayer extends StatelessWidget {
  const _FullscreenPlayer({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        title: const Text(
          'Fullscreen video',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => _VideoSurface(
            controller: controller,
            value: value,
            allowFullscreen: false,
          ),
        ),
      ),
    );
  }
}

class _LearningPathHeader extends StatelessWidget {
  const _LearningPathHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF191B27),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF303241)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SECTION FOUNDATIONS',
              style: TextStyle(
                color: Color(0xFF9C9EAB),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Unit 1: Python Kickstart',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PathNode(
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  active: true,
                ),
                const Expanded(child: _PathLine()),
                _PathNode(
                  icon: Icons.ondemand_video_rounded,
                  label: 'Watch',
                  active: true,
                ),
                const Expanded(child: _PathLine()),
                _PathNode(
                  icon: Icons.code_rounded,
                  label: 'Try',
                  active: false,
                ),
                const Expanded(child: _PathLine()),
                _PathNode(
                  icon: Icons.check_rounded,
                  label: 'Check',
                  active: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PathNode extends StatelessWidget {
  const _PathNode({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? SkillBridgeColors.accent : const Color(0xFF777A89);
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PathLine extends StatelessWidget {
  const _PathLine();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 17),
    height: 3,
    color: const Color(0xFF3A3C4A),
  );
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({
    required this.error,
    required this.onRetry,
    required this.publicId,
  });

  final Object? error;
  final VoidCallback onRetry;
  final String publicId;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.cloud_off_rounded : Icons.cloud_download_rounded,
              color: hasError
                  ? const Color(0xFFFFC857)
                  : SkillBridgeColors.accent,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              hasError
                  ? 'We could not load this lesson'
                  : 'Preparing your lesson',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? 'Check your connection and try again.' : 'Connecting securely to the SkillsBridge Academy video library.',
              style: const TextStyle(color: SkillBridgeColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (hasError)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              )
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            const SizedBox(height: 18),
            Text(
              'Video: $publicId',
              style: const TextStyle(color: Color(0xFF606271), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonMeta extends StatelessWidget {
  const _LessonMeta({required this.value});

  final VideoPlayerValue value;

  @override
  Widget build(BuildContext context) {
    final seconds = value.position.inSeconds;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return Row(
      children: [
        const Icon(
          Icons.play_circle_outline_rounded,
          color: SkillBridgeColors.accent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$minutes:${remaining.toString().padLeft(2, '0')} watched',
          style: const TextStyle(color: Color(0xFFB8BAC6)),
        ),
        const Spacer(),
        const Text(
          'Cloudinary • HD',
          style: TextStyle(color: Color(0xFFB8BAC6), fontSize: 12),
        ),
      ],
    );
  }
}

class _InterwovenPractice extends StatefulWidget {
  const _InterwovenPractice({required this.publicId});

  /// Identifies the lesson, so its own Code Lab task and quick check are shown.
  final String publicId;

  @override
  State<_InterwovenPractice> createState() => _InterwovenPracticeState();
}

class _InterwovenPracticeState extends State<_InterwovenPractice> {
  late final LessonPractice _practice = practiceForPublicId(widget.publicId);

  /// Score of the last finished Code Lab, once the learner has passed it.
  int? _labScore;

  /// How the quick check went, once the learner has answered it correctly.
  _CheckResult? _checkResult;

  /// Opens the real IDE on this lesson's task. The learner's program runs on
  /// the real Python runtime and is checked against the task's requirements.
  Future<void> _openCodeLab() async {
    await Navigator.of(context).pushNamed(
      '/editor',
      arguments: <String, dynamic>{
        'exercise': _practice.exercise,
        'practice': PracticeSession(
          block: _practice.codeLab,
          onCompleted: (int score) {
            if (mounted) setState(() => _labScore = score);
          },
        ),
      },
    );
  }

  Future<void> _openQuickCheck() async {
    final result = await showModalBottomSheet<_CheckResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191B27),
      showDragHandle: true,
      builder: (_) => _QuickCheckSheet(check: _practice.quickCheck),
    );
    if (result != null && mounted) setState(() => _checkResult = result);
  }

  @override
  Widget build(BuildContext context) {
    final labDone = _labScore != null;
    final check = _checkResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learn by doing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The practical is part of the lesson — not an extra assignment.',
          style: TextStyle(color: Color(0xFFB8BAC6), height: 1.4),
        ),
        const SizedBox(height: 14),
        const _FlowCard(
          index: '01',
          icon: Icons.play_circle_outline_rounded,
          color: SkillBridgeColors.accent,
          title: 'Watch the idea',
          body:
              'Follow the introduction video and pause whenever you want to try the idea yourself.',
        ),
        _FlowCard(
          index: '02',
          icon: Icons.code_rounded,
          color: const Color(0xFFFFC857),
          title: 'Try it in Code Lab',
          body: _practice.codeLab.brief,
          action: _openCodeLab,
          actionLabel: labDone ? 'Open again' : 'Open',
          badge: labDone ? 'Completed \u00b7 $_labScore%' : null,
        ),
        _FlowCard(
          index: '03',
          icon: Icons.quiz_rounded,
          color: const Color(0xFFC9A7FF),
          title: 'Quick check',
          body: _practice.quickCheck.question,
          action: _openQuickCheck,
          actionLabel: check != null ? 'Open again' : 'Open',
          badge: check == null
              ? null
              : (check.attempts == 1
                    ? 'Correct on the first try'
                    : 'Correct \u00b7 ${check.attempts} tries'),
        ),
      ],
    );
  }
}

/// Outcome handed back by the quick-check sheet once it is answered correctly.
class _CheckResult {
  const _CheckResult({required this.attempts});

  final int attempts;
}

/// A one-question check with instant feedback. Tapping an answer says right
/// away whether it is correct: wrong answers shake and turn red (and stay
/// disabled so the learner tries another); the right answer turns green and
/// the explanation locks the idea in.
class _QuickCheckSheet extends StatefulWidget {
  const _QuickCheckSheet({required this.check});

  final QuickCheck check;

  @override
  State<_QuickCheckSheet> createState() => _QuickCheckSheetState();
}

class _QuickCheckSheetState extends State<_QuickCheckSheet> {
  final Set<int> _wrong = <int>{};
  bool _correct = false;
  int _attempts = 0;

  void _answer(int index) {
    if (_correct || _wrong.contains(index)) return;
    final ok = index == widget.check.correctIndex;
    setState(() {
      _attempts++;
      if (ok) {
        _correct = true;
      } else {
        _wrong.add(index);
      }
    });
    if (ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  _TileState _stateOf(int i) {
    if (_correct) {
      return i == widget.check.correctIndex
          ? _TileState.correct
          : (_wrong.contains(i) ? _TileState.wrong : _TileState.dimmed);
    }
    return _wrong.contains(i) ? _TileState.wrong : _TileState.idle;
  }

  Widget _feedback() {
    if (_correct) {
      return _FeedbackCard(
        key: const ValueKey('correct'),
        correct: true,
        title: _attempts == 1 ? 'Correct! First try.' : 'Correct!',
        body: widget.check.explanation,
      );
    }
    if (_wrong.isEmpty) {
      return const Padding(
        key: ValueKey('idle'),
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'Tap an answer \u2014 you will know straight away.',
          style: TextStyle(color: Color(0xFF8E90A0), fontSize: 12.5),
        ),
      );
    }
    return _FeedbackCard(
      key: ValueKey('wrong${_wrong.length}'),
      correct: false,
      title: 'Not quite',
      body: _wrong.length >= 2
          ? 'Here is a clue: ${widget.check.explanation}'
          : 'That is not the one. Try another answer.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A7FF).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz_rounded, color: Color(0xFFC9A7FF)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Quick check',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_attempts > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _attempts == 1 ? '1 try' : '$_attempts tries',
                      style: const TextStyle(
                        color: Color(0xFFB8BAC6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              check.question,
              style: const TextStyle(
                color: Color(0xFFE6E7EE),
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < check.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerTile(
                  letter: String.fromCharCode(65 + i),
                  label: check.options[i],
                  state: _stateOf(i),
                  onTap: () => _answer(i),
                ),
              ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _feedback(),
              ),
            ),
            if (_correct) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_CheckResult(attempts: _attempts)),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _TileState { idle, wrong, correct, dimmed }

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _TileState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, IconData? icon) = switch (state) {
      _TileState.idle => (
        const Color(0xFF303241),
        const Color(0xFF14161F),
        null,
      ),
      _TileState.wrong => (
        SkillBridgeColors.error,
        SkillBridgeColors.error.withValues(alpha: 0.12),
        Icons.cancel_rounded,
      ),
      _TileState.correct => (
        SkillBridgeColors.success,
        SkillBridgeColors.success.withValues(alpha: 0.14),
        Icons.check_circle_rounded,
      ),
      _TileState.dimmed => (
        const Color(0xFF303241),
        const Color(0xFF14161F),
        null,
      ),
    };
    final enabled = state == _TileState.idle;

    Widget tile = Pressable(
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: border.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: state == _TileState.idle
                          ? const Color(0xFFB8BAC6)
                          : border,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: state == _TileState.dimmed
                          ? const Color(0xFF7C7E8E)
                          : Colors.white,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, color: border, size: 22),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrong: a quick horizontal shake. Right: a springy pop. Each plays once,
    // when the tile first enters that state.
    if (state == _TileState.wrong) {
      tile = TweenAnimationBuilder<double>(
        key: const ValueKey('shake'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        builder: (context, t, child) => Transform.translate(
          offset: Offset(math.sin(t * math.pi * 6) * 9 * (1 - t), 0),
          child: child,
        ),
        child: tile,
      );
    } else if (state == _TileState.correct) {
      tile = TweenAnimationBuilder<double>(
        key: const ValueKey('pop'),
        tween: Tween<double>(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: tile,
      );
    }
    return tile;
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    super.key,
    required this.correct,
    required this.title,
    required this.body,
  });

  final bool correct;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final color = correct ? SkillBridgeColors.success : SkillBridgeColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.celebration_rounded : Icons.info_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFE6E7EE),
                    fontSize: 13.5,
                    height: 1.45,
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

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
    this.actionLabel = 'Open',
    this.badge,
  });

  final String index;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback? action;
  final String actionLabel;

  /// Shown once the learner has completed this part (e.g. "Completed \u00b7 90%").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        enabled: action != null,
        scale: 0.985,
        child: GestureDetector(
          onTap: action,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF191B27),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: badge != null
                    ? SkillBridgeColors.success.withValues(alpha: 0.55)
                    : const Color(0xFF303241),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP $index',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFFB8BAC6),
                          height: 1.4,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: SkillBridgeColors.success
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: SkillBridgeColors.success,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                badge!,
                                style: const TextStyle(
                                  color: SkillBridgeColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (action != null) ...[
                        const SizedBox(height: 11),
                        FilledButton.tonalIcon(
                          onPressed: action,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                          label: Text(actionLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
