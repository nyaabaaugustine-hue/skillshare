import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_controller.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';

import '../../app/theme.dart';
import 'certificate_card.dart';
import 'learning_map.dart';
import 'learning_path.dart';

class LmsHubScreen extends StatefulWidget {
  const LmsHubScreen({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  State<LmsHubScreen> createState() => _LmsHubScreenState();
}

class _LmsHubScreenState extends State<LmsHubScreen> {
  late int _section;

  static const _sections = <({String label, IconData icon})>[
    (label: 'Courses', icon: Icons.auto_stories_rounded),
    (label: 'News', icon: Icons.campaign_rounded),
    (label: 'Resources', icon: Icons.download_rounded),
    (label: 'Certificate', icon: Icons.workspace_premium_rounded),
    (label: 'About', icon: Icons.info_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, _sections.length - 1).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillBridge Academy',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Your learning hub',
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About SkillBridge Academy',
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _SectionSelector(
            selected: _section,
            onSelected: (index) => setState(() => _section = index),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _buildSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    return switch (_section) {
      0 => const _CoursesSection(key: ValueKey('courses')),
      1 => const _NewsSection(key: ValueKey('news')),
      2 => const _ResourcesSection(key: ValueKey('resources')),
      3 => const _CertificateSection(key: ValueKey('certificate')),
      _ => const _AboutSection(key: ValueKey('about')),
    };
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About SkillBridge Academy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'SkillBridge Academy makes technology education more accessible for every learner.',
              style: TextStyle(color: context.appColors.textMuted, height: 1.5),
            ),
            SizedBox(height: 14),
            Text(
              'Learn • Build • Grow',
              style: TextStyle(
                color: SkillBridgeColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, IconData icon})>[
    (label: 'Courses', icon: Icons.auto_stories_rounded),
    (label: 'News', icon: Icons.campaign_rounded),
    (label: 'Resources', icon: Icons.download_rounded),
    (label: 'Certificate', icon: Icons.workspace_premium_rounded),
    (label: 'About', icon: Icons.info_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _NavPill(
            icon: item.icon,
            label: item.label,
            active: selected == index,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

/// A softly glowing pill for the LMS section bar. The active pill carries the
/// brand gradient; the rest stay quiet so the bar never competes with the page.
class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            gradient: active ? SkillBridgeColors.brandGradient : null,
            color: active ? null : context.appColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : context.appColors.outline,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: SkillBridgeColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? Colors.white : context.appColors.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : context.appColors.textPrimary,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoursesSection extends StatelessWidget {
  const _CoursesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const _LmsHero(),
        const SizedBox(height: 18),
        Text(
          'Continue learning',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _CourseCard(onTap: () => _showCourse(context)),
        const SizedBox(height: 18),
        const LearningPathView(),
      ],
    );
  }

  void _showCourse(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Course player connected — choose a lesson to continue.'),
      ),
    );
  }
}

class _CourseJourneyMap extends StatefulWidget {
  const _CourseJourneyMap();

  @override
  State<_CourseJourneyMap> createState() => _CourseJourneyMapState();
}

class _CourseJourneyMapState extends State<_CourseJourneyMap> {
  /// How many places on the map the learner has already finished. 0 means the
  /// learner is standing on the first place.
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  /// Asks the LMS where this learner actually is right now, so the map can
  /// mark every place before it as done and the matching place as "you are
  /// here". If the LMS cannot be reached, the map still renders from the first
  /// place rather than failing.
  Future<void> _loadPosition() async {
    try {
      final deps = context.read<AppDependencies>();
      final progress = await deps.lmsClient.fetchProgress();
      if (!mounted) return;
      setState(() {
        _completed = progress.completedChallenges.clamp(
          0,
          learningPlaces.length,
        );
      });
    } catch (_) {
      // Keep the default starting position when progress is unavailable.
    }
  }

  _LessonState _stateFor(int index) {
    if (index < _completed) return _LessonState.completed;
    if (index == _completed) return _LessonState.open;
    return _LessonState.locked;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const _MapStartNode(),
      const _MapConnector(label: 'Lesson path'),
    ];
    for (var i = 0; i < learningPlaces.length; i++) {
      final lesson = learningPlaces[i];
      if (i == _completed && i < learningPlaces.length) {
        children.add(
          _YouAreHere(
            place: lesson.title,
            step: i + 1,
            total: learningPlaces.length,
          ),
        );
      }
      children.add(
        _LessonTile(
          number: lesson.number,
          title: lesson.title,
          duration: lesson.duration,
          publicId: lesson.publicId,
          state: _stateFor(i),
        ),
      );
      if (lesson != learningPlaces.last) {
        children.add(
          const _MapConnector(label: 'Complete this step to continue'),
        );
      }
    }
    children.add(const _MapFinishNode());
    return Column(children: children);
  }
}

/// The "you are here" marker drawn on the learning map. It names the place the
/// learner is standing on and shows a dot row of every place so the learner can
/// see how far along the map they are right now.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({
    required this.place,
    required this.step,
    required this.total,
  });

  final String place;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    const marker = Color(0xFF53D8A0);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: marker.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: marker, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: marker,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'YOU ARE HERE',
                style: TextStyle(
                  color: marker,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Container(
                    width: i == step - 1 ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i < step - 1
                          ? SkillBridgeColors.success
                          : i == step - 1
                          ? marker
                          : context.appColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Place $step of $total on your map',
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStartNode extends StatelessWidget {
  const _MapStartNode();

  @override
  Widget build(BuildContext context) => const _MapMilestone(
    icon: Icons.flag_rounded,
    label: 'START HERE',
    detail: 'Begin Unit 1: Python Kickstart',
    color: SkillBridgeColors.accent,
  );
}

class _MapFinishNode extends StatelessWidget {
  const _MapFinishNode();

  @override
  Widget build(BuildContext context) => const _MapMilestone(
    icon: Icons.emoji_events_rounded,
    label: 'UNIT FINISH',
    detail: 'Complete all videos and practicals',
    color: Color(0xFFFFC857),
  );
}

class _MapMilestone extends StatelessWidget {
  const _MapMilestone({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapConnector extends StatelessWidget {
  const _MapConnector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: Row(
      children: [
        const SizedBox(width: 24),
        Container(width: 3, height: 38, color: context.appColors.surfaceHigh),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.appColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LmsHero extends StatefulWidget {
  const _LmsHero();

  @override
  State<_LmsHero> createState() => _LmsHeroState();
}

class _LmsHeroState extends State<_LmsHero> {
  late final CourseController _course;

  @override
  void initState() {
    super.initState();
    final deps = context.read<AppDependencies>();
    _course = CourseController(
      course: pythonKickstartCourse,
      repository: deps.courseProgress,
      learnerRef: deps.learnerRef,
    );
    _course.load();
  }

  @override
  void dispose() {
    _course.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _course,
      builder: (context, _) => _HeroCard(
        progress: _course.progress,
        completed: _course.completedCount,
        total: _course.totalSteps,
        streak: _course.streak,
        xp: _course.xpEarned,
      ),
    );
  }
}

/// The LMS welcome banner. It reports the learner's real course position (not
/// a hard-coded sample) and keeps quick facts at the bottom so the hub opens
/// with something useful rather than pure decoration.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.progress,
    required this.completed,
    required this.total,
    required this.streak,
    required this.xp,
  });

  final double progress;
  final int completed;
  final int total;
  final int streak;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: SkillBridgeColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF04101F).withValues(alpha: 0.55),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
          ),
          Positioned(
            right: -34,
            bottom: -46,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.035),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Image.asset(
                        'assets/icon/app_mark.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME BACK',
                            style: TextStyle(
                              color: Color(0xFF9CCBFF),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              fontSize: 10.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Python Kickstart',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: SkillBridgeColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: SkillBridgeColors.accent.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: const Text(
                        'BEGINNER',
                        style: TextStyle(
                          color: SkillBridgeColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'A friendly path from your first line of code to real '
                  'confidence - video, practice and feedback in one place.',
                  style: TextStyle(
                    color: Color(0xFFC3DCF5),
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '$pct% complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$completed of $total lessons',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD166)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroStat(
                      icon: Icons.local_fire_department_rounded,
                      label: streak > 0
                          ? '$streak day streak'
                          : 'Start a streak',
                    ),
                    const SizedBox(width: 8),
                    _HeroStat(icon: Icons.bolt_rounded, label: '$xp XP earned'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SkillBridgeColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/course_previews/python_quick_start.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 5,
                      bottom: 5,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IN PROGRESS',
                        style: TextStyle(
                          color: SkillBridgeColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Python Quick Start',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Beginner - 1h 47m - video + practice',
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: 0.33,
                          minHeight: 6,
                          backgroundColor: context.appColors.surfaceHigh,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.appColors.outline),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.appColors.textMuted,
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

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.number,
    required this.title,
    required this.duration,
    required this.publicId,
    required this.state,
  });

  final String number;
  final String title;
  final String duration;
  final String publicId;
  final _LessonState state;

  @override
  Widget build(BuildContext context) {
    final complete = state == _LessonState.completed;
    final locked = state == _LessonState.locked;
    final accent = complete
        ? SkillBridgeColors.success
        : locked
        ? context.appColors.textMuted
        : SkillBridgeColors.primary;

    void open() {
      if (locked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete the previous lesson to unlock this video.'),
          ),
        );
        return;
      }
      Navigator.of(context).pushNamed(
        '/lms-video',
        arguments: {'title': title, 'subtitle': duration, 'publicId': publicId},
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: locked
            ? context.appColors.surface.withValues(alpha: 0.55)
            : context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: locked
              ? context.appColors.outline
              : accent.withValues(alpha: 0.30),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          locked
                              ? Colors.black.withValues(alpha: 0.45)
                              : Colors.transparent,
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          previewForPlace(number),
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -2,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: locked
                              ? context.appColors.surfaceHigh
                              : context.appColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          number,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete
                            ? 'COMPLETED'
                            : locked
                            ? 'LESSON $number - LOCKED'
                            : 'LESSON $number',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: locked
                              ? context.appColors.textMuted
                              : context.appColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: context.appColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$duration - ${complete
                                ? 'Replay video'
                                : locked
                                ? 'Finish the lesson before'
                                : 'Video + practical'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: locked
                        ? context.appColors.surfaceHigh
                        : accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: locked
                          ? context.appColors.outline
                          : accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    complete
                        ? Icons.replay_rounded
                        : locked
                        ? Icons.lock_outline_rounded
                        : Icons.play_arrow_rounded,
                    color: locked ? context.appColors.textMuted : accent,
                    size: 19,
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

enum _LessonState { completed, open, locked }

class _NewsSection extends StatelessWidget {
  const _NewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: const [
        _NewsCard(
          title: 'Welcome to the SkillBridge Academy',
          tag: 'GENERAL',
          date: '20 Sep 2026',
          text: 'Access Python lessons anytime, track your progress, and keep building your future.',
        ),
        _NewsCard(
          title: 'New cohort enrollment open',
          tag: 'ENROLLMENT',
          date: '18 Sep 2026',
          text: 'Seats are limited. Scholarships are available for eligible learners.',
        ),
        _NewsCard(
          title: 'Weekly live Q&A sessions',
          tag: 'SCHEDULE',
          date: '15 Sep 2026',
          text: 'Bring your questions every Saturday at 10:00 AM GMT.',
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.title,
    required this.tag,
    required this.date,
    required this.text,
  });

  final String title;
  final String tag;
  final String date;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SkillBridgeColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: SkillBridgeColors.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              text,
              style: TextStyle(
                color: context.appColors.textMuted,
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  const _ResourcesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const resources = [
      (
        'Python Basics Cheat Sheet',
        'PDF',
        'Syntax, data types and common operations',
      ),
      (
        'Course Slides - Demystifying Python',
        'PDF',
        'Slides from the Python sessions',
      ),
      ('Practice Exercises', 'ZIP', 'Hands-on exercises with solutions'),
      (
        'Career Guide - Tech in Ghana',
        'PDF',
        'CV tips, interviews and opportunities',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: SkillBridgeColors.heroGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.folder_open_rounded,
                color: SkillBridgeColors.accent,
                size: 30,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download and keep learning',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Every handout works offline once saved.',
                      style: TextStyle(
                        color: Color(0xFFC3DCF5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final item in resources)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.appColors.outline),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.$1} is ready to download.')),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: SkillBridgeColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: SkillBridgeColors.primary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: SkillBridgeColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Text(
                            item.$2,
                            style: TextStyle(
                              color: context.appColors.textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: SkillBridgeColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CertificateSection extends StatefulWidget {
  const _CertificateSection({super.key});

  @override
  State<_CertificateSection> createState() => _CertificateSectionState();
}

class _CertificateSectionState extends State<_CertificateSection> {
  late final CourseController _course;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    final deps = context.read<AppDependencies>();
    _course = CourseController(
      course: pythonKickstartCourse,
      repository: deps.courseProgress,
      learnerRef: deps.learnerRef,
    );
    _course.load();
  }

  @override
  void dispose() {
    _course.dispose();
    super.dispose();
  }

  CertificateModel _modelFor(String learnerName) => CertificateModel(
    learnerName: learnerName,
    courseTitle: pythonKickstartCourse.title,
    completedOn: _completedOn(),
    xpEarned: _course.xpEarned,
    stepCount: _course.totalSteps,
  );

  /// The date the learner actually finished the course.
  ///
  /// Built from the earliest attempt recorded for each step, then the latest of
  /// those: that is the moment the final step was first completed. Retrying an
  /// old step months later therefore does not move the certificate date, and a
  /// certificate printed today does not claim to have been earned today.
  DateTime _completedOn() {
    final deps = context.read<AppDependencies>();
    final firstByStep = <String, DateTime>{};
    for (final record in deps.courseProgress.history(deps.learnerRef)) {
      final seen = firstByStep[record.stepId];
      if (seen == null || record.at.isBefore(seen)) {
        firstByStep[record.stepId] = record.at;
      }
    }
    if (firstByStep.isEmpty) return DateTime.now();
    return firstByStep.values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String _learnerName() {
    final session = context.read<AuthController?>()?.session;
    return session?.displayName ?? 'Learner';
  }

  Future<void> _download(String learnerName) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await capturePng(_boundaryKey);
      if (!mounted) return;
      if (bytes == null) {
        _toast('Could not render the certificate. Try again.');
        return;
      }
      if (kIsWeb) {
        _toast('Right-click the certificate and choose “Save image as…”.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final safe = learnerName
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final file = File(
        p.join(
          dir.path,
          'SkillBridge_Certificate_${safe.isEmpty ? 'Learner' : safe}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _toast('Certificate saved to ${file.path}');
    } catch (_) {
      if (mounted) _toast('Could not save the certificate. Try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _course,
      builder: (context, _) {
        final learnerName = _learnerName();
        final model = _modelFor(learnerName);
        final progress = _course.progress;
        final complete = _course.totalSteps > 0 && progress >= 1.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _StatusBanner(
              complete: complete,
              completedCount: _course.completedCount,
              totalSteps: _course.totalSteps,
              progress: progress,
            ),
            const SizedBox(height: 18),
            // Fit the print-size certificate to the phone so it is readable
            // and never overflows the page horizontally.
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.clamp(280.0, 760.0);
                return Center(
                  child: _LockedPreview(
                    locked: !complete,
                    progress: progress,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: CertificateCard(model: model, width: width),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (complete)
              FilledButton.icon(
                onPressed: _downloading ? null : () => _download(learnerName),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _downloading ? 'Preparing…' : 'Download certificate',
                ),
              )
            else
              _LockedAction(
                completedCount: _course.completedCount,
                totalSteps: _course.totalSteps,
              ),
          ],
        );
      },
    );
  }
}

/// Heading clause above the certificate: tells the learner whether they have
/// earned it or how far they still have to go.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.complete,
    required this.completedCount,
    required this.totalSteps,
    required this.progress,
  });

  final bool complete;
  final int completedCount;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = complete
        ? SkillBridgeColors.success
        : SkillBridgeColors.accent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // The card paints theme text over this wash, so the first stop has to
          // follow the theme too; a fixed near-black stop would swallow the
          // dark title text in light mode.
          colors: [
            isDark ? const Color(0xFF16202F) : context.appColors.surfaceHigh,
            context.appColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  complete
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  complete
                      ? 'Your certificate is ready'
                      : 'Your certificate is waiting',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            complete
                ? 'You finished every lesson in ${pythonKickstartCourse.title}. '
                      'Download your premium certificate below.'
                : 'Finish all $totalSteps lessons to unlock your certificate. '
                      'A sample is shown below.',
            style: TextStyle(
              color: context.appColors.textMuted,
              height: 1.5,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalSteps == 0 ? 0 : progress,
                    minHeight: 9,
                    backgroundColor: context.appColors.surfaceHigh,
                    color: complete
                        ? SkillBridgeColors.success
                        : SkillBridgeColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '$completedCount of $totalSteps lessons complete',
            style: TextStyle(
              color: context.appColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps the certificate preview. When [locked], the artwork is shown but
/// dimmed behind a frosted lock card so it reads as an unearned sample.
class _LockedPreview extends StatelessWidget {
  const _LockedPreview({
    required this.locked,
    required this.progress,
    required this.child,
  });

  final bool locked;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: SkillBridgeColors.accent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                const Text(
                  'SAMPLE PREVIEW',
                  style: TextStyle(
                    color: SkillBridgeColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  locked
                      ? Colors.black.withValues(alpha: 0.34)
                      : Colors.transparent,
                  BlendMode.srcATop,
                ),
                child: child,
              ),
              if (locked)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.appColors.background.withValues(alpha: 0.42),
                  ),
                ),
              if (locked)
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceHigh.withValues(
                      alpha: 0.94,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SkillBridgeColors.accent.withValues(
                            alpha: 0.14,
                          ),
                          border: Border.all(
                            color: SkillBridgeColors.accent.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: SkillBridgeColors.accent,
                          size: 23,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Locked',
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pct% complete',
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LockedAction extends StatelessWidget {
  const _LockedAction({required this.completedCount, required this.totalSteps});

  final int completedCount;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final remaining = totalSteps - completedCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SkillBridgeColors.accent.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SkillBridgeColors.accent.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: SkillBridgeColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Certificate unlocks at 100%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  remaining <= 1
                      ? 'Just $remaining lesson to go - finish it to unlock.'
                      : '$remaining lessons to go - keep going!',
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12.5,
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

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF17315A), Color(0xFF0F5FC0)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.public_rounded, color: Colors.white, size: 42),
              SizedBox(height: 18),
              Text(
                'Learn • Build • Grow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'SkillBridge Academy makes technology education more accessible for every learner.',
                style: TextStyle(color: Color(0xFFD8E9FF), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            leading: Icon(
              Icons.favorite_outline_rounded,
              color: SkillBridgeColors.accent,
            ),
            title: Text('Built for opportunity'),
            subtitle: Text(
              'Learn practical skills at your own pace, on any device.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(
              Icons.groups_rounded,
              color: SkillBridgeColors.accent,
            ),
            title: Text('A community that supports you'),
            subtitle: Text(
              'Stay connected to mentors, announcements and new cohorts.',
            ),
          ),
        ),
      ],
    );
  }
}
