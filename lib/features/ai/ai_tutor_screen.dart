import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/di/app_dependencies.dart';
import '../auth/auth_controller.dart';
import '../course/guardian_report.dart';
import '../course/python_course_content.dart';
import '../../shared/widgets/code_buddy.dart';
import '../../shared/widgets/pressable.dart';
import 'tutor_models.dart';
import 'http_tutor_tools.dart';
import 'tutor_service.dart';

/// Conversation with the on-device Python tutor.
///
/// Empty state doubles as the welcome screen (mascot + starter prompts);
/// once messages exist the learner gets a real chat: bubbles on both sides,
/// code in a monospace block with a copy button, quick follow-up chips and a
/// typing indicator while the tutor thinks. All answers come from
/// [TutorService], which runs locally, so replies work with no network.
class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key, this.service});

  /// Injection point for tests or a future remote backend; falls back to the
  /// built-in offline brain.
  final TutorService? service;

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  late final TutorService _service;
  TutorAttachment? _pendingAttachment;
  bool _busy = false;
  int _nextId = 0;

  static const int _typingKey = -1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TutorService();
    if (widget.service == null) unawaited(_loadStudentContext());
  }

  Future<void> _loadStudentContext() async {
    try {
      final deps = context.read<AppDependencies>();
      final auth = context.read<AuthController>();
      final progress = await deps.lmsClient.fetchProgress();
      final report = GuardianReport.build(
        course: pythonKickstartCourse,
        history: deps.courseProgress.history(deps.learnerRef),
      );
      final contextData = TutorStudentContext.fromRecords(
        learnerName: auth.session?.displayName ?? 'Learner',
        progress: progress,
        report: report,
      );
      final tools = deps.config.aiTutorBaseUrl.isEmpty
          ? TutorToolRegistry(studentContext: contextData)
          : HttpTutorTools(
              baseUrl: deps.config.aiTutorBaseUrl,
              token: deps.config.aiTutorToken,
            ).registry(contextData);
      _service.updateContext(
        contextData,
        tools: tools,
      );
      if (mounted) setState(() {});
    } catch (_) {
      // The offline tutor remains usable when the LMS is unavailable.
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _ChatMessage _message(String text, {bool fromUser = false, bool error = false}) =>
      _ChatMessage(_nextId++, text, fromUser: fromUser, error: error);

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    HapticFeedback.selectionClick();
    final attachment = _pendingAttachment;
    setState(() {
      _messages.add(_message(text, fromUser: true));
      _busy = true;
      _input.clear();
      _pendingAttachment = null;
    });
    _scrollToLatest();
    try {
      // A beat of thinking time so the typing indicator reads as intent.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final reply = await _service.ask(
        text,
        attachments: attachment == null
            ? const <TutorAttachment>[]
            : <TutorAttachment>[attachment],
      );
      if (!mounted) return;
      setState(() => _messages.add(_message(reply)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_message(
          'Something went wrong while thinking. Please try again.',
          error: true,
        ));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _scrollToLatest();
  }

  Future<void> _pickScreenshot() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingAttachment = TutorAttachment(
        name: picked.name,
        mimeType: picked.mimeType ?? 'image/*',
        bytes: bytes,
      );
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _clearChat() {
    if (_busy) return;
    setState(_messages.clear);
  }

  /// Maps a message key back to its list position so existing bubbles keep
  /// their state (and do not replay their entrance) when a new one arrives.
  int? _indexForKey(Key key) {
    if (key is! ValueKey<int>) return null;
    if (key.value == _typingKey) return _busy ? 0 : null;
    final i = _messages.indexWhere((m) => m.id == key.value);
    if (i < 0) return null;
    return _busy ? _messages.length - i : _messages.length - 1 - i;
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SkillBridgeColors.brandGradient,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text('AI Tutor'),
          ],
        ),
        actions: [
          if (hasMessages)
            IconButton(
              tooltip: 'New chat',
              onPressed: _busy ? null : _clearChat,
              icon: const Icon(Icons.add_comment_rounded, size: 22),
            ),
          Container(
            margin: const EdgeInsets.only(right: 14, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: SkillBridgeColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SkillBridgeColors.accent.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: SkillBridgeColors.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  _service.modeLabel,
                  style: const TextStyle(
                    color: SkillBridgeColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          // Keeps the chat readable on tablets, desktop and browser windows.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: !hasMessages
                        ? _WelcomeView(
                            key: const ValueKey('welcome'),
                            onPick: _send,
                            enabled: !_busy,
                          )
                        : ListView.builder(
                            key: const ValueKey('chat'),
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            itemCount: _messages.length + (_busy ? 1 : 0),
                            findChildIndexCallback: _indexForKey,
                            itemBuilder: (context, index) {
                              if (_busy && index == 0) {
                                return const _Appear(
                                  key: ValueKey<int>(_typingKey),
                                  child: _TypingIndicator(),
                                );
                              }
                              final messageIndex = _busy
                                  ? _messages.length - index
                                  : _messages.length - 1 - index;
                              final message = _messages[messageIndex];
                              return _Appear(
                                key: ValueKey<int>(message.id),
                                fromUser: message.fromUser,
                                child: _MessageBubble(message: message),
                              );
                            },
                          ),
                  ),
                ),
                if (hasMessages)
                  _FollowUpChips(enabled: !_busy, onPick: _send),
                _Composer(
                  controller: _input,
                  focusNode: _focus,
                  busy: _busy,
                  hasAttachment: _pendingAttachment != null,
                  onPickScreenshot: _pickScreenshot,
                  onSend: () => _send(_input.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.id, this.text,
      {this.fromUser = false, this.error = false});

  final int id;
  final String text;
  final bool fromUser;
  final bool error;
}

/// Fade + rise (and a slight slide from the sender's side) for a new bubble.
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child, this.fromUser = false});

  final Widget child;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((fromUser ? 18 : -18) * (1 - t), 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Hero + starter prompts, shown until the first message is sent.
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({super.key, required this.onPick, required this.enabled});

  final ValueChanged<String> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        SkillBridgeColors.primary.withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: CodeBuddy(size: 108, mood: BuddyMood.thinking),
                  ),
                ),
                const SizedBox(height: 10),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Let's learn ",
                        style: TextStyle(
                          color: SkillBridgeColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Python',
                        style: TextStyle(
                          color: SkillBridgeColors.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: SkillBridgeColors.primary,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ask anything — loops, errors, ideas, quizzes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _PromptCard(
                icon: Icons.sync_rounded,
                iconColor: const Color(0xFF1697F5),
                title: 'Explain loops',
                subtitle: 'for & while, simply',
                onTap: enabled
                    ? () => onPick('Explain for and while loops simply')
                    : null,
              ),
              _PromptCard(
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFFD0B5FF),
                title: 'Quiz me',
                subtitle: 'quick checkpoint',
                onTap: enabled ? () => onPick('Quiz me') : null,
              ),
              _PromptCard(
                icon: Icons.build_rounded,
                iconColor: const Color(0xFFFFB81C),
                title: 'Fix my code',
                subtitle: 'paste the error',
                onTap: enabled
                    ? () => onPick('Help me fix this Python error')
                    : null,
              ),
              _PromptCard(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFF7CF000),
                title: 'Challenge',
                subtitle: "today's pickup",
                onTap: enabled
                    ? () => onPick('Give me a fun Python challenge for today')
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: title,
      child: Pressable(
        enabled: onTap != null,
        child: Material(
          color: SkillBridgeColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SkillBridgeColors.outline),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                      border:
                          Border.all(color: iconColor.withValues(alpha: 0.5)),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SkillBridgeColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SkillBridgeColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String text, String confirmation) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(confirmation),
        duration: const Duration(milliseconds: 1400),
      ),
    );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  /// Splits [text] into prose and ``` fenced code blocks.
  List<Widget> _blocks(BuildContext context) {
    final widgets = <Widget>[];
    final parts = message.text.split('```');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.trim().isEmpty) continue;
      if (i.isOdd) {
        final code = part.trim();
        final language = RegExp(r'^[a-zA-Z_]+\n').firstMatch(code);
        final lines =
            language == null ? code : code.substring(language.end).trimRight();
        widgets.add(_CodeBlock(code: lines));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SelectableText(
              part.trim(),
              style: TextStyle(
                color: message.error
                    ? SkillBridgeColors.error
                    : SkillBridgeColors.textPrimary,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              gradient: SkillBridgeColors.brandGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
              boxShadow: [
                BoxShadow(
                  color: SkillBridgeColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SelectableText(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final accent =
        message.error ? SkillBridgeColors.error : SkillBridgeColors.primary;
    final borderColor = message.error
        ? SkillBridgeColors.error.withValues(alpha: 0.5)
        : SkillBridgeColors.outline;
    final bgColor = message.error
        ? SkillBridgeColors.error.withValues(alpha: 0.08)
        : SkillBridgeColors.surfaceHigh;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: message.error
                  ? null
                  : SkillBridgeColors.brandGradient,
              color: message.error ? accent.withValues(alpha: 0.18) : null,
            ),
            child: Icon(
              message.error
                  ? Icons.error_outline_rounded
                  : Icons.auto_awesome_rounded,
              size: 16,
              color: message.error ? accent : Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._blocks(context),
                    if (!message.error)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _MiniAction(
                            icon: Icons.copy_rounded,
                            label: 'Copy',
                            onTap: () => _copy(
                              context,
                              message.text,
                              'Reply copied',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: SkillBridgeColors.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: SkillBridgeColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fenced code block with a language label and a copy button.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      decoration: BoxDecoration(
        color: SkillBridgeColors.codeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded,
                    size: 14, color: SkillBridgeColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'PYTHON',
                  style: TextStyle(
                    color: SkillBridgeColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                _MiniAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy code',
                  onTap: () => _copy(context, code, 'Code copied'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: SkillBridgeColors.textPrimary,
                fontSize: 13,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three pulsing dots shown while the tutor is composing a reply.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery cannot be read from initState; gate with _started because
    // this runs again whenever dependencies change.
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = SkillBridgeColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        key: const Key('typing-dots'),
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SkillBridgeColors.brandGradient,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: SkillBridgeColors.surfaceHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: SkillBridgeColors.outline),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final pulse = t < 0.5 ? t * 2 : (1 - t) * 2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Transform.translate(
                        offset: Offset(0, -3 * pulse),
                        child: Opacity(
                          opacity: 0.35 + pulse * 0.65,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One-tap follow-ups shown once a conversation has started.
class _FollowUpChips extends StatelessWidget {
  const _FollowUpChips({required this.enabled, required this.onPick});

  final bool enabled;
  final ValueChanged<String> onPick;

  static const _items = <(IconData, String, String)>[
    (Icons.unfold_more_rounded, 'Explain more', 'Can you explain that in more detail?'),
    (Icons.code_rounded, 'Show an example', 'Show me a short example'),
    (Icons.quiz_rounded, 'Test me', 'Test me on what we just covered'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = _items[i];
          return Pressable(
            enabled: enabled,
            child: ActionChip(
              avatar: Icon(item.$1,
                  size: 16,
                  color: enabled
                      ? SkillBridgeColors.primary
                      : SkillBridgeColors.textMuted),
              label: Text(item.$2),
              labelStyle: TextStyle(
                color: enabled
                    ? SkillBridgeColors.textPrimary
                    : SkillBridgeColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              onPressed: enabled ? () => onPick(item.$3) : null,
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.hasAttachment,
    required this.onPickScreenshot,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool hasAttachment;
  final VoidCallback onPickScreenshot;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: SkillBridgeColors.background,
        border: Border(top: BorderSide(color: SkillBridgeColors.outline)),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, focusNode]),
        builder: (context, _) {
          final ready = controller.text.trim().isNotEmpty && !busy;
          final focused = focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: SkillBridgeColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused
                    ? SkillBridgeColors.primary
                    : SkillBridgeColors.outline,
                width: focused ? 1.6 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color:
                            SkillBridgeColors.primary.withValues(alpha: 0.18),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    onPressed: busy ? null : onPickScreenshot,
                    tooltip: 'Attach a screenshot',
                    icon: Icon(
                      hasAttachment
                          ? Icons.image_rounded
                          : Icons.add_photo_alternate_outlined,
                      color: hasAttachment
                          ? SkillBridgeColors.accent
                          : SkillBridgeColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  // Enter sends; Shift+Enter inserts a new line (desktop/web).
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter): () {
                        if (ready) onSend();
                      },
                    },
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        color: SkillBridgeColors.textPrimary,
                        fontSize: 15,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask about loops, errors, quizzes\u2026',
                        hintStyle: TextStyle(
                          color: SkillBridgeColors.textMuted,
                          fontSize: 15,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AnimatedScale(
                    scale: ready ? 1 : 0.88,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: IconButton(
                      onPressed: ready ? onSend : null,
                      tooltip: 'Send to tutor',
                      style: IconButton.styleFrom(
                        backgroundColor: ready
                            ? SkillBridgeColors.primary
                            : SkillBridgeColors.surfaceHigh,
                        foregroundColor: ready
                            ? SkillBridgeColors.onPrimary
                            : SkillBridgeColors.textMuted,
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
