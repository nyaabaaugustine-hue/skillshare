import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';

import 'dart:async';

import 'package:provider/provider.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/course/course_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/home/review_plan.dart';
import 'package:skillbridge_python_lab/shared/widgets/code_buddy.dart';
import 'package:skillbridge_python_lab/shared/widgets/premium_button.dart';

/// Screen: the gamified course path.
///
/// A status bar sits above a unit card, a "Start" divider and a winding path of
/// shield-shaped nodes. Nodes reflect the learner's progress and open the
/// matching lesson; locked nodes explain what unlocks them.
class CoursePathScreen extends StatelessWidget {
  const CoursePathScreen({
    super.key,
    required this.controller,
    this.onMenuTap,
    this.onStepCompleted,
    this.onLeaderboardTap,
  });

  final CourseController controller;
  final VoidCallback? onMenuTap;

  /// Called after a finished step has been persisted, so the app can email the
  /// Parent / Guardian a progress report. Optional: tests leave it null.
  final Future<void> Function(CourseStep step, int score)? onStepCompleted;

  /// Opens the shared ranking. Optional so tests and other hosts can omit it.
  final VoidCallback? onLeaderboardTap;

  Future<void> _openStep(BuildContext context, int index) async {
    final status = controller.statusFor(index);
    if (status == CourseStepStatus.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish the previous step to unlock this one.'),
        ),
      );
      return;
    }
    final step = controller.course.steps[index];

    // If the learner stops halfway, the reminder at +3h is already armed; it is
    // cancelled below as soon as the step is finished.
    unawaited(
      context.read<AppDependencies>().reminders.onLessonOpened(step.title),
    );

    await Navigator.of(context).pushNamed(
      '/course-lesson',
      arguments: <String, dynamic>{
        'step': step,
        'onCompleted': (int score) async {
          await controller.markCompleted(step, score: score);
          if (context.mounted) {
            unawaited(
              context.read<AppDependencies>().reminders.onStepCompleted(),
            );
          }
          await onStepCompleted?.call(step, score);
        },
      },
    );
  }

  Future<void> _openStepById(BuildContext context, CourseStep step) async {
    final index = controller.course.steps.indexWhere((s) => s.id == step.id);
    if (index >= 0) await _openStep(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CourseStatusBar(
              controller: controller,
              onMenuTap: onMenuTap,
              onLeaderboardTap: onLeaderboardTap,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UnitCard(
                      controller: controller,
                      onContinue: controller.currentIndex == -1
                          ? null
                          : () => _openStep(context, controller.currentIndex),
                    ),
                    if (!controller.isLoading && controller.error == null)
                      _ReviewCard(
                        items: buildReviewPlan(
                          course: controller.course,
                          history: controller.history,
                          completed: <String>{
                            for (final step in controller.course.steps)
                              if (controller.isCompleted(step.id)) step.id,
                          },
                        ),
                        onOpen: (step) => _openStepById(context, step),
                      ),
                    const _StartDivider(),
                    if (controller.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (controller.error != null)
                      _PathMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Progress unavailable',
                        message: controller.error!,
                        actionLabel: 'Retry',
                        onAction: controller.load,
                      )
                    else if (controller.totalSteps == 0)
                      const _PathMessage(
                        icon: Icons.inbox_rounded,
                        title: 'No steps yet',
                        message: 'This course has no published steps yet. Check back soon.',
                      )
                    else
                      _CoursePath(
                        controller: controller,
                        onOpenStep: (index) => _openStep(context, index),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CourseStatusBar extends StatelessWidget {
  const _CourseStatusBar({
    required this.controller,
    this.onMenuTap,
    this.onLeaderboardTap,
  });

  final CourseController controller;
  final VoidCallback? onMenuTap;
  final VoidCallback? onLeaderboardTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded),
              color: context.appColors.textPrimary,
              tooltip: 'Open menu',
            ),
          const CodeBuddy(size: 64, mood: BuddyMood.happy),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onLeaderboardTap != null)
                    IconButton(
                      onPressed: onLeaderboardTap,
                      icon: const Icon(Icons.emoji_events_rounded),
                      color: SkillBridgeColors.accent,
                      tooltip: 'Leaderboard',
                    ),
                  _StatPill(
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF7A45),
                    value: '${controller.streak}',
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.bolt_rounded,
                    color: SkillBridgeColors.accent,
                    value: '${controller.xpEarned}',
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.diamond_rounded,
                    color: const Color(0xFF5EC8FF),
                    value: '${controller.coinsEarned}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.controller, this.onContinue});

  final CourseController controller;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final remaining = controller.totalSteps - controller.completedCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SkillBridgeColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CodeBuddy(size: 46, mood: BuddyMood.happy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.course.sectionLabel,
                      style: const TextStyle(
                        color: SkillBridgeColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.course.title,
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            controller.course.subtitle,
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: controller.progress,
              minHeight: 9,
              backgroundColor: SkillBridgeColors.codeSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                SkillBridgeColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${controller.completedCount} / ${controller.totalSteps} steps',
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                remaining == 0 ? 'Course complete' : '$remaining to go',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 16),
            PremiumButton(
              label: controller.completedCount == 0
                  ? 'START LEARNING'
                  : 'CONTINUE · ${controller.nextStep?.title ?? ''}',
              icon: Icons.play_arrow_rounded,
              onPressed: onContinue,
            ),
          ],
        ],
      ),
    );
  }
}

