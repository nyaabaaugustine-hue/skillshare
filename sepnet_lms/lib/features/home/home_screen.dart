import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/integrations/lms/lms_models.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/shared/widgets/premium_button.dart';
import 'package:skillbridge_python_lab/features/auth/family_link.dart';
import 'package:skillbridge_python_lab/features/course/course_controller.dart';
import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/course_path_screen.dart';
import 'package:skillbridge_python_lab/features/course/guardian_report.dart';
import 'package:skillbridge_python_lab/features/course/guardian_report_mailer.dart';
import 'package:skillbridge_python_lab/features/auth/auth_controller.dart';
import 'package:skillbridge_python_lab/features/leaderboard/leaderboard_screen.dart';
import 'package:skillbridge_python_lab/features/leaderboard/leaderboard_sync.dart';
import 'package:skillbridge_python_lab/features/lms/learning_map.dart';
import 'package:skillbridge_python_lab/features/lms/lms_hub_screen.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';
import 'package:skillbridge_python_lab/shared/widgets/code_buddy.dart';
import 'package:skillbridge_python_lab/shared/widgets/entrance.dart';

import 'connectivity_controller.dart';
import 'home_controller.dart';
import 'practice_map.dart';

/// Screen A: Home. Shows branding, progress, recent exercises, drafts and the
/// pending-submission queue, with a clear connection indicator.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  late final CourseController _course;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final deps = context.read<AppDependencies>();
    _controller = HomeController(deps);
    _controller.load();
    _course = CourseController(
      course: pythonKickstartCourse,
      repository: deps.courseProgress,
      learnerRef: deps.learnerRef,
    );
    _course.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _openExercise(Exercise exercise) async {
    if (exercise.hasLesson) {
      await Navigator.of(context).pushNamed(
        '/lesson',
        arguments: {
          'exercise': exercise,
          'onFinished': () {
            Navigator.of(context)
                .pushReplacementNamed('/editor', arguments: exercise);
          },
        },
      );
    } else {
      await Navigator.of(context).pushNamed('/editor', arguments: exercise);
    }
    if (mounted) await _controller.refreshLocal();
  }

  Future<void> _openDetails(Exercise exercise) async {
    await Navigator.of(context).pushNamed('/exercise', arguments: exercise);
    if (mounted) await _controller.refreshLocal();
  }

  void _openLeaderboard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()));
  }

  /// Emails the Parent / Guardian a progress report after a finished step.
  ///
  /// [GuardianReportMailer] throttles to one email per learner per 20 hours and
  /// does nothing unless a guardian email and a mailer endpoint are configured,
  /// so this is safe to fire after every completion.
  Future<void> _afterStepCompleted(CourseStep step, int score) async {
    final deps = context.read<AppDependencies>();
    final session = context.read<AuthController?>()?.session;

    // Publish the new totals to the shared ranking in the background: the
    // learner moves on immediately, and a slow network never blocks a lesson.
    unawaited(
      LeaderboardSync.push(deps: deps, name: session?.displayName ?? 'Learner'),
    );

    try {
      final link = await FamilyLinkStore().findByLearner(deps.learnerRef);
      final localGuardianEmail = link?.guardianEmail ?? '';
      final guardianEmail = localGuardianEmail.isNotEmpty
          ? localGuardianEmail
          : session?.guardianEmail ?? '';
      if (guardianEmail.isEmpty) return;
      await GuardianReportMailer(config: deps.config).sendReport(
        learnerRef: deps.learnerRef,
        studentName: link?.studentName ?? session?.name ?? 'Learner',
        guardianName: link?.guardianName ?? 'Parent / Guardian',
        guardianEmail: guardianEmail,
        report: GuardianReport.build(
          course: pythonKickstartCourse,
          history: _course.history,
        ),
      );
    } catch (e) {
      // A progress email must never interrupt a lesson.
      debugPrint('Guardian progress email skipped: $e');
    }
  }

  String? _currentLearnerFirstName() {
    final name = context.read<AuthController?>()?.session?.displayName.trim();
    if (name == null ||
        name.isEmpty ||
        name.contains('@') ||
        name.toLowerCase() == 'learner' ||
        name.toLowerCase() == 'guest learner') {
      return null;
    }
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityController>();
    final learnerName = _currentLearnerFirstName();
    return Scaffold(
      key: _scaffoldKey,
      drawer: ListenableBuilder(
        listenable: _course,
        builder: (context, _) => _LmsDrawer(
          course: _course,
          onDestinationSelected: _openLmsSection,
        ),
      ),
      body: SafeArea(
        child: switch (_selectedTab) {
          0 => CoursePathScreen(
            controller: _course,
            learnerName: learnerName,
            onMenuTap: _openLmsDrawer,
            onStepCompleted: _afterStepCompleted,
            onLeaderboardTap: _openLeaderboard,
          ),
          1 => RefreshIndicator(
            onRefresh: () async {
              await connectivity.syncNow();
              await _controller.load();
            },
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _BrandHeader(onMenuTap: _openLmsDrawer),
                    ),
                    SliverToBoxAdapter(
                      child: Entrance(
                        index: 1,
                        child: _StatusStrip(connectivity: connectivity),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _ContinueCard(
                        exercise: _controller.continueExercise,
                        onTap: _controller.continueExercise == null
                            ? null
                            : () =>
                                  _openExercise(_controller.continueExercise!),
                      ),
                    ),
                    if (_controller.isFromCache &&
                        _controller.exercises.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: _InfoBanner(
                          icon: Icons.cloud_off_rounded,
                          text: 'Showing challenges saved on this device.',
                        ),
                      ),
                    if (_controller.error != null)
                      SliverToBoxAdapter(
                        child: _InfoBanner(
                          icon: Icons.error_outline_rounded,
                          text: _controller.error!,
                          isError: true,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'Practice challenges',
                        subtitle: _controller.isLoading
                            ? 'Loading…'
                            : '${_controller.exercises.length} available',
                      ),
                    ),
                    if (_controller.isLoading && _controller.exercises.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_controller.exercises.isEmpty)
                      const SliverToBoxAdapter(child: _EmptyState())
                    else
                      PracticeMap(
                        exercises: _controller.exercises,
                        hasDraft: (id) => _controller.draftFor(id) != null,
                        onOpen: _openDetails,
                      ),
                    if (_controller.drafts.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: _SectionTitle(title: 'Your drafts'),
                      ),
                      SliverList.builder(
                        itemCount: _controller.drafts.length,
                        itemBuilder: (context, index) {
                          final draft = _controller.drafts[index];
                          final exercise = _controller.exercises
                              .where((e) => e.id == draft.exerciseId)
                              .cast<Exercise?>()
                              .firstWhere((e) => true, orElse: () => null);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/course_previews/python_quick_start.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                exercise?.title ?? draft.exerciseId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Saved ${_relativeTime(draft.updatedAt)}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: exercise == null
                                  ? null
                                  : () => _openExercise(exercise),
                            ),
                          );
                        },
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                );
              },
            ),
          ),
          2 => _ProgressTab(
            home: _controller,
            course: _course,
            learnerName: learnerName,
            onOpenAchievements: () =>
                Navigator.of(context).pushNamed('/progress'),
            onOpenFullMap: () =>
                Navigator.of(context).pushNamed('/lms', arguments: 0),
            onOpenPath: () => setState(() => _selectedTab = 0),
          ),
          3 => const LmsHubScreen(),
          _ => _MoreTab(
            progress: _controller.progress,
            course: _course,
            learnerName: learnerName,
            onOpenPath: () => setState(() => _selectedTab = 0),
            onOpenSettings: () => Navigator.of(context).pushNamed('/settings'),
            onOpenTutor: () => Navigator.of(context).pushNamed('/ai-tutor'),
          ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code_rounded),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _openLmsDrawer() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _openLmsSection(int section) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) Navigator.of(context).pushNamed('/lms', arguments: section);
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

