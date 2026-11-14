import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/guardian_report.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/shared/widgets/entrance.dart';
import 'package:skillbridge_python_lab/shared/widgets/icon_badge.dart';

const Color _amber = Color(0xFFF2A81D);

Color _bandColor(ResultBand band) => switch (band) {
  ResultBand.mastered => SkillBridgeColors.success,
  ResultBand.developing => _amber,
  ResultBand.needsSupport => SkillBridgeColors.error,
};

/// Home for a signed-in Parent / Guardian.
///
/// Deliberately narrow and read-only. A guardian sees exactly three things:
///   1. scores and results,
///   2. weak points to note,
///   3. retries.
/// No lesson content, code, news, certificates or settings are exposed here.
class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  late final AppDependencies _deps;
  late final CourseController _course;

  @override
  void initState() {
    super.initState();
    _deps = context.read<AppDependencies>();
    _course = CourseController(
      course: pythonKickstartCourse,
      repository: _deps.courseProgress,
      learnerRef: _deps.learnerRef,
    )..load();
  }

  @override
  void dispose() {
    _course.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final auth = context.read<AuthController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  /// Demo accounts only: writes a few sample attempts so the report has
  /// something to show without first playing through lessons. Shown behind an
  /// explicit button and labelled as sample data.
  Future<void> _loadSample() async {
    final steps = pythonKickstartCourse.steps;
    const plan = <List<int>>[
      <int>[100],
      <int>[60, 80, 100],
      <int>[70, 85],
      <int>[55],
    ];
    for (var i = 0; i < plan.length && i < steps.length; i++) {
      for (final score in plan[i]) {
        await _deps.courseProgress.markCompleted(
          learner: _deps.learnerRef,
          stepId: steps[i].id,
          score: score,
        );
      }
    }
    await _deps.courseProgress.recordActivity(_deps.learnerRef);
    await _course.load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final guardianName = session?.displayName ?? 'Guardian';
    final childName = session?.linkedStudentName;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _course.load,
          child: ListenableBuilder(
            listenable: _course,
            builder: (context, _) {
              final report = GuardianReport.build(
                course: pythonKickstartCourse,
                history: _course.history,
              );
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _Header(
                    guardianName: guardianName,
                    childName: childName,
                    onSignOut: _confirmSignOut,
                  ),
                  if (report.isEmpty)
                    _EmptyState(
                      childName: childName,
                      showSample: kDebugMode,
                      onLoadSample: _loadSample,
                    )
                  else ...[
                    Entrance(index: 1, child: _SummaryRow(report: report)),
                    const _SectionTitle(
                      icon: Icons.assessment_rounded,
                      colors: IconBadge.blue,
                      title: 'Scores & results',
                      subtitle: 'Latest score for each lesson attempted',
                    ),
                    for (final r in report.results) _ResultTile(result: r),
                    const _SectionTitle(
                      icon: Icons.flag_rounded,
                      colors: IconBadge.coral,
                      title: 'Weak points to note',
                      subtitle: 'Lessons not yet at 90% — worth a second look',
                    ),
                    if (report.weakPoints.isEmpty)
                      const _AllClear(
                        text:
                            'No weak points right now. Every lesson '
                            'attempted is at 90% or above.',
                      )
                    else
                      for (final r in report.weakPoints)
                        _WeakPointTile(result: r),
                    const _SectionTitle(
                      icon: Icons.replay_rounded,
                      colors: IconBadge.purple,
                      title: 'Retries',
                      subtitle: 'Lessons that took more than one try',
                    ),
                    if (report.retried.isEmpty)
                      const _AllClear(
                        text:
                            'No retries yet — every lesson attempted was '
                            'completed on the first try.',
                      )
                    else
                      for (final r in report.retried) _RetryTile(result: r),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
                      child: Text(
                        'This is a read-only report. Pull down to refresh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SkillBridgeColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.guardianName,
    required this.childName,
    required this.onSignOut,
  });

  final String guardianName;
  final String? childName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 12, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B2547), Color(0xFF0F5FC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.family_restroom_rounded,
            colors: IconBadge.gold,
            iconColor: Color(0xFF2A1D00),
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARENT / GUARDIAN · ${guardianName.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBFE0FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  childName == null
                      ? "Your child's report"
                      : "$childName's report",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Scores, weak points and retries',
                  style: TextStyle(color: Color(0xFFD8E9FF), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.report});

  final GuardianReport report;

  @override
  Widget build(BuildContext context) {
    final average = report.averageScore ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          _StatTile(
            icon: Icons.percent_rounded,
            colors: IconBadge.blue,
            value: '$average%',
            label: 'Average score',
          ),
          const SizedBox(width: 10),
          _StatTile(
            icon: Icons.task_alt_rounded,
            colors: IconBadge.green,
            value: '${report.attemptedCount}/${report.totalSteps}',
            label: 'Lessons attempted',
          ),
          const SizedBox(width: 10),
          _StatTile(
            icon: Icons.replay_rounded,
            colors: IconBadge.purple,
            value: '${report.totalRetries}',
            label: 'Retries',
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.colors,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final List<Color> colors;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: SkillBridgeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SkillBridgeColors.outline),
        ),
        child: Column(
          children: [
            IconBadge(icon: icon, colors: colors, size: 38, glow: false),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: SkillBridgeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
    child: Row(
      children: [
        IconBadge(icon: icon, colors: colors, size: 36, glow: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SkillBridgeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final StepResult result;

  @override
  Widget build(BuildContext context) {
    final color = _bandColor(result.band);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            '${result.latestScore}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          result.step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${result.step.kind.label} · '
          '${result.attempts} ${result.attempts == 1 ? 'attempt' : 'attempts'}',
          style: const TextStyle(
            fontSize: 12.5,
            color: SkillBridgeColors.textMuted,
          ),
        ),
        trailing: _Chip(label: result.band.label, color: color),
      ),
    );
  }
}

class _WeakPointTile extends StatelessWidget {
  const _WeakPointTile({required this.result});

  final StepResult result;

  @override
  Widget build(BuildContext context) {
    final color = _bandColor(result.band);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.step.title} · ${result.latestScore}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.advice,
                  style: const TextStyle(
                    color: SkillBridgeColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
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

class _RetryTile extends StatelessWidget {
  const _RetryTile({required this.result});

  final StepResult result;

  @override
  Widget build(BuildContext context) {
    final trail = result.scores.map((s) => '$s%').join('  →  ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(
              icon: Icons.replay_rounded,
              colors: IconBadge.purple,
              size: 38,
              glow: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.step.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.retries} ${result.retries == 1 ? 'retry' : 'retries'}'
                    ' · ${result.attempts} tries in total',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SkillBridgeColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trail,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (result.improved)
              const Icon(
                Icons.trending_up_rounded,
                color: SkillBridgeColors.success,
              )
            else if (result.latestScore < result.firstScore)
              const Icon(
                Icons.trending_down_rounded,
                color: SkillBridgeColors.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AllClear extends StatelessWidget {
  const _AllClear({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SkillBridgeColors.success.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: SkillBridgeColors.success.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: SkillBridgeColors.success,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.childName,
    required this.showSample,
    required this.onLoadSample,
  });

  final String? childName;
  final bool showSample;
  final Future<void> Function() onLoadSample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
      child: Column(
        children: [
          const IconBadge(
            icon: Icons.hourglass_empty_rounded,
            colors: IconBadge.teal,
            size: 72,
          ),
          const SizedBox(height: 22),
          const Text(
            'No results yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${childName ?? 'Your child'} has not finished a lesson yet. '
            'Scores, weak points and retries will appear here as soon as '
            'they do.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SkillBridgeColors.textMuted,
              height: 1.45,
            ),
          ),
          if (showSample) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onLoadSample,
              icon: const Icon(Icons.science_rounded, size: 20),
              label: const Text('Load sample results (demo)'),
            ),
          ],
        ],
      ),
    );
  }
}
