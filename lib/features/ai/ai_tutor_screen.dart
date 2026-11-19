import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// typing indicator while the tutor thinks. [TutorService] streams online
/// answers when configured and keeps the offline tutor available as fallback.
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

  /// Set when the last send used the offline tutor, and cleared by the next
  /// attempt. Shown as a banner so a fallback is never mistaken for the model.
  String? _notice;
  bool _videosUnavailable = false;
  bool _speaking = false;
  StreamSubscription<bool>? _connectivitySub;

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
    final base = deps.config.aiTutorEndpoint;
    if (base.isNotEmpty &&
        auth.cloudAuthEnabled &&
        session?.isAccount == true &&
        session?.role == UserRole.student &&
        session?.token?.isNotEmpty == true) {
      final client = CloudflareTutorClient(
        baseUrl: base,
        // Refreshes the short-lived JWT when it is about to expire or the
        // Worker rejected it, instead of reusing the sign-in token forever.
        accessTokenProvider: ({bool forceRefresh = false}) =>
            auth.tutorAccessToken(forceRefresh: forceRefresh),
      );
      _cloudflareClient = client;
      remote = client.chat;
      remoteStream = client.chatStream;
    }

    var contextData = TutorStudentContext(
      learnerName: session?.displayName ?? 'Learner',
      totalPoints: null,
      completedChallenges: 0,
      totalChallenges: 0,
      weakPoints: const <String>[],
      recentScores: const <String, int>{},
    );
    try {
      // Progress is stored per device. If a different account has signed in on
      // this device, do not send the earlier learner's weak points and scores
      // to the AI (or show them back to the new learner).
      if (await _contextBelongsToAccount(auth, deps.learnerRef)) {
        final progress = await deps.lmsClient.fetchProgress();
        final report = GuardianReport.build(
          course: pythonKickstartCourse,
          history: deps.courseProgress.history(deps.learnerRef),
        );
        contextData = TutorStudentContext.fromRecords(
          learnerName: auth.session?.displayName ?? 'Learner',
          progress: progress,
          report: report,
          // Mock LMS points reset every launch; never state them as real.
          pointsAreServerAuthoritative: !deps.config.useMockLms,
        );
      }
    } catch (error) {
      debugPrint(
        'Tutor progress context unavailable; continuing without progress.',
      );
    }

    // Skip the network entirely while the device reports no connection, so the
    // learner gets the offline answer instead of waiting out a timeout.
    _connectivitySub ??= deps.connectivity.onChanged.listen(
      _service.setRemoteEnabled,
    );
    _service.setRemoteEnabled(deps.connectivity.isOnline);

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

  /// Ties this device's local learner id to the first account that used the
  /// tutor here, so a shared device cannot leak context between accounts.
  Future<bool> _contextBelongsToAccount(
    AuthController auth,
    String learnerRef,
  ) async {
    final email = auth.session?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tutor.contextOwner.$learnerRef';
      final owner = prefs.getString(key);
      if (owner == null || owner.isEmpty) {
        await prefs.setString(key, email);
        return true;
      }
      return owner == email;
    } catch (_) {
      // If the scope cannot be read, withholding context is the safe choice.
      return false;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _cloudflareClient?.close();
    unawaited(_connectivitySub?.cancel());
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
    final attachment = _pendingAttachment;
    // A screenshot on its own is a valid question.
    if (_busy || (text.isEmpty && attachment == null)) return;
    final message = text.isEmpty
        ? 'Explain the Python code or error in this image.'
        : text;
    // The Worker reads at most 1500 characters. Trim before showing the bubble
    // so what the learner sees and what the model reads are the same text.
    final trimmed = message.length > 1500
        ? message.substring(0, 1500)
        : message;
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
    if (trimmed.length != message.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Long message trimmed to 1500 characters for the tutor.',
          ),
        ),
      );
    }
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_message(trimmed, fromUser: true));
      _busy = true;
      _streamHasStarted = false;
      _input.clear();
      _pendingAttachment = null;
      _notice = null;
    });
    _scrollToLatest();
    try {
      if (!mounted) return;
      if (attachment != null) {
        final reply = await _service.askReply(
          trimmed,
          attachments: <TutorAttachment>[attachment],
        );
        if (!mounted) return;
        setState(
          () => _messages.add(
            _message(
              reply.text,
              sources: reply.sources,
              resourceTopic: trimmed,
            ),
          ),
        );
      } else {
        final replyId = _nextId++;
        final answer = StringBuffer();
        final sources = <String>[];
        await for (final event in _service.askStream(trimmed)) {
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
              resourceTopic: trimmed,
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
        // One tap should retry the same question and screenshot.
        _input.text = trimmed;
        _pendingAttachment = attachment;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _streamHasStarted = false;
          _notice = _service.lastFailure;
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
    if (_speaking) {
      await _textToSpeech.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final speechText = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' code example omitted ')
        .replaceAll(RegExp(r'https://\S+'), ' link ')
        .trim();
    if (speechText.isEmpty) return;
    try {
      await _textToSpeech.stop();
      await _textToSpeech.setLanguage('en-US');
      await _textToSpeech.setSpeechRate(0.45);
      await _textToSpeech.awaitSpeakCompletion(true);
      if (mounted) setState(() => _speaking = true);
      await _textToSpeech.speak(speechText);
      if (mounted) setState(() => _speaking = false);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
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
      setState(() {
        _loadingVideoFor = null;
        // The Worker reports 503 until video search is configured; stop
        // offering a button that can never succeed this session.
        _videosUnavailable = true;
      });
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
    // Clearing the bubbles alone left the previous turns in the model's
    // context and any quiz answer still pending.
    _service.resetConversation();
    setState(() {
      _messages.clear();
      _pendingAttachment = null;
      _notice = null;
      _videosUnavailable = false;
    });
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
    final compactHeader = MediaQuery.sizeOf(context).width < 420;
    final mode = _notice != null
        ? 'Fallback'
        : _service.modeLabel.contains('Cloudflare')
        ? 'Online'
        : 'Offline';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SkillBridgeColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SkillBridgeColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.code_rounded,
                color: SkillBridgeColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI Tutor'),
                if (!compactHeader)
                  Text(
                    'Python tutor',
                    style: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (hasMessages)
            IconButton(
              tooltip: 'New chat',
              onPressed: _busy ? null : _clearChat,
              icon: const Icon(Icons.add_comment_rounded, size: 22),
            ),
          Tooltip(
            message: mode,
            child: Semantics(
              label: 'Tutor connection: $mode',
              child: Container(
                margin: const EdgeInsets.only(right: 14, left: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appColors.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode == 'Online'
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: mode == 'Online'
                          ? SkillBridgeColors.primary
                          : context.appColors.textMuted,
                      size: 14,
                    ),
                    if (!compactHeader) ...[
                      const SizedBox(width: 6),
                      Text(
                        mode,
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                                  onFindVideos:
                                      _cloudflareClient == null ||
                                          _videosUnavailable
                                      ? null
                                      : () => _findShortVideos(message),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (hasMessages) _FollowUpChips(enabled: !_busy, onPick: _send),
                if (_notice case final notice?) _TutorNotice(message: notice),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 18 : 24),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.appColors.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PYTHON PARTNER',
                            style: TextStyle(
                              color: SkillBridgeColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: "Let's learn\n"),
                                TextSpan(
                                  text: 'Python.',
                                  style: TextStyle(
                                    color: SkillBridgeColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 30,
                              height: 1.04,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            compact
                                ? 'Ask a question. Learn one step at a time.'
                                : 'Bring a question, a bug, or a new idea. We will work through it together.',
                            style: TextStyle(
                              color: context.appColors.textMuted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 20),
                    CodeBuddy(
                      size: compact ? 82 : 122,
                      mood: BuddyMood.thinking,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Start with a topic',
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _PromptCard(
                icon: Icons.sync_rounded,
                title: 'Explain loops',
                subtitle: 'A clear guide to for and while',
                featured: true,
                onTap: enabled
                    ? () => onPick('Explain for and while loops simply')
                    : null,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _PromptCard(
                    icon: Icons.quiz_outlined,
                    title: 'Quiz me',
                    onTap: enabled ? () => onPick('Quiz me') : null,
                  ),
                  _PromptCard(
                    icon: Icons.build_outlined,
                    title: 'Fix my code',
                    onTap: enabled
                        ? () => onPick('Help me fix this Python error')
                        : null,
                  ),
                  _PromptCard(
                    icon: Icons.bolt_outlined,
                    title: 'Challenge',
                    onTap: enabled
                        ? () =>
                              onPick('Give me a fun Python challenge for today')
                        : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: title,
      child: Pressable(
        enabled: onTap != null,
        child: Material(
          color: featured
              ? SkillBridgeColors.primary.withValues(alpha: 0.10)
              : context.appColors.surfaceHigh,
          borderRadius: BorderRadius.circular(featured ? 18 : 14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(featured ? 18 : 14),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: featured ? 16 : 14,
                vertical: featured ? 15 : 11,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(featured ? 18 : 14),
                border: Border.all(
                  color: featured
                      ? SkillBridgeColors.primary.withValues(alpha: 0.32)
                      : context.appColors.outline,
                ),
              ),
              child: Row(
                mainAxisSize: featured ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: featured ? 21 : 18,
                    color: SkillBridgeColors.primary,
                  ),
                  const SizedBox(width: 11),
                  if (featured)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle case final value?) ...[
                            const SizedBox(height: 3),
                            Text(
                              value,
                              style: TextStyle(
                                color: context.appColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (!featured)
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Icon(
                    featured
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_outward_rounded,
                    color: featured
                        ? SkillBridgeColors.primary
                        : context.appColors.textMuted,
                    size: featured ? 18 : 15,
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
                    : context.appColors.textPrimary,
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
              color: SkillBridgeColors.primaryDeep,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
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
        : context.appColors.outline;
    final bgColor = message.error
        ? SkillBridgeColors.error.withValues(alpha: 0.08)
        : context.appColors.surface;

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
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
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

/// A single honest line explaining that the answer came from the offline
/// tutor, rather than a normal reply from the model.
class _TutorNotice extends StatelessWidget {
  const _TutorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: SkillBridgeColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SkillBridgeColors.accent.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: SkillBridgeColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.outline),
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
              style: TextStyle(
                color: context.appColors.textMuted,
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
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${video.channel} · Captions available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: context.appColors.textMuted,
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
              Icon(icon, size: 14, color: context.appColors.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: context.appColors.textMuted,
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
        border: Border.all(color: context.appColors.outline),
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
                Icon(
                  Icons.terminal_rounded,
                  size: 14,
                  color: context.appColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'PYTHON',
                  style: TextStyle(
                    color: context.appColors.textMuted,
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
              style: TextStyle(
                color: context.appColors.textPrimary,
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
              color: context.appColors.surfaceHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: context.appColors.outline),
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
                    : context.appColors.textMuted,
              ),
              label: Text(item.$2),
              labelStyle: TextStyle(
                color: enabled
                    ? context.appColors.textPrimary
                    : context.appColors.textMuted,
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
      decoration: BoxDecoration(
        color: context.appColors.background,
        border: Border(top: BorderSide(color: context.appColors.outline)),
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
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused
                    ? SkillBridgeColors.primary
                    : context.appColors.outline,
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
                          : context.appColors.textMuted,
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
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 15,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask about loops, errors, quizzes\u2026',
                        hintStyle: TextStyle(
                          color: context.appColors.textMuted,
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
                          : context.appColors.textMuted,
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
                            : context.appColors.surfaceHigh,
                        foregroundColor: ready
                            ? SkillBridgeColors.onPrimary
                            : context.appColors.textMuted,
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