class _StartDivider extends StatelessWidget {
  const _StartDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: context.appColors.outline, thickness: 1.5),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: context.appColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appColors.outline),
            ),
            child: Text(
              'START',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: context.appColors.outline, thickness: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PathMessage extends StatelessWidget {
  const _PathMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: context.appColors.textMuted),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// The winding path: shield nodes over curved connectors, drawn in one canvas.
class _CoursePath extends StatelessWidget {
  const _CoursePath({required this.controller, required this.onOpenStep});

  final CourseController controller;
  final ValueChanged<int> onOpenStep;

  static const double _nodeSize = 94;
  static const double _rowStep = 158;
  static const double _topPad = 18;
  static const double _bottomPad = 48;
  static const List<double> _wiggle = <double>[
    0,
    0.55,
    0.9,
    0.6,
    0.05,
    -0.55,
    -0.9,
    -0.45,
  ];

  @override
  Widget build(BuildContext context) {
    final steps = controller.course.steps;
    final outline = context.appColors.outline;
    final background = context.appColors.background;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final amplitude = math.min(width * 0.19, 62.0);
        final centerX = width / 2;

        final centers = <Offset>[
          for (var i = 0; i < steps.length; i++)
            Offset(
              centerX + _wiggle[i % _wiggle.length] * amplitude,
              _topPad + i * _rowStep + _nodeSize / 2,
            ),
        ];

        final canvasHeight =
            _topPad + (steps.length - 1) * _rowStep + _nodeSize + _bottomPad;

        return SizedBox(
          height: canvasHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    centers: centers,
                    segmentColors: <Color>[
                      for (var i = 0; i < centers.length - 1; i++)
                        _colorFor(controller.statusFor(i + 1), outline),
                    ],
                    lineColor: background,
                    dotColor: outline.withValues(alpha: 0.35),
                  ),
                ),
              ),
              for (var i = 0; i < steps.length; i++)
                Positioned(
                  left: centers[i].dx - _nodeSize / 2,
                  top: _topPad + i * _rowStep,
                  width: _nodeSize,
                  child: _ShieldNode(
                    step: steps[i],
                    index: i,
                    status: controller.statusFor(i),
                    onTap: () => onOpenStep(i),
                  ),
                ),
              for (var i = 0; i < steps.length; i++)
                Positioned(
                  left: centers[i].dx - 70,
                  top: _topPad + i * _rowStep + _nodeSize + 6,
                  width: 140,
                  child: _StepLabel(step: steps[i], index: i),
                ),
            ],
          ),
        );
      },
    );
  }

  static Color _colorFor(CourseStepStatus status, Color lockedColor) =>
      switch (status) {
        CourseStepStatus.completed => SkillBridgeColors.primary,
        CourseStepStatus.current => SkillBridgeColors.primary,
        CourseStepStatus.available => SkillBridgeColors.primary,
        CourseStepStatus.locked => lockedColor,
      };
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.step, required this.index});

  final CourseStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${step.kind.label} · STEP ${(index + 1).toString().padLeft(2, '0')}',
          style: TextStyle(
            color: context.appColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          step.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.appColors.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ShieldNode extends StatelessWidget {
  const _ShieldNode({
    required this.step,
    required this.index,
    required this.status,
    required this.onTap,
  });

  final CourseStep step;
  final int index;
  final CourseStepStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status == CourseStepStatus.locked;
    final current = status == CourseStepStatus.current;
    final completed = status == CourseStepStatus.completed;

    final face = switch (status) {
      CourseStepStatus.completed => SkillBridgeColors.primary,
      CourseStepStatus.current => SkillBridgeColors.primary,
      CourseStepStatus.available => context.appColors.surfaceHigh,
      CourseStepStatus.locked => context.appColors.surface,
    };
    final lip = switch (status) {
      CourseStepStatus.completed => const Color(0xFF0A5EB0),
      CourseStepStatus.current => const Color(0xFF0A5EB0),
      CourseStepStatus.available => context.appColors.outline,
      CourseStepStatus.locked => context.appColors.outline,
    };
    final Color iconColor = switch (status) {
      CourseStepStatus.locked => context.appColors.textMuted,
      CourseStepStatus.available => SkillBridgeColors.primary,
      CourseStepStatus.current => Colors.white,
      CourseStepStatus.completed => Colors.white,
    };

    return Semantics(
      button: true,
      enabled: !locked,
      label: 'Step ${index + 1}: ${step.title}',
      child: GestureDetector(
        key: ValueKey<String>('course-step-$index'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 94,
          height: 94,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (current)
                Positioned(
                  left: -16,
                  top: -16,
                  right: -16,
                  bottom: -16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          SkillBridgeColors.primary.withValues(alpha: 0.40),
                          SkillBridgeColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              // Base lip gives the chunky 3D edge.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: const _ShieldClipper(),
                  child: Container(color: lip),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 7,
                child: ClipPath(
                  clipper: const _ShieldClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: face,
                      gradient: locked || status == CourseStepStatus.available
                          ? null
                          : LinearGradient(
                              colors: [
                                Color.lerp(face, Colors.white, 0.16)!,
                                face,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                    ),
                    child: Center(
                      child: step.previewAsset != null && !locked
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  step.previewAsset!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    step.kind.icon,
                                    color: iconColor,
                                    size: 34,
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Icon(
                                      step.kind.icon,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Icon(
                                step.kind.icon,
                                color: iconColor,
                                size: 34,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 7,
                child: CustomPaint(
                  painter: _ShieldBorderPainter(
                    color: locked
                        ? context.appColors.outline
                        : SkillBridgeColors.primary.withValues(alpha: 0.65),
                    strokeWidth: 2,
                  ),
                ),
              ),
              if (completed)
                const Positioned(
                  right: -2,
                  bottom: 2,
                  child: _NodeBadge(
                    icon: Icons.check_rounded,
                    background: SkillBridgeColors.success,
                  ),
                ),
              if (locked)
                Positioned(
                  right: -2,
                  bottom: 2,
                  child: _NodeBadge(
                    icon: Icons.lock_rounded,
                    background: context.appColors.surfaceHigh,
                    foreground: context.appColors.textMuted,
                  ),
                ),
              if (current)
                Positioned(
                  bottom: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: SkillBridgeColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'START',
                      style: TextStyle(
                        color: Color(0xFF20160A),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({
    required this.icon,
    required this.background,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: context.appColors.background, width: 3),
      ),
      child: Icon(icon, size: 13, color: foreground),
    );
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.3;
    final shoulder = h * 0.6;
    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, shoulder)
      ..quadraticBezierTo(w, h * 0.88, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.88, 0, shoulder)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShieldBorderPainter extends CustomPainter {
  _ShieldBorderPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _ShieldClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Draws the dotted backdrop and the thick curved connectors between nodes.
class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.centers,
    required this.segmentColors,
    required this.lineColor,
    required this.dotColor,
  });

  final List<Offset> centers;
  final List<Color> segmentColors;
  final Color lineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(canvas, size);
    if (centers.length < 2) return;

    for (var i = 0; i < centers.length - 1; i++) {
      final from = centers[i];
      final to = centers[i + 1];
      final midY = (from.dy + to.dy) / 2;

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);

      // Dark seat under the line for depth, then the coloured line on top.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..color = lineColor,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = segmentColors[i],
      );
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor;
    const spacing = 34.0;
    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.centers != centers ||
      oldDelegate.segmentColors != segmentColors;
}

/// Short daily review: the steps the learner scored lowest on, plus the next
/// unfinished step, so Home always offers a two-minute reason to come back.
///
/// Renders nothing until there is something honest to review.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.items, required this.onOpen});

  final List<ReviewItem> items;
  final void Function(CourseStep step) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: SkillBridgeColors.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: SkillBridgeColors.accent,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    "Today's review",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Text(
                  '${items.length} min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                'A short pass over what you missed — finish these and you are done '
                'for today.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: context.appColors.textMuted,
                ),
              ),
            ),
            for (final item in items)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onOpen(item.step),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        item.step.kind.icon,
                        size: 17,
                        color: SkillBridgeColors.primaryDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.step.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item.reason,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.appColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: context.appColors.textMuted,
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
