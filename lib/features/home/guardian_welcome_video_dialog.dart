import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';

const String guardianWelcomeVideoUrl =
    'https://res.cloudinary.com/jrqocjcd/video/upload/v1793550785/newvid.mp4';

/// Premium welcome video shown to guardians after login.
class GuardianWelcomeVideoDialog extends StatefulWidget {
  const GuardianWelcomeVideoDialog({super.key});

  @override
  State<GuardianWelcomeVideoDialog> createState() =>
      _GuardianWelcomeVideoDialogState();
}

class _GuardianWelcomeVideoDialogState
    extends State<GuardianWelcomeVideoDialog> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(guardianWelcomeVideoUrl),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    if (mounted) setState(() {});
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final size = controller?.value.size;
    final aspectRatio = size == null || size.width <= 0 || size.height <= 0
        ? 16 / 9
        : size.width / size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      backgroundColor: SkillBridgeColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Welcome to SkillsBridge Academy',
                        style: TextStyle(
                          color: SkillBridgeColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: aspectRatio,
                child: controller == null
                    ? _VideoState(error: _error, onRetry: _load)
                    : ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          if (value.hasError) {
                            return _VideoState(
                              error: value.errorDescription,
                              onRetry: _load,
                            );
                          }
                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(controller),
                              VideoProgressIndicator(
                                controller,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: SkillBridgeColors.primary,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                              if (!value.isPlaying)
                                Center(
                                  child: IconButton.filled(
                                    tooltip: 'Play',
                                    onPressed: controller.play,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'A short introduction for parents and guardians.',
                        style: TextStyle(color: SkillBridgeColors.textMuted),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller == null ? null : _replay,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Replay'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoState extends StatelessWidget {
  const _VideoState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 10),
            const Text(
              'The welcome video could not load.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
