import 'dart:math';

import 'tutor_models.dart';

/// Answers tutor questions without any network round-trip.
///
/// The app is offline-first (the Python editor runs locally too), so the tutor
/// ships with a built-in brain: targeted explanations, worked examples, a
/// graded quiz, and debugging help. The interface (`ask`) is deliberately
/// async so the local tutor and optional streamed remote tutor share one UI.
class TutorService {
  TutorService({
    Random? random,
    TutorStudentContext? studentContext,
    TutorToolRegistry? tools,
    TutorRemoteChat? remote,
    TutorRemoteStream? remoteStream,
    this.teachingStyle = const TutorTeachingStyle(),
  }) : _random = random ?? Random(7),
       _studentContext = studentContext ?? TutorStudentContext.empty,
       _tools = tools, // ignore: prefer_initializing_formals
       _remote = remote, // ignore: prefer_initializing_formals
       _remoteStream = remoteStream; // ignore: prefer_initializing_formals

  final Random _random;
  TutorStudentContext _studentContext;
  TutorToolRegistry? _tools;

  /// Cloudflare-hosted language model. When set it answers first; the offline
  /// brain below is the fallback whenever it is unreachable.
  TutorRemoteChat? _remote;
  TutorRemoteStream? _remoteStream;
  final List<TutorChatTurn> _history = <TutorChatTurn>[];
  static const int _maxHistoryTurns = 10;
  final TutorTeachingStyle teachingStyle;

  TutorStudentContext get studentContext => _studentContext;

  void updateContext(
    TutorStudentContext context, {
    TutorToolRegistry? tools,
    TutorRemoteChat? remote,
    TutorRemoteStream? remoteStream,
  }) {
    _studentContext = context;
    _tools = tools;
    _remote = remote;
    _remoteStream = remoteStream;
  }

  void _remember(String question, String answer) {
    _history
      ..add(TutorChatTurn(fromUser: true, text: question))
      ..add(TutorChatTurn(fromUser: false, text: answer));
    while (_history.length > _maxHistoryTurns) {
      _history.removeAt(0);
    }
  }

  /// Why the last online attempt failed, or null if it succeeded (or there is
  /// no online tutor configured at all).
  String? _lastFailure;
  String? get lastFailure => _lastFailure;

  bool get canFindVideos => _tools?.canFindVideos == true;

  /// False while the device reports no network, so a learner never waits out a
  /// 35 second timeout before the offline answer appears.
  bool _remoteEnabled = true;

  void setRemoteEnabled(bool enabled) {
    if (_remoteEnabled == enabled) return;
    _remoteEnabled = enabled;
  }

  static const String offlineNotice =
      'I could not reach the online AI tutor just now, so this answer comes '
      'from the offline tutor.';

  /// Shown in the app bar so the learner knows what they are talking to.
  String get modeLabel {
    if (_remote == null && _remoteStream == null) {
      return _tools?.canLookupWeb == true
          ? 'Tutor + web tools'
          : 'Offline tutor';
    }
    if (!_remoteEnabled) return 'Offline tutor';
    return _lastFailure == null ? 'AI tutor (Cloudflare)' : 'Offline fallback';
  }

  /// Starts a genuinely new conversation: clears the turns sent to the model
  /// and any quiz answer still waiting to be graded.
  void resetConversation() {
    _history.clear();
    _pendingAnswer = null;
    _quizIndex = 0;
    _lastFailure = null;
  }

  static const _quiz = <_QuizQuestion>[
    _QuizQuestion(
      question:
          'Quick check 1/3: which loop keeps running while a condition '
          'is true?',
      options: ['for', 'while', 'print'],
      answerIndex: 1,
      afterCorrect:
          'Exactly — while is the condition loop. It re-checks the '
          'test on every pass and stops the moment it turns false.',
      afterWrong:
          'The answer is B) while. A for loop walks over a sequence; '
          'while only cares whether its condition is still true.',
    ),
    _QuizQuestion(
      question: 'Quick check 2/3: what does len("code") return?',
      options: ['4', '"code"', 'an error'],
      answerIndex: 0,
      afterCorrect:
          'Right — len() counts the characters, and "code" has '
          'four: c, o, d, e.',
      afterWrong:
          'The answer is A) 4. len() returns the number of items — '
          'characters in a string, elements in a list.',
    ),
    _QuizQuestion(
      question: 'Quick check 3/3: which keyword defines a function?',
      options: ['func', 'def', 'define'],
      answerIndex: 1,
      afterCorrect: 'Yes — def marks the start of a function. Nice run!',
      afterWrong:
          'The answer is B) def. Python defines functions with '
          'def name(parameters): followed by an indented body.',
    ),
  ];

