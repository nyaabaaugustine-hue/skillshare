import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';
import 'package:skillbridge_python_lab/shared/widgets/entrance.dart';
import 'package:skillbridge_python_lab/shared/widgets/icon_badge.dart';
import 'package:skillbridge_python_lab/shared/widgets/pressable.dart';

import '../auth/auth_controller.dart';
import 'settings_controller.dart';

/// Screen F: Settings — theme, editor preferences, offline storage info,
/// app version and privacy controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _draftCount = 0;
  int _submissionCount = 0;
  int _pendingCount = 0;
  bool _loaded = false;

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final deps = context.read<AppDependencies>();
    try {
      final drafts = await deps.drafts.listFor(deps.learnerRef, limit: 1000);
      final submissions = await deps.submissions.listForLearner(
        deps.learnerRef,
        limit: 1000,
      );
      final pending = await deps.submissions.pendingCount(deps.learnerRef);
      if (mounted) {
        setState(() {
          _draftCount = drafts.length;
          _submissionCount = submissions.length;
          _pendingCount = pending;
          _loaded = true;
        });
      }
    } catch (_) {
      // A storage failure must not surface as an unhandled async error from
      // initState; show the section (with zeroed counts) instead of spinning.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear local data?'),
        content: const Text(
          'This removes drafts and submission history stored on this device. '
          'Submissions already accepted by the LMS are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 46),
              backgroundColor: SkillBridgeColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deps = context.read<AppDependencies>();
    await deps.drafts.deleteAllFor(deps.learnerRef);
    await deps.submissions.deleteAllFor(deps.learnerRef);
    await deps.settings.clearLearnerData();
    await _loadStats();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Local data cleared.')));
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in anytime. Drafts, progress and submissions '
          'stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthController>().signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    // Optional: SkillBridgeApp provides it, but lightweight test hosts may not.
    final auth = context.watch<AuthController?>();
    final session = auth?.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // Keeps the page readable on tablets, desktop and browser windows.
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Entrance(index: 0, child: _ProfileCard(session: session)),
              if (auth != null && auth.isAuthenticated) ...[
                const SizedBox(height: 12),
                Entrance(
                  index: 1,
                  child: _Group(
                    children: [
                      _SettingTile(
                        icon: Icons.logout_rounded,
                        colors: IconBadge.coral,
                        title: 'Sign out',
                        subtitle: 'Return to the login screen',
                        onTap: _confirmSignOut,
                      ),
                    ],
                  ),
                ),
              ],
              const _SectionHeader('Appearance'),
              Entrance(
                index: 2,
                child: _Group(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (selection) =>
                              settings.setThemeMode(selection.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _SectionHeader('Editor'),
              Entrance(
                index: 3,
                child: _Group(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBadge(
                                icon: Icons.text_fields_rounded,
                                colors: IconBadge.blue,
                                size: 38,
                                glow: false,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Font size',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: SkillBridgeColors.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${settings.editorFontSize.round()}',
                                  style: const TextStyle(
                                    color: SkillBridgeColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.editorFontSize,
                            min: 12,
                            max: 24,
                            divisions: 12,
                            label: settings.editorFontSize.round().toString(),
                            onChanged: settings.setEditorFontSize,
                          ),
                          // Live preview so the change is visible immediately.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SkillBridgeColors.codeSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: SkillBridgeColors.outline,
                              ),
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: settings.editorFontSize,
                                height: 1.4,
                                color: SkillBridgeColors.textPrimary,
                              ),
                              child: const Text(
                                'print("Hello, SkillsBridge Academy!")',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    _SettingTile(
                      icon: Icons.format_indent_increase_rounded,
                      colors: IconBadge.purple,
                      title: 'Indentation width',
                      subtitle: 'Spaces inserted by the indent button',
                      trailing: DropdownButton<int>(
                        value: settings.tabSize,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: SkillBridgeColors.surfaceHigh,
                        onChanged: (v) => settings.setTabSize(v!),
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2')),
                          DropdownMenuItem(value: 4, child: Text('4')),
                          DropdownMenuItem(value: 8, child: Text('8')),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      secondary: const IconBadge(
                        icon: Icons.save_rounded,
                        colors: IconBadge.green,
                        size: 38,
                        glow: false,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      title: const Text(
                        'Save drafts automatically',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text('Autosave your code while you type'),
                      value: settings.autoSaveDraft,
                      onChanged: settings.setAutoSaveDraft,
                    ),
                  ],
                ),
              ),
              const _SectionHeader('Offline storage'),
              Entrance(
                index: 4,
                child: _Group(
                  children: [
                    if (!_loaded)
                      const ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        title: Text('Calculating…'),
                        trailing: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      _SettingTile(
                        icon: Icons.storage_rounded,
                        colors: IconBadge.teal,
                        title: '$_draftCount drafts stored',
                        subtitle:
                            '$_submissionCount submissions on this device '
                            '($_pendingCount waiting to sync)',
                        trailing: _pendingCount > 0
                            ? const Icon(
                                Icons.sync_rounded,
                                color: SkillBridgeColors.accent,
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                color: SkillBridgeColors.success,
                              ),
                      ),
                  ],
                ),
              ),
              const _SectionHeader('Privacy & safety'),
              Entrance(
                index: 5,
                child: _Group(
                  children: [
                    const _SettingTile(
                      icon: Icons.lock_rounded,
                      colors: IconBadge.blue,
                      title: 'How your data is handled',
                      subtitle:
                          'Your code is stored on this device. It is only sent to the SkillsBridge Academy LMS '
                          'when you tap Submit. We do not collect phone numbers or run advertising.',
                    ),
                    _SettingTile(
                      icon: Icons.delete_outline_rounded,
                      colors: IconBadge.coral,
                      title: 'Clear local data',
                      subtitle: 'Remove drafts and submission history from this device',
                      onTap: _clearLocalData,
                    ),
                  ],
                ),
              ),
              const _SectionHeader('About'),
              Entrance(
                index: 6,
                child: _Group(
                  children: [
                    const _SettingTile(
                      icon: Icons.info_rounded,
                      colors: IconBadge.gold,
                      iconColor: Color(0xFF2A1D00),
                      title: 'SkillsBridge Academy',
                      subtitle:
                          'Version $appVersion • Offline-first Python practice',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                child: Text(
                  'Python programs run on your device. Local execution is sandboxed by the '
                  'operating system but is not a certified security boundary; only submit code '
                  'you are comfortable sharing with your academy.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: SkillBridgeColors.textMuted,
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

/// Avatar, name, role and email for the signed-in account.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s == null) {
      return const _Group(
        children: [
          _SettingTile(
            icon: Icons.person_outline_rounded,
            colors: IconBadge.blue,
            title: 'Not signed in',
            subtitle: 'Sign in or continue as a guest to start learning',
          ),
        ],
      );
    }

    final initial = s.displayName.trim().isEmpty
        ? '?'
        : s.displayName.trim()[0].toUpperCase();
    final IconData roleIcon = s.guest
        ? Icons.explore_outlined
        : (s.isGuardian ? Icons.family_restroom_rounded : Icons.school_rounded);
    final String roleLabel = s.guest ? 'Guest' : s.role.label;
    final String detail = s.guest
        ? 'Guest — progress stored on this device'
        : '${s.role.label} · ${s.email ?? 'Signed in'}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2547), Color(0xFF0F5FC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E9FF),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

/// Rounded card that holds a run of related rows, divided by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // A Material ancestor is required so the ListTile rows inside paint their
    // background, ripple and ink on this card rather than a hidden DecoratedBox.
    return Material(
      color: SkillBridgeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: SkillBridgeColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 66,
                color: SkillBridgeColors.outline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One settings row: icon badge, title, optional subtitle and trailing widget.
/// Tappable rows react with a ripple and a gentle press-down.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.colors,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final List<Color> colors;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: const RoundedRectangleBorder(),
      leading: IconBadge(
        icon: icon,
        colors: colors,
        iconColor: iconColor,
        size: 38,
        glow: false,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  color: SkillBridgeColors.textMuted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: SkillBridgeColors.textMuted,
                )),
    );
    return Pressable(enabled: onTap != null, scale: 0.985, child: tile);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