/// Tab 3: Progress. The learner's standing across the LMS and the course, with
/// a shortcut into the full achievements screen and the learning map.
class _ProgressTab extends StatelessWidget {
  const _ProgressTab({
    required this.home,
    required this.course,
    required this.onOpenAchievements,
    required this.onOpenFullMap,
    required this.onOpenPath,
    required this.learnerName,
  });

  final HomeController home;
  final CourseController course;
  final String? learnerName;
  final VoidCallback onOpenAchievements;
  final VoidCallback onOpenFullMap;
  final VoidCallback onOpenPath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([home, course]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _LearnerGreeting(
              progress: home.progress,
              learnerName: learnerName,
            ),
            _ProgressCard(progress: home.progress),
            _CourseProgressCard(course: course, onOpenPath: onOpenPath),
            _CourseMomentumCard(course: course),
            _BadgeRow(progress: home.progress),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: PremiumButton(
                gold: true,
                onPressed: onOpenAchievements,
                icon: Icons.emoji_events_rounded,
                label: 'OPEN ACHIEVEMENTS',
              ),
            ),
            _LearningMapCard(
              progress: home.progress,
              onOpenFullMap: onOpenFullMap,
            ),
          ],
        );
      },
    );
  }
}

/// Course-specific progress summary shown on the Progress tab.
class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.course, required this.onOpenPath});

  final CourseController course;
  final VoidCallback onOpenPath;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.route_rounded,
                  color: SkillBridgeColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  course.course.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${course.completedCount}/${course.totalSteps}',
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: course.progress,
                minHeight: 10,
                backgroundColor: context.appColors.surfaceHigh,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Steps done', value: '${course.completedCount}'),
                _Stat(
                  label: 'XP earned',
                  value: '${course.xpEarned}',
                  gold: true,
                ),
                _Stat(label: 'Streak', value: '${course.streak}'),
              ],
            ),
            const SizedBox(height: 12),
            PremiumButton(
              label: 'CONTINUE ON THE PATH',
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpenPath,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseMomentumCard extends StatelessWidget {
  const _CourseMomentumCard({required this.course});

  final CourseController course;

  @override
  Widget build(BuildContext context) {
    final latest = course.latestAttempt;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ListTile(
        leading: Icon(
          course.isCourseComplete
              ? Icons.workspace_premium_rounded
              : Icons.flag_rounded,
          color: course.isCourseComplete
              ? SkillBridgeColors.accent
              : SkillBridgeColors.primary,
        ),
        title: Text(
          course.isCourseComplete
              ? 'Certificate unlocked'
              : 'Keep your momentum',
        ),
        subtitle: Text(
          latest == null
              ? course.learnerPrompt
              : '${course.learnerPrompt}  •  Last result ${latest.score}%',
        ),
        isThreeLine: latest != null,
      ),
    );
  }
}