  int _quizIndex = 0;
  int? _pendingAnswer;

  /// Answers [message] and keeps any trusted source metadata.
  Future<TutorReply> askReply(
    String message, {
    List<TutorAttachment> attachments = const <TutorAttachment>[],
  }) async {
    final m = message.trim().toLowerCase();
    _lastFailure = null;

    if (attachments.isNotEmpty) {
      final screenshotTool = _tools;
      if (screenshotTool?.canAnalyzeScreenshots == true) {
        _clearQuiz();
        final results = <TutorToolResult>[];
        for (final attachment in attachments) {
          results.add(
            await screenshotTool!.analyzeScreenshot(
              attachment,
              question: message.trim(),
              history: List<TutorChatTurn>.unmodifiable(_history),
            ),
          );
        }
        final text = results.map((result) => result.text).join('\n\n');
        _remember(message.trim(), text);
        return TutorReply(
          text: text,
          sources: <String>{for (final result in results) ...result.sources}
              .toList(growable: false),
        );
      }
      return TutorReply(
        text:
            'I received ${attachments.length == 1 ? 'the screenshot' : 'the screenshots'}, '
            'but image analysis needs a signed-in online tutor connection. '
            'You can paste the code or error text and I can help offline.',
      );
    }

    if ((m.contains('web') ||
            m.contains('latest') ||
            m.contains('search') ||
            m.contains('look up')) &&
        _tools?.canLookupWeb == true) {
      final result = await _tools!.lookupWeb(message.trim());
      return TutorReply(text: result.text, sources: result.sources);
    }

    // A short letter right after a quiz question is an answer, not a new
    // question.
    final letter = _answerLetter(m);
    if (letter != null && _pendingAnswer != null) {
      return TutorReply(text: _grade(letter));
    }

    final remote = _remote;
    if (remote != null && _remoteEnabled && m.isNotEmpty) {
      try {
        final reply = await remote(
          message: message.trim(),
          history: List<TutorChatTurn>.unmodifiable(_history),
          context: _studentContext,
          style: teachingStyle,
        );
        if (reply != null && reply.text.trim().isNotEmpty) {
          _clearQuiz();
          _remember(message.trim(), reply.text);
          return reply;
        }
      } catch (error) {
        // Fall through to the offline tutor, but remember why so the answer can
        // say it is a fallback instead of posing as the online model.
        _lastFailure = error is TutorException
            ? error.message
            : 'The online tutor is unavailable right now.';
      }
    }

    return TutorReply(text: _offlineReply(message));
  }

  /// Offline answer that is remembered for follow-ups and labelled honestly.
  String _offlineReply(String message) {
    final text = _askOffline(message);
    _remember(message.trim(), text);
    return _lastFailure == null ? text : '$offlineNotice\n\n$text';
  }

  /// Answers [message]. Never throws and never leaves the learner on read.
  Future<String> ask(
    String message, {
    List<TutorAttachment> attachments = const <TutorAttachment>[],
  }) async => (await askReply(message, attachments: attachments)).text;

  /// Streams the remote answer when available, then falls back to one complete
  /// offline answer if the request fails before the model sends any text.
  Stream<TutorStreamEvent> askStream(String message) async* {
    final cleanMessage = message.trim();
    final m = cleanMessage.toLowerCase();
    _lastFailure = null;
    final letter = _answerLetter(m);
    if (letter != null && _pendingAnswer != null) {
      yield TutorStreamEvent(text: _grade(letter));
      return;
    }

    final remote = _remoteStream;
    if (remote == null || cleanMessage.isEmpty || !_remoteEnabled) {
      yield TutorStreamEvent(text: (await askReply(cleanMessage)).text);
      return;
    }

    final output = StringBuffer();
    try {
      await for (final event in remote(
        message: cleanMessage,
        history: List<TutorChatTurn>.unmodifiable(_history),
        context: _studentContext,
        style: teachingStyle,
      )) {
        if (event.text.isNotEmpty) output.write(event.text);
        if (event.text.isNotEmpty || event.sources.isNotEmpty) yield event;
      }
    } catch (error) {
      _lastFailure = error is TutorException
          ? error.message
          : 'The online tutor is unavailable right now.';
      if (output.isNotEmpty) {
        _remember(cleanMessage, output.toString());
        yield const TutorStreamEvent(
          text: '\n\nThe connection paused. Please retry if the answer is incomplete.',
        );
        return;
      }
    }

    if (output.isNotEmpty) {
      _clearQuiz();
      _remember(cleanMessage, output.toString());
      return;
    }
    yield TutorStreamEvent(text: _offlineReply(cleanMessage));
  }

