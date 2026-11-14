import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/app/router.dart';
import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/shared/widgets/premium_button.dart';
import 'package:skillbridge_python_lab/features/course/course_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/integrations/lms/lms_models.dart';

import 'achievements_controller.dart';

/// Screen: Progress. Server-verified SkillCoins and achievements, joined with
/// the locally tracked course path so the learner sees one picture: what the
/// LMS confirmed, and where they are on the Python track.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final AppDependencies _deps;
  late final AchievementsController _controller;
  late final CourseController _course;

  @override
  void initState() {
    super.initState();
    _deps = context.read<AppDependencies>();
    _controller = AchievementsController(_deps)..load();
    _course = CourseController(
      course: pythonKickstartCourse,
      repository: _deps.courseProgress,
      learnerRef: _deps.learnerRef,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _openNextStep(CourseStep step) async {
    await Navigator.of(context).pushNamed(
      AppRouter.courseLesson,
      arguments: {'step': step, 'onCompleted': (int score) => _course.load()},
    );
    if (mounted) _course.load();
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 1),
            Text(
              'SkillCoins, achievements and your course',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: SkillBridgeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _course]),
        builder: (context, _) {
          if (_controller.isLoading || _course.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_controller.load(), _course.load()]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _HeroCard(
                  coins: _controller.progress.totalPoints,
                  completedChallenges: _controller.progress.completedChallenges,
                  totalChallenges: _controller.progress.totalChallenges,
                  course: _course,
                ),
                if (_controller.error != null) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(message: _controller.error!),
                ],
                const SizedBox(height: 20),
                _CourseTrack(course: _course, onOpenStep: _openNextStep),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Achievements',
                  caption: 'Confirmed by the SkillBridge Academy LMS',
                  icon: Icons.emoji_events_outlined,
                ),
                const SizedBox(height: 12),
                if (_controller.achievements.isEmpty)
                  const _EmptyState(
                    icon: Icons.emoji_events_outlined,
                    message:
                        'Complete a challenge to earn your first achievement.',
                  )
                else
                  _AchievementGrid(achievements: _controller.achievements),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Recent submissions',
                  caption: 'Synced with the LMS',
                  icon: Icons.schedule_outlined,
                ),
                const SizedBox(height: 8),
                if (_controller.recentSubmissions.isEmpty)
                  const _EmptyState(
                    icon: Icons.upload_file_outlined,
                    message: 'No submissions yet.',
                  )
                else
                  for (final summary in _controller.recentSubmissions)
                    _SubmissionTile(summary: summary),
                const SizedBox(height: 20),
                const _CoinNote(),
              ],
            ),
          );
        },
      ),
    );
    return screen;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.coins,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.course,
  });

  final int coins;
  final int completedChallenges;
  final int totalChallenges;
  final CourseController course;

  @override
  Widget build(BuildContext context) {
    final ratio = totalChallenges == 0
        ? 0.0
        : completedChallenges / totalChallenges;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13395F), Color(0xFF101B2C), Color(0xFF0F1620)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SkillBridgeColors.primary.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: SkillBridgeColors.primary.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: SkillBridgeColors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'verified SkillCoins',
                          style: TextStyle(
                            color: SkillBridgeColors.accent.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          SkillBridgeColors.goldGradient.createShader(bounds),
                      child: Text(
                        '$coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Confirmed by your LMS after it grades a submission.',
                      style: TextStyle(
                        color: SkillBridgeColors.textMuted.withValues(
                          alpha: 0.9,
                        ),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressRing(progress: course.progress, label: 'course'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                icon: Icons.route_outlined,
                label: 'Course steps',
                value: '${course.completedCount}/${course.totalSteps}',
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.local_fire_department_outlined,
                label: 'Streak',
                value: '${course.streak}',
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.task_alt,
                label: 'Challenges',
                value: '$completedChallenges/$totalChallenges',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ThinBar(value: ratio),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedChallenges of $totalChallenges challenges verified',
                style: const TextStyle(
                  fontSize: 11,
                  color: SkillBridgeColors.textMuted,
                ),
              ),
              Text(
                '${course.xpEarned} XP earned',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SkillBridgeColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    const size = 92.0;
    final percent = (progress.clamp(0, 1) * 100).round();

    return SizedBox(
      width: size,
      height: size + 14,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(size),
                  painter: _RingPainter(progress: progress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SkillBridgeColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'complete',
                      style: TextStyle(
                        fontSize: 10,
                        color: SkillBridgeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: SkillBridgeColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final track = Rect.fromCircle(
      center: rect.center,
      radius: (size.shortestSide - stroke) / 2,
    );

    canvas.drawArc(
      track,
      0,
      6.283185307179586,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = SkillBridgeColors.surfaceHigh,
    );

    canvas.drawArc(
      track,
      -1.5707963267948966,
      6.283185307179586 * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = const SweepGradient(
          startAngle: -1.5707963267948966,
          endAngle: 4.71238898038469,
          colors: [SkillBridgeColors.primary, SkillBridgeColors.accent],
        ).createShader(track),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: SkillBridgeColors.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: SkillBridgeColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SkillBridgeColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinBar extends StatelessWidget {
  const _ThinBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: 7,
          backgroundColor: SkillBridgeColors.surfaceHigh,
          valueColor: const AlwaysStoppedAnimation(SkillBridgeColors.primary),
        ),
      ),
    );
  }
}

class _CourseTrack extends StatelessWidget {
  const _CourseTrack({required this.course, required this.onOpenStep});

  final CourseController course;
  final ValueChanged<CourseStep> onOpenStep;

  @override
  Widget build(BuildContext context) {
    final steps = course.course.steps;
    final next = course.nextStep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.signpost_outlined,
                size: 16,
                color: SkillBridgeColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course.course.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SkillBridgeColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${course.completedCount}/${steps.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SkillBridgeColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 16,
                      height: 3,
                      color: course.isCompleted(steps[i - 1].id)
                          ? SkillBridgeColors.accent
                          : SkillBridgeColors.surfaceHigh,
                    ),
                  _StepPip(
                    index: i,
                    step: steps[i],
                    status: course.statusFor(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (next == null)
            const Row(
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 16,
                  color: SkillBridgeColors.accent,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Course complete. Everything stays open for review.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: SkillBridgeColors.textPrimary,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UP NEXT',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: SkillBridgeColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: SkillBridgeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: PremiumButton(
                    height: 44,
                    onPressed: () => onOpenStep(next),
                    icon: Icons.play_arrow_rounded,
                    label: 'CONTINUE',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepPip extends StatelessWidget {
  const _StepPip({
    required this.index,
    required this.step,
    required this.status,
  });

  final int index;
  final CourseStep step;
  final CourseStepStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = status == CourseStepStatus.completed;
    final current = status == CourseStepStatus.current;
    final locked = status == CourseStepStatus.locked;

    final Color background;
    final Color border;
    if (completed) {
      background = SkillBridgeColors.accent;
      border = SkillBridgeColors.accent;
    } else if (current) {
      background = SkillBridgeColors.primary;
      border = SkillBridgeColors.primary;
    } else if (locked) {
      background = SkillBridgeColors.surfaceHigh;
      border = SkillBridgeColors.outline;
    } else {
      background = SkillBridgeColors.primary.withValues(alpha: 0.18);
      border = SkillBridgeColors.primary;
    }

    final child = completed
        ? const Icon(
            Icons.check_rounded,
            size: 14,
            color: SkillBridgeColors.onPrimary,
          )
        : locked
        ? const Icon(
            Icons.lock_rounded,
            size: 12,
            color: SkillBridgeColors.textMuted,
          )
        : Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: current
                  ? SkillBridgeColors.onPrimary
                  : SkillBridgeColors.primary,
            ),
          );

    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: current ? 2 : 1),
        boxShadow: current
            ? [
                BoxShadow(
                  color: SkillBridgeColors.primary.withValues(alpha: 0.45),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: SkillBridgeColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SkillBridgeColors.textPrimary,
            ),
          ),
        ),
        Text(
          caption,
          style: const TextStyle(
            fontSize: 10.5,
            color: SkillBridgeColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.achievements});

  final List<Achievement> achievements;

  static const _icons = <IconData>[
    Icons.emoji_events_outlined,
    Icons.military_tech_outlined,
    Icons.workspace_premium_outlined,
    Icons.local_fire_department_outlined,
    Icons.auto_awesome_outlined,
    Icons.stars_rounded,
    Icons.insights_rounded,
    Icons.verified_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final icon = _icons[index % _icons.length];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SkillBridgeColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SkillBridgeColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: SkillBridgeColors.goldGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: const Color(0xFF3A2B00)),
                  ),
                  const SizedBox(width: 8),
                  if (achievement.points > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SkillBridgeColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '+${achievement.points}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: SkillBridgeColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                achievement.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: SkillBridgeColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: SkillBridgeColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.summary});

  final SubmissionSummary summary;

  (IconData, Color, String) get _status {
    switch (summary.state) {
      case 'synced':
      case 'synced_to_lms':
        return (Icons.cloud_done_outlined, SkillBridgeColors.success, 'synced');
      case 'pending':
      case 'queued':
        return (
          Icons.cloud_upload_outlined,
          SkillBridgeColors.accent,
          'queued',
        );
      case 'failed':
        return (Icons.sync_problem_outlined, SkillBridgeColors.error, 'failed');
      default:
        return (
          Icons.cloud_outlined,
          SkillBridgeColors.textMuted,
          summary.state.replaceAll('_', ' '),
        );
    }
  }

  String get _title {
    final id = summary.exerciseId.replaceAll('-', ' ').trim();
    if (id.isEmpty) return summary.exerciseId;
    return id[0].toUpperCase() + id.substring(1);
  }

  String get _when {
    final delta = DateTime.now().difference(summary.createdAt);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
    return '${summary.createdAt.year}-${summary.createdAt.month.toString().padLeft(2, '0')}-${summary.createdAt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _status;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SkillBridgeColors.textPrimary,
                  ),
                ),
                Text(
                  _when,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SkillBridgeColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2B16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A6728)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFFFD180)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFE6B0)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: SkillBridgeColors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: SkillBridgeColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinNote extends StatelessWidget {
  const _CoinNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SkillBridgeColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SkillBridgeColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color: SkillBridgeColors.accent,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SkillCoins are confirmed by the SkillBridge Academy LMS after it grades '
              'your submission. This app never awards coins on its own.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: SkillBridgeColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
