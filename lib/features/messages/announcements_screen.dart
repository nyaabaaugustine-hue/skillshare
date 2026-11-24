import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../features/auth/auth_controller.dart';
import 'announcement.dart';
import 'announcement_controller.dart';

/// Inbox for one-way admin announcements.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final signedIn =
          context.read<AuthController?>()?.session?.isAccount ?? false;
      if (signedIn) context.read<AnnouncementController>().load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn =
        context.watch<AuthController?>()?.session?.isAccount ?? false;
    final controller = context.watch<AnnouncementController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.busy
                  ? null
                  : () => controller.load(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: !signedIn
          ? const _CenteredMessage(
              icon: Icons.mail_outline_rounded,
              title: 'Sign in to see announcements',
              body: 'Admin updates are delivered to linked learner accounts.',
            )
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.busy && controller.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => controller.load(refresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height / 4,
                        ),
                        const _CenteredMessage(
                          icon: Icons.inbox_rounded,
                          title: 'No announcements yet',
                          body: 'Messages from SkillBridge Academy will appear here.',
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => controller.load(refresh: true),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: controller.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      return _AnnouncementTile(
                        item: item,
                        onTap: () =>
                            Navigator.of(context)
                                .pushNamed('/announcements/${item.id}'),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item, required this.onTap});

  final Announcement item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Card(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.outline),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SkillBridgeColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.isRead
                ? Icons.mail_outline_rounded
                : Icons.markunread_mailbox_rounded,
            color: SkillBridgeColors.primaryDeep,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${_formatDate(item.createdAt)}  •  ${item.body}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
          ),
        ),
        trailing: item.isRead
            ? const Icon(Icons.chevron_right_rounded)
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: SkillBridgeColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: palette.textMuted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = time.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} • $hour:$minute';
}