  Future<List<TutorVideo>> findShortVideos(String topic) async {
    final tools = _tools;
    if (tools?.canFindVideos != true) return const <TutorVideo>[];
    return tools!.findVideos(topic);
  }

  String _askOffline(String message) {
    final m = message.trim().toLowerCase();

    if (!_mentionsTopic(m) &&
        _matchesWord(m, const [
      'error',
      'errors',
      'crash',
      'crashing',
      'bug',
      'buggy',
      'fix',
      'fixing',
      'broken',
      'traceback',
      'exception',
      'not working',
      'wrong output',
      'debug',
    ])) {
      _clearQuiz();
      return 'Let us read the error like a detective:\n\n'
          '1. Go to the LAST line of the traceback — that names the real '
          'error (NameError, SyntaxError, TypeError...).\n'
          '2. Look just above it for the file and line number — that is where '
          'it happened.\n'
          '3. Check the classics: a misspelled variable (NameError), a '
          'missing colon or bracket (SyntaxError), or mixing incompatible '
          'types (TypeError).\n\n'
          '```python\n'
          '# Broken\n'
          "user = 'Ada'\n"
          "print(useer)   # NameError: name 'useer' is not defined\n\n"
          '# Fixed\n'
          'print(user)\n'
          '```\n'
          'Paste the last two lines of your error and I will pinpoint it.';
    }

    if (_isGreeting(m)) {
      _clearQuiz();
      final name = _studentContext.learnerName;
      final greeting = name == 'Learner' ? 'Hi!' : 'Hi, $name!';
      return '$greeting I am your Python tutor. I run right on your device, so I '
          'answer instantly even with no internet.\n\n'
          'Ask me about loops, strings, functions, lists, dictionaries or '
          'errors — or say "quiz me" and I will test what you know. '
          'I can also use your progress to target practice.';
    }

    if (m.contains('my progress') ||
        m.contains('my points') ||
        m.contains('weak point') ||
        m.contains('weakness')) {
      _clearQuiz();
      final weak = _studentContext.weakPoints.isEmpty
          ? 'You do not have a flagged weak point yet.'
          : 'The best places to practise next are: '
                '${_studentContext.weakPoints.join(', ')}.';
      return '${_studentContext.learnerName}, you have '
          '${_studentContext.totalPoints} points and have completed '
          '${_studentContext.progressLabel}. $weak\n\n'
          'I can explain one of those topics with a small example, then give '
          'you a short challenge.';
    }

    if (m.contains('quiz') || m.contains('test me') || m.contains('question')) {
      return _nextQuiz();
    }

    if (m.contains('challenge') ||
        m.contains('task of the day') ||
        m.contains('exercise for')) {
      _clearQuiz();
      return 'Today\u2019s challenge: FizzBuzz.\n\n'
          'Print the numbers 1 to 20. For multiples of 3 print "fizz", for '
          'multiples of 5 print "buzz", and for multiples of both print '
          '"fizzbuzz". Everything else prints the number itself.\n\n'
          '```python\n'
          'for n in range(1, 21):\n'
          '    # your logic here\n'
          '    print(n)\n'
          '```\n'
          'Run it in the editor and tell me your output — I will review it.';
    }

    if (m.contains('loop') ||
        m.contains('loops') ||
        m.contains('iterate') ||
        m.contains('iteration')) {
      _clearQuiz();
      return 'Two kinds of loop in Python: for and while.\n\n'
          'Use for when you know what you are walking over — a list, a '
          'string, range(10). Use while when you keep going until a '
          'condition flips.\n\n'
          '```python\n'
          "fruits = ['apple', 'banana']\n"
          'for fruit in fruits:\n'
          '    print(fruit)\n'
          '\n'
          'count = 0\n'
          'while count < 3:\n'
          '    print(count)\n'
          '    count += 1\n'
          '```\n'
          'Rule of thumb: can you name the collection? Use for. Waiting on a '
          'condition? Use while — and make sure something inside the loop '
          'changes that condition, or it never stops.';
    }

    if (m.contains('function') ||
        m.contains('functions') ||
        m.startsWith('def')) {
      _clearQuiz();
      return 'A function is a named block of code you can run again and '
          'again. Define it with def, pass values in as parameters, and send '
          'results back with return.\n\n'
          '```python\n'
          'def greet(name):\n'
          "    return f'Hello, {name}!'\n"
          '\n'
          "message = greet('Ada')\n"
          'print(message)\n'
          '```\n'
          'Keep each function to one job with a clear name — small functions '
          'are easy to test and reuse.';
    }

    if (m.contains('string') ||
        m.contains('strings') ||
        m.contains('f-string') ||
        m.contains('quote')) {
      _clearQuiz();
      return 'Text lives in strings — quotes make one. Strings slice, count '
          'and transform, and f-strings embed variables directly.\n\n'
          '```python\n'
          "name = 'Ada'\n"
          "greeting = f'Hello, {name}!'\n"
          'print(greeting[0])     # first character\n'
          'print(len(greeting))   # length\n'
          'print(greeting.upper())\n'
          '```\n'
          'The f before the quote is the modern way to put variables into '
          'text. Indexes start at 0, so greeting[0] is the H.';
    }

    if (_matchesWord(m, const ['list', 'lists', 'append', 'array'])) {
      _clearQuiz();
      return 'A list is an ordered collection you can grow and shrink.\n\n'
          '```python\n'
          'scores = [90, 75, 88]\n'
          'scores.append(100)\n'
          'print(scores[0])     # first item — indexes start at 0\n'
          'print(len(scores))\n'
          'for score in scores:\n'
          '    print(score)\n'
          '```\n'
          'Square brackets create a list, append() adds to the end, and a '
          'for loop walks every item in order.';
    }

    if (_matchesWord(m, const ['dict', 'dictionary', 'key-value', 'key value'])) {
      _clearQuiz();
      return 'A dictionary stores pairs: a key that points to a value.\n\n'
          '```python\n'
          "student = {'name': 'Ada', 'xp': 120}\n"
          "print(student['name'])\n"
          "student['xp'] += 10\n"
          'for key, value in student.items():\n'
          '    print(key, value)\n'
          '```\n'
          'Use brackets to read or write a key, .get(key) when the key might '
          'be missing, and .items() to loop over the pairs.';
    }

    if (m.contains('if statement') ||
        m.contains('condition') ||
        m.contains('conditions') ||
        _matchesWord(m, const ['else']) ||
        m.contains('boolean') ||
        m.contains('compare')) {
      _clearQuiz();
      return 'Conditions let your program choose a path with if / elif / '
          'else. Python compares with ==, !=, <, >, <=, >= and combines with '
          'and, or, not.\n\n'
          '```python\n'
          'score = 85\n'
          'if score >= 90:\n'
          "    print('distinction')\n"
          'elif score >= 50:\n'
          "    print('pass')\n"
          'else:\n'
          "    print('try again')\n"
          '```\n'
          'Indentation is part of the syntax — the indented block is what '
          'runs when the condition is true.';
    }

    if (m.contains('variable') ||
        m.contains('variables') ||
        m.contains('assign') ||
        m.contains('datatype') ||
        RegExp(r'\bint\b').hasMatch(m) ||
        RegExp(r'\bfloat\b').hasMatch(m)) {
      _clearQuiz();
      return 'A variable is a name for a value. Python infers the type from '
          'what you assign — no declaration needed.\n\n'
          '```python\n'
          'age = 14          # int\n'
          'pi = 3.14         # float\n'
          "name = 'Ada'      # string\n"
          'ready = True      # bool\n'
          'age = age + 1     # names can be reassigned\n'
          '```\n'
          'Use snake_case for names and avoid keywords like if, for and '
          'def.';
    }

    if (m.contains('input(') ||
        m.contains('user input') ||
        m.contains('read input')) {
      _clearQuiz();
      return 'input() pauses the program, reads a line from the user, and '
          'returns it as a string.\n\n'
          '```python\n'
          "name = input('What is your name? ')\n"
          "age = int(input('How old are you? '))  # convert to a number\n"
          "print(f'Next year you turn {age + 1}')\n"
          '```\n'
          'Everything from input() is text — wrap it in int() or float() '
          'when you need to do math.';
    }

    // Nothing matched: be useful anyway.
    _clearQuiz();
    const fallbacks = <String>[
      'I can help with Python fundamentals — loops, strings, functions, '
          'lists, dictionaries, conditions and debugging errors. Try one of the '
          'starter cards, ask something specific, or say "quiz me".',
      'That one is outside my offline brain for now. I am strongest on the '
          'basics: loops, strings, functions, lists, dictionaries, conditions '
          'and fixing errors. Which of those do you want to work through?',
      'Hmm, I do not have a prepared answer for that yet. Ask me about loops, '
          'strings, functions, lists, dictionaries or errors — or say "quiz me" '
          'for a quick check.',
    ];
    return fallbacks[_random.nextInt(fallbacks.length)];
  }

