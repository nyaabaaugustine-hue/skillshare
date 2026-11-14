import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';

/// Languages the welcome video is offered in.
enum WelcomeLanguage {
  english('English', 'Welcome video in English', 'EN'),
  twi('Twi', 'Akwaaba — Twi welcome', 'TW');

  const WelcomeLanguage(this.label, this.caption, this.badge);

  final String label;
  final String caption;
  final String badge;
}

const String _welcomeVideoEnglish =
    'https://res.cloudinary.com/dx1nrew3h/video/upload/v1794677999/nnnnewww_jl1qzc.mp4';

/// Cloudinary URL of the Twi welcome video.
const String _welcomeVideoTwi =
    'https://res.cloudinary.com/jrqocjcd/video/upload/v1793610104/twi.mp4';

String? welcomeVideoUrlFor(WelcomeLanguage language) => switch (language) {
  WelcomeLanguage.english => _welcomeVideoEnglish,
  WelcomeLanguage.twi => _welcomeVideoTwi.isEmpty ? null : _welcomeVideoTwi,
};

/// Shown once after every successful sign-in (or guest entry): asks which
/// language the learner prefers, then plays the matching welcome video.
///
/// The picker is the first thing a new learner sees after the account is
/// created, so it is treated as a brand moment: the mark, a warm Akwaaba, and
/// two unmissable language cards. Choosing a language swaps the sheet into a
/// player without closing it.
class WelcomeVideoDialog extends StatefulWidget {
  const WelcomeVideoDialog({super.key});

  @override
  State<WelcomeVideoDialog> createState() => _WelcomeVideoDialogState();
}

class _WelcomeVideoDialogState extends State<WelcomeVideoDialog> {
  WelcomeLanguage? _language;
  bool _fellBackToEnglish = false;
  bool _starting = false;
  VideoPlayerController? _controller;
  Object? _error;

  Future<void> _choose(WelcomeLanguage language) async {
    var url = welcomeVideoUrlFor(language);
    var fellBack = false;
    if (url == null) {
      url = _welcomeVideoEnglish;
      fellBack = true;
    }
    setState(() {
      _language = language;
      _fellBackToEnglish = fellBack;
      _error = null;
      _starting = true;
    });
    await _load(url);
  }

  Future<void> _load(String url) async {
    await _controller?.dispose();
    _controller = null;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
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

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  void _changeLanguage() {
    _controller?.dispose();
    setState(() {
      _controller = null;
      _language = null;
      _error = null;
      _fellBackToEnglish = false;
      _starting = false;
    });
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
      backgroundColor: SkillBridgeColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _language == null
                ? _LanguagePicker(
                    key: const ValueKey('picker'),
                    onPick: _choose,
                    onSkip: () => Navigator.of(context).pop(),
                  )
                : _Player(
                    key: const ValueKey('player'),
                    language: _language!,
                    fellBackToEnglish: _fellBackToEnglish,
                    starting: _starting,
                    controller: _controller,
                    error: _error,
                    onRetry: () => _choose(_language!),
                    onReplay: _replay,
                    onChangeLanguage: _changeLanguage,
                    onClose: () => Navigator.of(context).pop(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    super.key,
    required this.onPick,
    required this.onSkip,
  });

  final ValueChanged<WelcomeLanguage> onPick;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand hero strip, drawn without a network image so it is instant and
        // works offline.
        Container(
          height: 158,
          decoration: const BoxDecoration(
            gradient: SkillBridgeColors.heroGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -30,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 190,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -50,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SkillBridgeColors.primary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'WELCOME VIDEO',
                      style: TextStyle(
                        color: Color(0xFFB9DCFF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Akwaaba! Welcome.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SkillBridgeColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Choose the language for your welcome video.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SkillBridgeColors.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              for (final language in WelcomeLanguage.values) ...[
                _LanguageTile(
                  language: language,
                  available: welcomeVideoUrlFor(language) != null,
                  onTap: () => onPick(language),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 2),
              TextButton(onPressed: onSkip, child: const Text('Skip for now')),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.available,
    required this.onTap,
  });

  final WelcomeLanguage language;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final english = language == WelcomeLanguage.english;
    final accent = english
        ? SkillBridgeColors.primary
        : SkillBridgeColors.accent;
    return Material(
      color: english
          ? SkillBridgeColors.primary.withValues(alpha: 0.10)
          : SkillBridgeColors.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: english
                  ? SkillBridgeColors.primary.withValues(alpha: 0.55)
                  : SkillBridgeColors.outline,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: english
                        ? SkillBridgeColors.brandGradient.colors
                        : const [Color(0xFFFFD66B), Color(0xFFF2A81D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  language.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          language.label,
                          style: const TextStyle(
                            color: SkillBridgeColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!available) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SkillBridgeColors.accent.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SOON',
                              style: TextStyle(
                                color: SkillBridgeColors.accent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      language.caption,
                      style: const TextStyle(
                        color: SkillBridgeColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                color: english ? SkillBridgeColors.primary : accent,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({
    super.key,
    required this.language,
    required this.fellBackToEnglish,
    required this.starting,
    required this.controller,
    required this.error,
    required this.onRetry,
    required this.onReplay,
    required this.onChangeLanguage,
    required this.onClose,
  });

  final WelcomeLanguage language;
  final bool fellBackToEnglish;
  final bool starting;
  final VideoPlayerController? controller;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onReplay;
  final VoidCallback onChangeLanguage;
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
                    const Text(
                      'Welcome to SkillsBridge Academy',
                      style: TextStyle(
                        color: SkillBridgeColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${language.label} introduction · under a minute',
                      style: const TextStyle(
                        color: SkillBridgeColors.textMuted,
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
        if (fellBackToEnglish)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SkillBridgeColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: SkillBridgeColors.accent,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The Twi video is coming soon — playing English for now.',
                    style: TextStyle(
                      color: SkillBridgeColors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
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
                                padding: const EdgeInsets.only(top: 0),
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
              _LanguageChip(label: language.label, onTap: onChangeLanguage),
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

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SkillBridgeColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 16,
                color: SkillBridgeColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: SkillBridgeColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: SkillBridgeColors.textMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'The welcome video could not load.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SkillBridgeColors.textMuted),
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
