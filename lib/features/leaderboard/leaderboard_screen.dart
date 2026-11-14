import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/icon_badge.dart';
import '../auth/auth_controller.dart';
import 'leaderboard_client.dart';
import 'leaderboard_models.dart';
import 'leaderboard_sync.dart';

/// Screen: the shared ranking.
///
/// Shows the same list the website shows, because both read one endpoint: learners
/// are ordered by the score they earned across the twelve steps, with their photo,
/// steps finished and hands-on practice counted. This device's learner is pushed
/// to the server before the list is read, so a score finished offline appears here
/// on the next open.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardClient? _client;
  List<LeaderboardEntry> _entries = const <LeaderboardEntry>[];
  bool _loading = true;
  String? _error;
  String? _avatarDataUrl;

  AppDependencies get _deps => context.read<AppDependencies>();

  String get _learnerName =>
      context.read<AuthController>().session?.displayName ?? 'Learner';

  String get _myId => 'app:${_deps.learnerRef}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client != null) return;
    _client = LeaderboardSync.clientFor(_deps);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = _client;
    if (client == null) return;
    if (!client.configured) {
      setState(() {
        _loading = false;
        _error =
            'The leaderboard is not connected in this build. Set '
            'SB_LEADERBOARD_URL to the website address.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Publish this learner's current totals first, then read the ranking.
    await LeaderboardSync.push(
      deps: _deps,
      name: _learnerName,
      avatarDataUrl: _avatarDataUrl,
    );

    try {
      final entries = await client.top();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on LeaderboardException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final client = _client;
    if (client == null || !client.configured) return;

    // Read the providers before the first await so no BuildContext is used
    // across an async gap.
    final deps = _deps;
    final name = _learnerName;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
    } catch (_) {
      _notice('That photo could not be read.');
      return;
    }
    if (picked == null) return;

    List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      _notice('That photo could not be read.');
      return;
    }
    if (bytes.isEmpty || bytes.length > 60 * 1024) {
      _notice('Choose a smaller photo — under 60 KB.');
      return;
    }

    final mime = picked.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    _avatarDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    await LeaderboardSync.push(
      deps: deps,
      name: name,
      avatarDataUrl: _avatarDataUrl,
    );
    if (!mounted) return;
    _notice('Profile photo saved to the leaderboard.');
    await _load();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  LeaderboardEntry? get _me {
    for (final entry in _entries) {
      if (entry.id == _myId) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final me = _me;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Choose profile photo',
            onPressed: client?.configured == true && !_loading ? _pickPhoto : null,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _HeaderCard(me: me, avatarDataUrl: _avatarDataUrl),
                if (_loading) ...[
                  const SizedBox(height: 48),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_error != null) ...[
                  const SizedBox(height: 20),
                  _MessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Ranking unavailable',
                    message: _error!,
                    actionLabel: client?.configured == true ? 'Try again' : null,
                    onAction: client?.configured == true ? _load : null,
                  ),
                ] else if (_entries.isEmpty) ...[
                  const SizedBox(height: 20),
                  const _MessageCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'No scores yet',
                    message:
                        'Finish step 1 and you take the first spot on the board.',
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  for (final entry in _entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RankRow(
                        entry: entry,
                        isMe: entry.id == _myId,
                        avatarUrl: entry.hasAvatar && client != null
                            ? client.avatarUrl(entry.id)
                            : null,
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Ranks use the total score across the twelve steps; more '
                  'finished steps and higher scores both move you up. Photos are '
                  'visible to everyone on this board.',
                  style: TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 12,
                    height: 1.5,
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.me, required this.avatarDataUrl});

  final LeaderboardEntry? me;
  final String? avatarDataUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: SkillBridgeColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Row(
        children: [
          _Avatar(
            name: me?.name ?? 'You',
            image: avatarDataUrl != null
                ? MemoryImage(base64Decode(avatarDataUrl!.split(',').last))
                : null,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me == null ? 'Not ranked yet' : 'Rank #${me!.rank}',
                  style: const TextStyle(
                    color: SkillBridgeColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  me == null
                      ? 'Finish a step to join the board.'
                      : '${me!.stepsCompleted} steps · '
                          '${me!.practicesCompleted} practice · '
                          '${me!.score} points · ${me!.average}% average',
                  style: const TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const IconBadge(
            icon: Icons.emoji_events_rounded,
            colors: IconBadge.gold,
            size: 46,
            circle: true,
            glow: false,
            iconColor: Color(0xFF2A1D00),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.isMe,
    required this.avatarUrl,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final String? avatarUrl;

  String get _medal => switch (entry.rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final top = entry.rank <= 3;
    return Semantics(
      label:
          'Rank ${entry.rank}, ${entry.name}, ${entry.score} points, '
          '${entry.stepsCompleted} steps',
      button: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? SkillBridgeColors.primary.withValues(alpha: 0.12)
              : SkillBridgeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMe
                ? SkillBridgeColors.primary.withValues(alpha: 0.55)
                : top
                    ? SkillBridgeColors.accent.withValues(alpha: 0.35)
                    : SkillBridgeColors.outline,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                _medal.isNotEmpty ? _medal : '#${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: top
                      ? SkillBridgeColors.accent
                      : SkillBridgeColors.textMuted,
                  fontSize: _medal.isNotEmpty ? 18 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _Avatar(
              name: entry.name,
              image: avatarUrl == null ? null : NetworkImage(avatarUrl!),
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${entry.name} (you)' : entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SkillBridgeColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.fromApp ? 'Android app' : 'Browser'} · '
                    '${entry.stepsCompleted} steps · '
                    '${entry.practicesCompleted} practice',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SkillBridgeColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.score}',
                  style: const TextStyle(
                    color: SkillBridgeColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.image, required this.size});

  final String name;
  final ImageProvider? image;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).take(2);
    final letters = parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase());
    final joined = letters.join();
    return joined.isEmpty ? 'S' : joined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SkillBridgeColors.surfaceHigh,
        border: Border.all(color: SkillBridgeColors.outline),
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              _initials,
              style: TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SkillBridgeColors.textMuted, size: 26),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: SkillBridgeColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: SkillBridgeColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 46),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