  /// Greetings are matched as whole (or leading) phrases so that messages
  /// like "which loop..." or "your code has a bug" never trigger them.
  bool _isGreeting(String m) {
    const exact = <String>{
      'hi',
      'hello',
      'hey',
      'yo',
      'hiya',
      'salam',
      'help',
      'help me',
      'who are you',
      'what are you',
      'what can you do',
      'how do you work',
      'good morning',
      'good afternoon',
      'good evening',
    };
    if (exact.contains(m)) return true;
    // A greeting must be a greeting: "hi, how do while loops work?" is a
    // question, and treating it as a hello threw the real question away.
    if (m.length > 32 || m.contains('?')) return false;
    const starters = <String>[
      'hello',
      'hey',
      'hi',
      'hiya',
      'yo',
      'salam',
      'good morning',
      'good afternoon',
      'good evening',
      'what can you do',
    ];
    for (final starter in starters) {
      if (!m.startsWith(starter)) continue;
      final rest = m
          .substring(starter.length)
          .replaceAll(RegExp(r'^[\s,!.:;-]*'), '')
          .trim();
      return rest.isEmpty;
    }
    return false;
  }

  String _nextQuiz() {
    final q = _quiz[_quizIndex % _quiz.length];
    _quizIndex++;
    _pendingAnswer = q.answerIndex;
    return '${q.question}\n\n'
        'A) ${q.options[0]}\n'
        'B) ${q.options[1]}\n'
        'C) ${q.options[2]}\n\n'
        'Reply with A, B or C.';
  }

