import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';

const String _welcomeVideoEnglish =
    'https://res.cloudinary.com/dx1nrew3h/video/upload/v1794677999/nnnnewww_jl1qzc.mp4';

class WelcomeVideoDialog extends StatefulWidget {
  const WelcomeVideoDialog({super.key});

  @override
  State<WelcomeVideoDialog> createState() => _WelcomeVideoDialogState();
}

class _WelcomeVideoDialogState extends State<WelcomeVideoDialog> {
  bool _starting = true;
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _controller?.dispose();
    _controller = null;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_welcomeVideoEnglish),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      setState(() {
        _controller = controller;
        _starting = false;
        _error = null;
      });
      await controller.play();
    } catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _error = error;
          _starting = false;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _starting = true;
    });
    await _load();
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _Player(
            starting: _starting,
            controller: _controller,
            error: _error,
            onRetry: _retry,
            onReplay: _replay,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({
    required this.starting,
    required this.controller,
    required this.error,
    required this.onRetry,
    required this.onReplay,
    required this.onClose,
  });

  final bool starting;
  final VideoPlayerController? controller;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = controller?.value.size;
    final aspectRatio = size == null || size.width <= 0 || size.height <= 0
        ? 16 / 9
        : size.width / size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to SkillBridge Academy',
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'English welcome video · under a minute',
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                color: Colors.black,
                child: controller == null
                    ? _VideoState(
                        loading: starting,
                        error: error,
                        onRetry: onRetry,
                      )
                    : ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller!,
                        builder: (context, value, _) {
                          if (value.hasError) {
                            return _VideoState(
                              loading: false,
                              error: value.errorDescription,
                              onRetry: onRetry,
                            );
                          }
                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Center(child: VideoPlayer(controller!)),
                              VideoProgressIndicator(
                                controller!,
                                allowScrubbing: true,
                                padding: EdgeInsets.zero,
                                colors: const VideoProgressColors(
                                  playedColor: SkillBridgeColors.primary,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                              if (!value.isPlaying)
                                Center(
                                  child: IconButton.filled(
                                    tooltip: 'Play',
                                    onPressed: controller!.play,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              const Spacer(),
              IconButton.outlined(
                tooltip: 'Replay',
                onPressed: controller == null ? null : onReplay,
                icon: const Icon(Icons.replay_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(132, 46)),
                onPressed: onClose,
                child: const Text('Start learning'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoState extends StatelessWidget {
  const _VideoState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading || error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'The welcome video could not load.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
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
