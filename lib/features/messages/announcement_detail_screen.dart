import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import 'announcement_controller.dart';

/// Full message view. Opening it is what marks an announcement as read.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Marking read notifies the inbox provider, so wait until the first frame
    // is built before touching shared state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    final controller = context.read<AnnouncementController>();
    if (controller.find(widget.id) == null) {
      await controller.load(refresh: true);
    }
    if (!mounted) return;
    await controller.markRead(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnnouncementController>();
    final item = controller.find(widget.id);
    final palette = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: item == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  controller.busy
                      ? 'Loading announcement…'
                      : 'This announcement is no longer available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: SkillBridgeColors.brandGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.outline),
                  ),
                  child: Text(
                    item.body,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Posted ${_formatDate(item.createdAt)}',
                  style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: const TextStyle(color: SkillBridgeColors.error),
                  ),
                ],
              ],
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
  return '${local.day} ${months[local.month - 1]} ${local.year} at '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
