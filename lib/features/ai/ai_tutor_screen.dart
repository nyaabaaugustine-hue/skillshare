import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/di/app_dependencies.dart';
import '../auth/auth_controller.dart';
import '../course/guardian_report.dart';
import '../course/python_course_content.dart';
import '../../shared/widgets/code_buddy.dart';
import '../../shared/widgets/pressable.dart';
import 'tutor_models.dart';
import 'cloudflare_tutor_client.dart';
import 'tutor_service.dart';
import 'tutor_visual_aid.dart';

/// Offline-first conversation with the SkillsBridge Python tutor.
///
/// Empty state doubles as the welcome screen (mascot + starter prompts);
/// Signed-in learners may also use the authenticated Cloudflare tutor. Once
/// messages exist, learners get a real chat: bubbles on both sides,
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
  final _speechToText = SpeechToText();
  final _textToSpeech = FlutterTts();
  final _messages = <_ChatMessage>[];
  late final TutorService _service;
  CloudflareTutorClient? _cloudflareClient;
  TutorAttachment? _pendingAttachment;
  bool _busy = false;
  bool _isListening = false;
  bool _streamHasStarted = false;
  int? _loadingVideoFor;
  int _nextId = 0;

  static const int _typingKey = -1;
  bool get _showTyping => _busy && !_streamHasStarted;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TutorService();
    if (widget.service == null) unawaited(_loadStudentContext());
  }

  Future<void> _loadStudentContext() async {
    late final AppDependencies deps;
    late final AuthController auth;
    try {
      deps = context.read<AppDependencies>();
      auth = context.read<AuthController>();
    } catch (_) {
      return;
    }

    TutorRemoteChat? remote;
    TutorRemoteStream? remoteStream;
    final session = auth.session;
    final base = deps.config.aiTutorBaseUrl;
    if (base.isNotEmpty &&
        auth.cloudAuthEnabled &&
        session?.isAccount == true &&
        session?.role == UserRole.student &&
        session?.token?.isNotEmpty == true) {
      final client = CloudflareTutorClient(
        baseUrl: base,
        accessTokenProvider: () => auth.session?.token,
      );
      _cloudflareClient = client;
      remote = client.chat;
      remoteStream = client.chatStream;
    }

    var contextData = TutorStudentContext(
      learnerName: session?.displayName ?? 'Learner',
      totalPoints: 0,
      completedChallenges: 0,
      totalChallenges: 0,
      weakPoints: const <String>[],
      recentScores: const <String, int>{},
    );
    try {
      final progress = await deps.lmsClient.fetchProgress();
      final report = GuardianReport.build(
        course: pythonKickstartCourse,
        history: deps.courseProgress.history(deps.learnerRef),
      );
      contextData = TutorStudentContext.fromRecords(
        learnerName: auth.session?.displayName ?? 'Learner',
        progress: progress,
        report: report,
      );
    } catch (error) {
      debugPrint(
        'Tutor progress context unavailable; continuing without progress.',
      );
    }

    _service.updateContext(
      contextData,
      tools: TutorToolRegistry(
        studentContext: contextData,
        screenshotAnalysis: _cloudflareClient?.analyzeScreenshot,
        videoSearch: _cloudflareClient?.findShortVideos,
      ),
      remote: remote,
      remoteStream: remoteStream,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _cloudflareClient?.close();
    unawaited(_speechToText.cancel());
    unawaited(_textToSpeech.stop());
    super.dispose();
  }

  _ChatMessage _message(
    String text, {
    bool fromUser = false,
    bool error = false,
    List<String> sources = const <String>[],
    String? resourceTopic,
    List<TutorVideo> videos = const <TutorVideo>[],
  }) => _ChatMessage(
    _nextId++,
    text,
    fromUser: fromUser,
    error: error,
    sources: sources,
    resourceTopic: resourceTopic,
    videos: videos,
  );

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    final attachment = _pendingAttachment;
    if (attachment != null && _cloudflareClient != null) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send screenshot for analysis?'),
          content: const Text(
            'This image will be sent to SkillsBridge AI to help explain what '
            'it shows. Avoid including names, passwords, or other private '
            'information.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send screenshot'),
            ),
          ],
        ),
      );
      if (consent != true || !mounted) return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_message(text, fromUser: true));
      _busy = true;
      _streamHasStarted = false;
      _input.clear();
      _pendingAttachment = null;
    });
    _scrollToLatest();
    try {
      // A beat of thinking time so the typing indicator reads as intent.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (attachment != null) {
        final reply = await _service.askReply(
          text,
          attachments: <TutorAttachment>[attachment],
        );
        if (!mounted) return;
        setState(
          () => _messages.add(
            _message(reply.text, sources: reply.sources, resourceTopic: text),
          ),
        );
      } else {
        final replyId = _nextId++;
        final answer = StringBuffer();
        final sources = <String>[];
        await for (final event in _service.askStream(text)) {
          if (!mounted) return;
          if (event.text.isNotEmpty) answer.write(event.text);
          if (event.sources.isNotEmpty) {
            sources
              ..clear()
              ..addAll(event.sources);
          }
          setState(() {
            if (event.text.isNotEmpty) _streamHasStarted = true;
            final index = _messages.indexWhere(
              (message) => message.id == replyId,
            );
            final reply = _ChatMessage(
              replyId,
              answer.toString(),
              sources: List<String>.unmodifiable(sources),
              resourceTopic: text,
            );
            if (index < 0) {
              _messages.add(reply);
            } else {
              _messages[index] = reply;
            }
          });
          _scrollToLatest();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _message(
            'Something went wrong while thinking. Please try again.',
            error: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _streamHasStarted = false;
        });
      }
    }
    _scrollToLatest();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask by voice'),
        content: const Text(
          'Your device speech service will turn your voice into text. '
          'Review the text before sending it to the tutor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _isListening = status == 'listening');
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice input is not available on this device.'),
            ),
          );
        }
        return;
      }

      setState(() => _isListening = true);
      await _speechToText.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _input.text = result.recognizedWords);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input could not start.')),
      );
    }
  }

  Future<void> _readAloud(String text) async {
    final speechText = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code example omitted ')
        .replaceAll(RegExp(r'https://\S+'), ' link ')
        .trim();
    if (speechText.isEmpty) return;
    try {
      await _textToSpeech.stop();
      await _textToSpeech.setLanguage('en-US');
      await _textToSpeech.setSpeechRate(0.45);
      await _textToSpeech.speak(speechText);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Read aloud is unavailable right now.')),
      );
    }
  }

  Future<void> _findShortVideos(_ChatMessage message) async {
    final topic = message.resourceTopic;
    if (topic == null || _loadingVideoFor != null) return;
    setState(() => _loadingVideoFor = message.id);
    try {
      final videos = await _service.findShortVideos(topic);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(videos: videos);
        }
        _loadingVideoFor = null;
      });
      if (videos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No approved short videos are available for this topic yet.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVideoFor = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video recommendations are unavailable right now.'),
        ),
      );
    }
  }

  Future<void> _openResource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !const <String>{
          'docs.python.org',
          'youtube.com',
          'www.youtube.com',
        }.contains(uri.host)) {
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that learning resource.')),
      );
    }
  }

  Future<void> _pickScreenshot() async {
    if (_busy) return;
    try {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that screenshot.')),
      );
    }
  }

  void _removeScreenshot() {
    setState(() => _pendingAttachment = null);
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
    if (key.value == _typingKey) return _showTyping ? 0 : null;
    final i = _messages.indexWhere((m) => m.id == key.value);
    if (i < 0) return null;
    return _showTyping ? _messages.length - i : _messages.length - 1 - i;
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
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 17,
              ),
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
                const Icon(
                  Icons.bolt_rounded,
                  color: SkillBridgeColors.accent,
                  size: 14,
                ),
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
                            itemCount: _messages.length + (_showTyping ? 1 : 0),
                            findChildIndexCallback: _indexForKey,
                            itemBuilder: (context, index) {
                              if (_showTyping && index == 0) {
                                return const _Appear(
                                  key: ValueKey<int>(_typingKey),
                                  child: _TypingIndicator(),
                                );
                              }
                              final messageIndex = _showTyping
                                  ? _messages.length - index
                                  : _messages.length - 1 - index;
                              final message = _messages[messageIndex];
                              return _Appear(
                                key: ValueKey<int>(message.id),
                                fromUser: message.fromUser,
                                child: _MessageBubble(
                                  message: message,
                                  loadingVideo: _loadingVideoFor == message.id,
                                  onCopy: (text) =>
                                      _copy(context, text, 'Reply copied'),
                                  onReadAloud: _readAloud,
                                  onOpenResource: _openResource,
                                  onFindVideos: _cloudflareClient == null
                                      ? null
                                      : () => _findShortVideos(message),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (hasMessages) _FollowUpChips(enabled: !_busy, onPick: _send),
                if (_pendingAttachment case final attachment?)
                  _AttachmentPreview(
                    attachment: attachment,
                    remoteAvailable: _cloudflareClient != null,
                    onRemove: _removeScreenshot,
                  ),
                _Composer(
                  controller: _input,
                  focusNode: _focus,
                  busy: _busy,
                  hasAttachment: _pendingAttachment != null,
                  isListening: _isListening,
                  onPickScreenshot: _pickScreenshot,
                  onToggleListening: _toggleVoiceInput,
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
  const _ChatMessage(
    this.id,
    this.text, {
    this.fromUser = false,
    this.error = false,
    this.sources = const <String>[],
    this.resourceTopic,
    this.videos = const <TutorVideo>[],
  });

  final int id;
  final String text;
  final bool fromUser;
  final bool error;
  final List<String> sources;
  final String? resourceTopic;
  final List<TutorVideo> videos;

  _ChatMessage copyWith({List<TutorVideo>? videos}) => _ChatMessage(
    id,
    text,
    fromUser: fromUser,
    error: error,
    sources: sources,
    resourceTopic: resourceTopic,
    videos: videos ?? this.videos,
  );
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
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.5),
                      ),
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

Future<void> _copy(
  BuildContext context,
  String text,
  String confirmation,
) async {
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
  const _MessageBubble({
    required this.message,
    required this.loadingVideo,
    required this.onCopy,
    required this.onReadAloud,
    required this.onOpenResource,
    this.onFindVideos,
  });

  final _ChatMessage message;
  final bool loadingVideo;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onReadAloud;
  final ValueChanged<String> onOpenResource;
  final VoidCallback? onFindVideos;

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
        final lines = language == null
            ? code
            : code.substring(language.end).trimRight();
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

    final accent = message.error
        ? SkillBridgeColors.error
        : SkillBridgeColors.primary;
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
              gradient: message.error ? null : SkillBridgeColors.brandGradient,
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
                    if (!message.error &&
                        TutorVisualAid.supports(
                          message.resourceTopic ?? message.text,
                        ))
                      TutorVisualAid(
                        topic: message.resourceTopic ?? message.text,
                      ),
                    if (message.sources.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final source in message.sources)
                        _LearningSource(
                          url: source,
                          onTap: () => onOpenResource(source),
                        ),
                    ],
                    if (message.videos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final video in message.videos)
                        _VideoResource(
                          video: video,
                          onTap: () => onOpenResource(video.url),
                        ),
                    ],
                    if (!message.error && message.text.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MiniAction(
                                icon: Icons.volume_up_outlined,
                                label: 'Read aloud',
                                onTap: () => onReadAloud(message.text),
                              ),
                              if (onFindVideos != null)
                                _MiniAction(
                                  icon: loadingVideo
                                      ? Icons.hourglass_top_rounded
                                      : Icons.ondemand_video_outlined,
                                  label: loadingVideo
                                      ? 'Finding…'
                                      : 'Find a short video',
                                  onTap: loadingVideo ? null : onFindVideos,
                                ),
                              _MiniAction(
                                icon: Icons.copy_rounded,
                                label: 'Copy',
                                onTap: () => onCopy(message.text),
                              ),
                            ],
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

class _LearningSource extends StatelessWidget {
  const _LearningSource({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host;
    if (host != 'docs.python.org') return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.menu_book_outlined, size: 16),
        label: const Text('Python documentation'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.remoteAvailable,
    required this.onRemove,
  });

  final TutorAttachment attachment;
  final bool remoteAvailable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              attachment.bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              semanticLabel: 'Screenshot preview',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remoteAvailable
                  ? 'Screenshot ready. It is sent for analysis only when you send your question.'
                  : 'Screenshot stays on this device. Paste code or an error for offline help.',
              style: const TextStyle(
                color: SkillBridgeColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove screenshot',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _VideoResource extends StatelessWidget {
  const _VideoResource({required this.video, required this.onTap});

  final TutorVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(video.url)?.host;
    if (host != 'youtube.com' && host != 'www.youtube.com') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: SkillBridgeColors.codeSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: SkillBridgeColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SkillBridgeColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${video.channel} · Captions available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SkillBridgeColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: SkillBridgeColors.textMuted,
                ),
              ],
            ),
          ),
        ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: onTap != null,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 14,
                  color: SkillBridgeColors.textMuted,
                ),
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
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Colors.white,
            ),
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
    (
      Icons.unfold_more_rounded,
      'Explain more',
      'Can you explain that in more detail?',
    ),
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
              avatar: Icon(
                item.$1,
                size: 16,
                color: enabled
                    ? SkillBridgeColors.primary
                    : SkillBridgeColors.textMuted,
              ),
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
    required this.isListening,
    required this.onPickScreenshot,
    required this.onToggleListening,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool hasAttachment;
  final bool isListening;
  final VoidCallback onPickScreenshot;
  final VoidCallback onToggleListening;
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
                        color: SkillBridgeColors.primary.withValues(
                          alpha: 0.18,
                        ),
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
                  child: IconButton(
                    onPressed: busy ? null : onToggleListening,
                    tooltip: isListening ? 'Stop voice input' : 'Ask by voice',
                    style: IconButton.styleFrom(
                      foregroundColor: isListening
                          ? SkillBridgeColors.error
                          : SkillBridgeColors.textMuted,
                    ),
                    icon: Icon(
                      isListening ? Icons.stop_circle_outlined : Icons.mic_none,
                      size: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
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