  String _grade(int letter) {
    final q = _quiz[(_quizIndex - 1 + _quiz.length) % _quiz.length];
    final correct = letter == _pendingAnswer;
    _pendingAnswer = null;
    if (correct) {
      return 'Correct! ${q.afterCorrect}\n\n'
          'Say "quiz me" for another, or ask about any topic.';
    }
    return 'Not quite. ${q.afterWrong}\n\n'
        'Say "quiz me" to try the next one, or ask me to explain the topic.';
  }

  /// Maps a bare answer ("b", "2", "answer: a") to its option index.
  int? _answerLetter(String m) {
    if (m.isEmpty) return null;
    final cleaned = m
        .replaceAll(RegExp(r'^answer\s*(is)?\s*[:\-]?\s*'), '')
        .replaceAll(RegExp(r'^[\(\[\s]+|[\)\]\s.,!?]+$'), '')
        .trim();
    if (cleaned.length != 1) return null;
    final c = cleaned.codeUnitAt(0);
    if (c >= 97 && c <= 99) return c - 97; // a/b/c
    if (c >= 49 && c <= 51) return c - 49; // 1/2/3
    return null;
  }

  /// Whole-word/phrase match. Plain `contains` made "prefix" a debugging
  /// question, "listen" a list question and "addict" a dictionary question.
  bool _matchesWord(String m, List<String> phrases) => phrases.any(
    (phrase) => RegExp(
      '(^|[^a-z0-9_])${RegExp.escape(phrase)}([^a-z0-9_]|\$)',
    ).hasMatch(m),
  );

  static const _topicWords = <String>[
    'loop',
    'loops',
    'for',
    'while',
    'function',
    'functions',
    'def',
    'string',
    'strings',
    'list',
    'lists',
    'append',
    'dict',
    'dictionary',
    'condition',
    'conditions',
    'if',
    'else',
    'variable',
    'variables',
    'input',
    'quiz',
    'challenge',
  ];

  /// True when the message names a topic the offline tutor can teach, so the
  /// generic debugging answer does not pre-empt the specific one.
  bool _mentionsTopic(String m) => _matchesWord(m, _topicWords);

  void _clearQuiz() {
    _pendingAnswer = null;
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.afterCorrect,
    required this.afterWrong,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String afterCorrect;
  final String afterWrong;
}