/// Tab 5: More. Profile, rewards and the app's secondary destinations.
class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.progress,
    required this.course,
    required this.learnerName,
    required this.onOpenPath,
    required this.onOpenSettings,
    required this.onOpenTutor,
  });

  final LearnerProgress progress;
  final CourseController course;
  final String? learnerName;
  final VoidCallback onOpenPath;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenTutor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: course,
      builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 28),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: SkillBridgeColors.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learnerName ?? 'Your profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage rewards, settings and support',
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _CourseProgressCard(course: course, onOpenPath: onOpenPath),
        const _SectionTitle(title: 'Account'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            subtitle: const Text('Theme, editor and storage'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenSettings,
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_rounded),
            title: const Text('AI Tutor'),
            subtitle: const Text('Ask for help any time'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenTutor,
          ),
        ),
        const _SectionTitle(title: 'Rewards'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _Stat(
                  label: 'SkillCoins',
                  value: '${progress.totalPoints}',
                  gold: true,
                ),
                _Stat(
                  label: 'Completed',
                  value: '${progress.completedChallenges}',
                ),
                _Stat(
                  label: 'Challenges',
                  value: '${progress.totalChallenges}',
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

class _LmsDrawer extends StatelessWidget {
  const _LmsDrawer({
    required this.course,
    required this.onDestinationSelected,
  });

  final CourseController course;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final progressDescription = course.isLoading
        ? 'Loading course progress…'
        : course.error != null
        ? 'Progress unavailable'
        : course.totalSteps == 0
        ? 'No published steps'
        : '${course.completedCount} of ${course.totalSteps} steps complete';
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.86,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5A2B5F), Color(0xFFAF5C46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(topRight: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKILLBRIDGE ACADEMY',
                          style: TextStyle(
                            color: Color(0xFFFFE4D8),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your learning hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.appColors.surfaceHigh),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: SkillBridgeColors.accent,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.course.title,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          progressDescription,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.appColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Text(
                      'LEARNING SPACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.auto_stories_rounded,
                    label: 'My Courses',
                    caption: 'Continue your path',
                    onTap: () => onDestinationSelected(0),
                  ),
                  _DrawerItem(
                    icon: Icons.campaign_rounded,
                    label: 'Announcements',
                    caption: 'What is happening',
                    onTap: () => onDestinationSelected(1),
                  ),
                  _DrawerItem(
                    icon: Icons.download_rounded,
                    label: 'Resources',
                    caption: 'Cheat sheets and guides',
                    onTap: () => onDestinationSelected(2),
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Certificate',
                    caption: 'Track your achievement',
                    onTap: () => onDestinationSelected(3),
                  ),
                  const Divider(height: 30),
                  _DrawerItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About SkillBridge Academy',
                    caption: 'Learn • Build • Grow',
                    onTap: () => onDestinationSelected(4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Row(
                children: [
                  const Icon(
                    Icons.offline_bolt_rounded,
                    size: 18,
                    color: SkillBridgeColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Works offline on this device',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.appColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: SkillBridgeColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: SkillBridgeColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        caption,
        style: TextStyle(
          fontSize: 12,
          color: context.appColors.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.appColors.textMuted,
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    // A dark brand hero reads correctly in both themes, so the wash stays dark
    // and the white type on it keeps its contrast.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B2547), SkillBridgeColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onMenuTap,
                tooltip: 'Open LMS menu',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.menu_rounded),
              ),
              const SizedBox(width: 8),
              const CodeBuddy(size: 88, mood: BuddyMood.happy),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SkillBridge ACADEMY',
                      style: TextStyle(
                        color: Color(0xFFBFE0FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Python Lab',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Write, run and submit real Python anywhere, even offline.',
            style: TextStyle(
              color: Color(0xFFD8E9FF),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerGreeting extends StatelessWidget {
  const _LearnerGreeting({required this.progress, this.learnerName});

  final LearnerProgress progress;
  final String? learnerName;

  @override
  Widget build(BuildContext context) {
    final hasStarted = progress.completedChallenges > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: SkillBridgeColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SkillBridgeColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: SkillBridgeColors.accent,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  learnerName != null
                      ? 'Welcome, $learnerName'
                      : hasStarted
                      ? 'Welcome back'
                      : 'Welcome to SkillBridge Academy',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasStarted
                      ? 'Pick up where you left off and keep your streak alive.'
                      : 'Your first Python adventure begins here.',
                  style: TextStyle(
                    color: context.appColors.textMuted,
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.connectivity});

  final ConnectivityController connectivity;

  @override
  Widget build(BuildContext context) {
    final online = connectivity.isOnline;
    final tone = online ? SkillBridgeColors.success : SkillBridgeColors.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              online
                  ? 'Connected'
                  : 'Offline mode · your work is saved on this device',
              style: TextStyle(
                fontSize: 13,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
          if (connectivity.pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: SkillBridgeColors.goldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${connectivity.pendingCount} to sync',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2A1D00),
                ),
              ),
            ),
          if (connectivity.isSyncing)
            const Padding(
              padding: EdgeInsets.only(left: 10, right: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded, size: 20),
              tooltip: 'Sync now',
              onPressed: connectivity.syncNow,
            ),
        ],
      ),
    );
  }
}

/// A milestone a learner can reach, and whether they have reached it yet.
typedef _Milestone = ({IconData icon, String label, Color color, bool earned});

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.progress});

  final LearnerProgress progress;

  /// These used to be three fixed badges every learner saw from their very
  /// first launch, which claimed milestones nobody had earned. They now light
  /// up from the learner's own totals and stay dim until they are reached.
  List<_Milestone> get _milestones => <_Milestone>[
    (
      icon: Icons.lightbulb_rounded,
      label: 'First step',
      color: const Color(0xFFFFC857),
      earned: progress.completedChallenges >= 1,
    ),
    (
      icon: Icons.code_rounded,
      label: 'Code explorer',
      color: const Color(0xFF63B3FF),
      earned: progress.completedChallenges >= 5,
    ),
    (
      icon: Icons.emoji_events_rounded,
      label: 'Halfway hero',
      color: const Color(0xFFFF7D9A),
      earned: progress.completionRatio >= 0.5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final milestones = _milestones;
    final earned = milestones.where((m) => m.earned).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Milestones',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '$earned of ${milestones.length}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < milestones.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _MiniBadge(
                  icon: milestones[i].icon,
                  label: milestones[i].label,
                  color: milestones[i].color,
                  earned: milestones[i].earned,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.earned = true,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// A milestone still ahead of the learner stays dim, so the row shows both
  /// what has been earned and what is left to earn.
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final tone = earned ? color : context.appColors.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(earned ? icon : Icons.lock_rounded, color: tone, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final LearnerProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your progress',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  label: 'Completed',
                  value: '${progress.completedChallenges}',
                ),
                _Stat(
                  label: 'SkillCoins',
                  value: '${progress.totalPoints}',
                  gold: true,
                ),
                _Stat(
                  label: 'Challenges',
                  value: '${progress.totalChallenges}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: progress.completionRatio.toDouble(),
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: context.appColors.surfaceHigh,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SkillCoins are verified by your SkillBridge Academy account.',
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.gold = false});

  final String label;
  final String value;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: gold
                  ? SkillBridgeColors.accent
                  : context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.exercise, required this.onTap});

  final Exercise? exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PremiumButton(
        onPressed: onTap,
        icon: Icons.play_arrow_rounded,
        label: exercise == null
            ? 'START CODING'
            : 'CONTINUE · ${exercise!.title}',
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12.5,
                color: context.appColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tone = isError ? SkillBridgeColors.error : SkillBridgeColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: context.appColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          CodeBuddy(size: 110, mood: BuddyMood.thinking),
          SizedBox(height: 10),
          Text(
            'Nothing here yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            "Connect to the internet once to download your challenges. They'll then work offline.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Compact "you are here" map shown right after login. Tapping it opens the
/// full learning path map on the LMS hub.
class _LearningMapCard extends StatelessWidget {
  const _LearningMapCard({required this.progress, required this.onOpenFullMap});

  final LearnerProgress progress;
  final VoidCallback onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    final total = learningPlaces.length;
    final finished = progress.completedChallenges.clamp(0, total);
    final current = progress.completedChallenges.clamp(0, total - 1);
    final place = learningPlaces[current];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenFullMap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      previewForPlace(place.number),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR LEARNING MAP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: context.appColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Place $finished of $total · ${place.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.appColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < finished
                                ? SkillBridgeColors.primary
                                : i == current
                                ? SkillBridgeColors.accent
                                : context.appColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'You are here — tap to see the full path',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
