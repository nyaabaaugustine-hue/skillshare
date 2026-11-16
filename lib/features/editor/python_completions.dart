import 'python_vocabulary.dart';

/// What a suggestion is, which decides how it is labelled in the strip.
enum CompletionKind { name, builtin, keyword }

/// One entry in the editor's completion strip.
class PythonCompletion {
  const PythonCompletion({
    required this.label,
    required this.kind,
    this.insert,
    this.caretBack = 0,
  });

  /// Text shown on the chip.
  final String label;

  final CompletionKind kind;

  /// Text that replaces the partial word. Defaults to [label].
  final String? insert;

  /// How far the caret sits from the end of the inserted text. Used to land
  /// inside `print(|)` after completing a call.
  final int caretBack;

  String get text => insert ?? label;
}

/// A completion request resolved against a source buffer.
class CompletionMatch {
  const CompletionMatch({
    required this.start,
    required this.end,
    required this.items,
  });

  /// Range of the partial word being typed, in source offsets.
  final int start;
  final int end;

  final List<PythonCompletion> items;

  bool get isEmpty => items.isEmpty;
}

/// Computes context-aware completions for the identifier being typed at
/// [cursor] in [source].
///
/// Scope is intentionally narrow and predictable: Python keywords, the curated
/// built-ins, and names the learner already introduced in this exercise. It does
/// not attempt full semantic analysis — an offline phone editor that guesses
/// wrongly is worse than one that stays quiet.
class PythonCompletions {
  const PythonCompletions();

  static final RegExp _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*$');

  /// Names bound in [source]: assignments, `def`, `for ... in`, imports and
  /// `with ... as`. Ordered by first appearance so earlier names win ties.
  static List<String> boundNames(String source) {
    final found = <String>[];
    void add(String? name) {
      if (name == null || name.isEmpty) return;
      if (isPythonKeyword(name)) return;
      if (!found.contains(name)) found.add(name);
    }

    for (final match in RegExp(
      r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:,\s*[A-Za-z_][A-Za-z0-9_]*\s*)*=[^=]',
      multiLine: true,
    ).allMatches(source)) {
      add(match.group(1));
    }
    for (final match in RegExp(
      r'\bdef\s+([A-Za-z_][A-Za-z0-9_]*)',
    ).allMatches(source)) {
      add(match.group(1));
    }
    for (final match in RegExp(
      r'\bfor\s+([A-Za-z_][A-Za-z0-9_]*)'
      r'(?:\s*,\s*([A-Za-z_][A-Za-z0-9_]*))*\s+in\b',
    ).allMatches(source)) {
      add(match.group(1));
      add(match.group(2));
    }
    for (final match in RegExp(
      r'\bimport\s+([A-Za-z_][A-Za-z0-9_]*)'
      r'|\bas\s+([A-Za-z_][A-Za-z0-9_]*)'
      r'|\bfrom\s+([A-Za-z_][A-Za-z0-9_]*)\s+import',
    ).allMatches(source)) {
      add(match.group(1));
      add(match.group(2));
      add(match.group(3));
    }
    for (final match in RegExp(
      r'\bdef\s+[A-Za-z_][A-Za-z0-9_]*\s*\(([^)]*)\)',
    ).allMatches(source)) {
      for (final param in match.group(1)!.split(',')) {
        final name = param.split('=').first.trim();
        if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) add(name);
      }
    }
    return found;
  }

  /// True when [cursor] sits inside a string literal or after a `#` comment on
  /// the same line, where identifier completion would only add noise.
  static bool inStringOrComment(String source, int cursor) {
    final lineStart = cursor == 0
        ? 0
        : source.lastIndexOf('\n', cursor - 1) + 1;
    var quote = '';
    for (var i = lineStart; i < cursor; i++) {
      final ch = source[i];
      if (quote.isEmpty) {
        if (ch == '#') return true;
        if (ch == '"' || ch == "'") quote = ch;
      } else if (ch == quote) {
        quote = '';
      }
    }
    return quote.isNotEmpty;
  }

  /// Resolves the completions that apply at [cursor].
  CompletionMatch completionsAt(
    String source, {
    required int cursor,
    int limit = 8,
  }) {
    if (cursor < 0 || cursor > source.length) {
      return CompletionMatch(start: cursor, end: cursor, items: const []);
    }
    final before = source.substring(0, cursor);
    final partial = _identifier.firstMatch(before)?.group(0) ?? '';
    final start = cursor - partial.length;

    // No prefix, inside a string, or immediately after a dot (attribute access)
    // is outside what this lightweight completer can answer safely.
    if (partial.isEmpty) {
      return CompletionMatch(start: start, end: cursor, items: const []);
    }
    if (inStringOrComment(source, cursor)) {
      return CompletionMatch(start: start, end: cursor, items: const []);
    }
    if (start > 0 && source[start - 1] == '.') {
      return CompletionMatch(start: start, end: cursor, items: const []);
    }

    final lower = partial.toLowerCase();
    final scored = <(int, int, PythonCompletion)>[];

    final names = boundNames(source);
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      if (name == partial) continue;
      if (!name.toLowerCase().startsWith(lower)) continue;
      scored.add((
        0,
        i,
        PythonCompletion(label: name, kind: CompletionKind.name),
      ));
    }
    for (var i = 0; i < pythonBuiltins.length; i++) {
      final name = pythonBuiltins[i];
      if (name == partial) continue;
      if (!name.toLowerCase().startsWith(lower)) continue;
      final callable = pythonCallables.contains(name);
      scored.add((
        1,
        i,
        PythonCompletion(
          label: name,
          kind: CompletionKind.builtin,
          insert: callable ? '$name()' : name,
          caretBack: callable ? 1 : 0,
        ),
      ));
    }
    for (var i = 0; i < pythonKeywords.length; i++) {
      final name = pythonKeywords[i];
      if (name == partial) continue;
      if (!name.toLowerCase().startsWith(lower)) continue;
      scored.add((
        2,
        i,
        PythonCompletion(
          label: name,
          kind: CompletionKind.keyword,
          insert: pythonBlockKeywords.contains(name) ? '$name ' : name,
        ),
      ));
    }

    scored.sort((a, b) {
      final byKind = a.$1.compareTo(b.$1);
      if (byKind != 0) return byKind;
      final byLength = a.$3.label.length.compareTo(b.$3.label.length);
      if (byLength != 0) return byLength;
      return a.$2.compareTo(b.$2);
    });

    return CompletionMatch(
      start: start,
      end: cursor,
      items: scored.take(limit).map((e) => e.$3).toList(growable: false),
    );
  }
}
