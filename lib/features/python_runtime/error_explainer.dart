import '../editor/python_vocabulary.dart';
import 'execution_result.dart';

/// A plain-language explanation of a Python error, written for a beginner.
///
/// Three parts, in the order a learner needs them: what Python noticed, why it
/// happened, and one concrete thing to try next. The raw message and traceback
/// stay available in the console's "Details" section — this is the layer on top.
class ErrorExplanation {
  const ErrorExplanation({
    required this.headline,
    required this.why,
    required this.nextStep,
    this.line,
  });

  /// One short sentence naming the mistake, e.g. "A colon is missing".
  final String headline;

  /// Why Python complained.
  final String why;

  /// The single most useful thing to try next.
  final String nextStep;

  /// 1-based line, when the runtime reported one.
  final int? line;

  /// "Line 4" or an empty string.
  String get lineLabel => line == null ? '' : 'Line $line';
}

/// Maps a raw [ExecutionException] onto an [ErrorExplanation].
///
/// The matching is intentionally message-driven (not a parser replacement):
/// CPython's own wording is stable enough in practice, and a wrong-but-plausible
/// explanation is worse for a beginner than none. Anything unrecognised falls
/// back to the message itself.
class PythonErrorExplainer {
  const PythonErrorExplainer();

  ErrorExplanation explain(ExecutionException error, {String source = ''}) {
    final type = error.type;
    final message = error.message;
    final lower = message.toLowerCase();
    final line = error.line;
    final sourceLine = _lineText(source, line);

    switch (type) {
      case 'SyntaxError':
        return _syntax(error, lower, sourceLine);
      case 'IndentationError':
      case 'TabError':
        return _indentation(error, lower);
      case 'NameError':
        return _name(error, source);
      case 'UnboundLocalError':
        return _unbound(message, line);
      case 'TypeError':
        return _type(error, lower, line);
      case 'ValueError':
        return _value(error, lower, line);
      case 'ZeroDivisionError':
        return ErrorExplanation(
          line: line,
          headline: 'You divided by zero',
          why:
              'Python cannot split something into 0 pieces, so the program '
              'stops on the line with the / or // sign.',
          nextStep:
              'Check the value on the right of the division. If it comes '
              'from input() or a calculation, guard it with '
              '`if divisor != 0:` before dividing.',
        );
      case 'IndexError':
        return ErrorExplanation(
          line: line,
          headline: 'You asked for an item that is not in the list',
          why:
              'Counting starts at 0, so a list with 3 items only has '
              'positions 0, 1 and 2.',
          nextStep:
              'Print `len(your_list)` and compare it with the index you '
              'asked for. Use `-1` for the last item instead of counting '
              'backwards by hand.',
        );
      case 'KeyError':
        return _key(message, line);
      case 'AttributeError':
        return _attribute(message, line);
      case 'ModuleNotFoundError':
      case 'ImportError':
        return _import(message, line);
      case 'EOFError':
        return ErrorExplanation(
          line: line,
          headline: 'Your program wanted more input',
          why:
              'input() asked for a value, but no more typed answers were '
              'waiting.',
          nextStep:
              'Add a sample input in the exercise’s Input panel, or '
              'test with a fixed value first, then swap input() back in.',
        );
      case 'RecursionError':
        return ErrorExplanation(
          line: line,
          headline: 'A function keeps calling itself',
          why:
              'The function calls itself without ever reaching a case that '
              'stops it.',
          nextStep:
              'Add a stopping condition at the top of the function, for '
              'example `if n <= 0: return`.',
        );
      case 'TimeoutError':
        return ErrorExplanation(
          line: line,
          headline: 'Your program took too long',
          why: 'It was stopped so it could not freeze the editor.',
          nextStep:
              'Look for a loop whose condition never becomes false, and '
              'make sure the variable it checks is updated inside the loop.',
        );
      default:
        return ErrorExplanation(
          headline: 'Python stopped with a $type',
          why: message.isEmpty ? 'It did not give any more detail.' : message,
          nextStep:
              'Read the last line of the details below: it names the '
              'line and the value Python was unhappy with.',
          line: line,
        );
    }
  }

  // --- Syntax -------------------------------------------------------------

  ErrorExplanation _syntax(
    ExecutionException error,
    String lower,
    String sourceLine,
  ) {
    final line = error.line;

    if (lower.contains("expected ':'")) {
      return ErrorExplanation(
        line: line,
        headline: 'A colon is missing',
        why:
            'Lines that open a block with if, for, while, def, class, else, '
            'elif, try or except must end with a colon (:).',
        nextStep:
            'Put `:` at the end of the line, for example '
            '`if score > 10:`.',
      );
    }

    if (lower.contains('was never closed')) {
      final opener = RegExp(r"'([\(\[\{])'")
          .firstMatch(error.message)
          ?.group(1);
      return ErrorExplanation(
        line: line,
        headline: 'A bracket or quote was opened and never closed',
        why: opener == null
            ? 'Every ( [ { and every quote needs a matching partner on the '
                  'same statement.'
            : 'A `$opener` was opened here and Python reached the end of the '
                  'file without finding the closing partner.',
        nextStep:
            'Count the pairs on this line. The editor already closes '
            'brackets for you, so the usual cause is deleting one half.',
      );
    }

    if (lower.contains('unexpected eof') ||
        lower.contains('unexpected end of file')) {
      return ErrorExplanation(
        line: line,
        headline: 'The file ended in the middle of a statement',
        why:
            'Python was still expecting more code — often an unclosed '
            'bracket, quote or block.',
        nextStep:
            'Check the last block you typed for a missing )(, quote or '
            'colon, and that `if`/`for`/`def` blocks have an indented body.',
      );
    }

    if (lower.contains('invalid decimal literal') ||
        lower.contains('leading zeros')) {
      return ErrorExplanation(
        line: line,
        headline: 'A number is written in a way Python cannot read',
        why:
            'Whole numbers cannot start with an unnecessary 0 (write 7, not '
            '07), and a decimal point needs digits on both sides.',
        nextStep:
            'Rewriting the number without leading zeros usually fixes '
            'this.',
      );
    }

    if (lower.contains('cannot assign to')) {
      return ErrorExplanation(
        line: line,
        headline: 'You compared where Python expected an assignment',
        why: 'A single `=` stores a value; `==` compares two values.',
        nextStep: 'If you meant to compare, change `=` to `==`.',
      );
    }

    if (lower.contains("expected 'except' or 'finally'")) {
      return ErrorExplanation(
        line: line,
        headline: 'The try block is missing its except or finally',
        why:
            'A `try:` must be followed by at least one `except:` or a '
            '`finally:`.',
        nextStep:
            'Add `except Exception as error:` under the try block, '
            'indented to match.',
      );
    }

    // Generic syntax error: read the offending line for the usual suspects.
    final firstWord = sourceLine.trim().split(RegExp(r'\s+')).first;
    if (pythonBlockKeywords.contains(firstWord) && !sourceLine.contains(':')) {
      return ErrorExplanation(
        line: line,
        headline: 'A colon is missing',
        why:
            '`$firstWord` starts a block, and every block header ends with '
            'a colon.',
        nextStep: 'Add `:` at the end of the line.',
      );
    }

    if (_hasSingleEqualsComparison(sourceLine)) {
      return ErrorExplanation(
        line: line,
        headline: 'A comparison used a single =',
        why:
            'Inside `if`, `while` or `elif`, comparing needs `==`; one `=` '
            'tries to store a value and Python will not allow that there.',
        nextStep: 'Change the single `=` to `==`.',
      );
    }

    if (sourceLine.trimRight().endsWith(':')) {
      return ErrorExplanation(
        line: line,
        headline: 'Python could not read this line',
        why: 'The line opens a block, but what follows it is not valid.',
        nextStep:
            'Check the words after the colon — a block keyword needs a '
            'condition or a name before the `:`.',
      );
    }

    if (_hasUnbalancedQuote(sourceLine)) {
      return ErrorExplanation(
        line: line,
        headline: 'A quote is opened and not closed',
        why: 'Text must start and end with the same quote character.',
        nextStep:
            'Close the piece of text with the same quote you opened it '
            'with.',
      );
    }

    return ErrorExplanation(
      line: line,
      headline: 'Python could not read this line',
      why: error.message.isEmpty
          ? 'The line does not follow Python’s spelling rules.'
          : error.message,
      nextStep:
          'Check the end of the line for a missing colon, bracket or '
          'quote, and look one line above too — an unclosed bracket on the '
          'line before shows up here.',
    );
  }

  // --- Indentation --------------------------------------------------------

  ErrorExplanation _indentation(ExecutionException error, String lower) {
    final line = error.line;
    if (lower.contains('expected an indented block') ||
        lower.contains("expected an indented block after")) {
      return ErrorExplanation(
        line: line,
        headline: 'The block under this line needs to be indented',
        why:
            'After a line ending in `:`, Python expects the body to be '
            'pushed in by one level.',
        nextStep:
            'Indent the next line by 4 spaces (the editor does this '
            'automatically when you press Enter at the end of a `:` line).',
      );
    }
    if (lower.contains('unexpected indent')) {
      return ErrorExplanation(
        line: line,
        headline: 'This line is indented more than Python expects',
        why: 'The line is pushed in, but nothing above it opens a block.',
        nextStep:
            'Remove the leading spaces so the line starts at the same '
            'column as the code around it.',
      );
    }
    if (lower.contains('unindent does not match')) {
      return ErrorExplanation(
        line: line,
        headline: 'The indentation does not line up with the code above',
        why:
            'The spaces at the start of this line do not match any open '
            'block.',
        nextStep:
            'Match the indentation exactly. Four spaces per level is '
            'the convention, and mixing tabs with spaces causes this in ways '
            'you cannot see.',
      );
    }
    return ErrorExplanation(
      line: line,
      headline: 'The indentation is not correct',
      why: 'Python uses indentation to know which lines belong together.',
      nextStep:
          'Line this line up with the code it belongs to, using the '
          'same number of spaces.',
    );
  }

  // --- Names --------------------------------------------------------------

  ErrorExplanation _name(ExecutionException error, String source) {
    final line = error.line;
    final name = RegExp(r"name '([^']+)'").firstMatch(error.message)?.group(1);
    final suggestion = name == null ? null : _didYouMean(name, source);

    if (name == null) {
      return ErrorExplanation(
        line: line,
        headline: 'You used a name that does not exist yet',
        why: 'Python has not seen this name before it reached this line.',
        nextStep: 'Create it first with an assignment, or fix the spelling.',
      );
    }

    if (suggestion != null) {
      final isBuiltin = pythonBuiltins.contains(suggestion);
      return ErrorExplanation(
        line: line,
        headline: '“$name” is not the name Python knows',
        why: isBuiltin
            ? 'The built-in function is spelled `$suggestion`.'
            : 'You already defined `$suggestion` earlier in this exercise.',
        nextStep: 'Change `$name` to `$suggestion` and run it again.',
      );
    }

    final definedLater = RegExp(
      r'^\s*' + RegExp.escape(name) + r'\s*=',
      multiLine: true,
    ).hasMatch(source.split('\n').skip((line ?? 1)).join('\n'));
    if (definedLater) {
      return ErrorExplanation(
        line: line,
        headline: '“$name” is used before it is created',
        why:
            'The value is created further down, but Python reads from the '
            'top, so it does not exist yet at this point.',
        nextStep:
            'Move the line that creates `$name` above the line that '
            'uses it.',
      );
    }

    return ErrorExplanation(
      line: line,
      headline: '“$name” does not exist yet',
      why:
          'Python has only the names you created with `=`, or the ones '
          'built in, like print and len.',
      nextStep:
          'Create it first, for example `$name = 0`, and check that the '
          'spelling matches exactly everywhere it is used.',
    );
  }

  ErrorExplanation _unbound(String message, int? line) {
    final name = RegExp(r"name '([^']+)'").firstMatch(message)?.group(1);
    return ErrorExplanation(
      line: line,
      headline: name == null
          ? 'A variable is used before it has a value'
          : '“$name” has no value at this point',
      why:
          'The function assigns it further down, so Python treats it as a '
          'local name and it is empty on this line.',
      nextStep: name == null
          ? 'Give the variable a value before reading it.'
          : 'Give `$name` a starting value at the top of the function, or '
                'pass it in as a parameter.',
    );
  }

  // --- Types --------------------------------------------------------------

  ErrorExplanation _type(ExecutionException error, String lower, int? line) {
    final message = error.message;

    if (lower.contains('can only concatenate str') ||
        (lower.contains("unsupported operand type(s) for +") &&
            lower.contains('str'))) {
      return ErrorExplanation(
        line: line,
        headline: 'Text and numbers cannot be added with +',
        why:
            '`+` joins two pieces of text, but it will not glue a number '
            'onto text on its own.',
        nextStep:
            'Wrap the number: `print("Total: " + str(total))`. Using a '
            'comma is shorter: `print("Total:", total)`.',
      );
    }

    if (lower.contains("unsupported operand type(s) for +")) {
      return ErrorExplanation(
        line: line,
        headline: 'These two values cannot be added',
        why: message,
        nextStep:
            'Convert one of them first: `int(value)` for whole '
            'numbers, `float(value)` for decimals, `str(value)` for text.',
      );
    }

    if (lower.contains('object is not callable')) {
      return ErrorExplanation(
        line: line,
        headline: 'You used a value as if it were a function',
        why:
            'The name in front of the ( ) holds a number or text, not a '
            'function.',
        nextStep:
            'If you meant to multiply, use `*`. Otherwise rename your '
            'variable so it does not hide the function you wanted to call.',
      );
    }

    if (lower.contains('takes') && lower.contains('positional argument')) {
      return ErrorExplanation(
        line: line,
        headline: 'A function was given the wrong number of values',
        why: message,
        nextStep:
            'Count the items inside the ( ) and compare with the '
            'parameters in the `def` line. Defaults in the definition make '
            'parameters optional.',
      );
    }

    if (lower.contains('not subscriptable')) {
      return ErrorExplanation(
        line: line,
        headline: 'You used [ ] on something that is not a list or text',
        why:
            'Square brackets read an item from a list, tuple or string. '
            'Numbers and None cannot be indexed.',
        nextStep:
            'Check what the variable holds — `print(type(value))` — and '
            'make sure it is a list, tuple or string.',
      );
    }

    if (lower.contains("'nonetype'") && lower.contains('not iterable')) {
      return ErrorExplanation(
        line: line,
        headline:
            'A function returned nothing, so there was nothing to loop over',
        why: 'Functions return None unless they use `return`.',
        nextStep:
            'Add `return result` at the end of the function you are '
            'calling.',
      );
    }

    return ErrorExplanation(
      line: line,
      headline: 'Two values were used together in a way Python does not allow',
      why: message,
      nextStep:
          'Check the types with `print(type(value))` and convert the '
          'one that is wrong.',
    );
  }

  ErrorExplanation _value(ExecutionException error, String lower, int? line) {
    final message = error.message;
    if (lower.contains('invalid literal for int()')) {
      return ErrorExplanation(
        line: line,
        headline: 'That text is not a whole number',
        why:
            '`int()` only accepts digits. input() always gives you text, so '
            'typing anything else — or pressing Enter on an empty line — ends '
            'up here.',
        nextStep:
            'Convert only after checking, or use `float()` for '
            'decimals. For a safe conversion: `if answer.isdigit(): '
            'number = int(answer)`.',
      );
    }
    if (lower.contains('could not convert string to float')) {
      return ErrorExplanation(
        line: line,
        headline: 'That text is not a decimal number',
        why: message,
        nextStep: 'Type a value like 3.5, with a dot rather than a comma.',
      );
    }
    if (lower.contains('too many values to unpack')) {
      return ErrorExplanation(
        line: line,
        headline: 'There are more values than names to store them',
        why: message,
        nextStep:
            'Count the items and the names on the left of `=`, or '
            'collect the extras with `*rest`.',
      );
    }
    if (lower.contains('not enough values to unpack')) {
      return ErrorExplanation(
        line: line,
        headline: 'There are fewer values than names to store them',
        why: message,
        nextStep:
            'Add the missing value, or remove a name from the left of '
            '`=`.',
      );
    }
    return ErrorExplanation(
      line: line,
      headline: 'A value had the right type but the wrong content',
      why: message,
      nextStep:
          'Print the value just before this line to see what it '
          'actually holds.',
    );
  }

  ErrorExplanation _key(String message, int? line) {
    final key = RegExp(r"KeyError: (.*)$").firstMatch(message)?.group(1);
    return ErrorExplanation(
      line: line,
      headline: key == null
          ? 'That key is not in the dictionary'
          : 'The dictionary has no key $key',
      why:
          'Looking up a key that was never stored returns an error rather '
          'than a default value.',
      nextStep:
          'Use `.get(key, default)` if the key might be missing, or '
          'print `list(dictionary.keys())` to see what is actually there.',
    );
  }

  ErrorExplanation _attribute(String message, int? line) {
    final match = RegExp(r"'(\w+)' object has no attribute '(\w+)'")
        .firstMatch(message);
    final owner = match?.group(1);
    final attribute = match?.group(2);

    if (owner == 'str' && (attribute == 'append' || attribute == 'push')) {
      return ErrorExplanation(
        line: line,
        headline: 'Text cannot be appended to like a list',
        why:
            '`append` belongs to lists. A string is immutable, so it cannot '
            'grow in place.',
        nextStep:
            'Join with `+` or an f-string: `message = message + "!"`, '
            'or collect pieces in a list and `"".join(pieces)` at the end.',
      );
    }
    if (owner == 'NoneType') {
      return ErrorExplanation(
        line: line,
        headline: 'That value is None, so it has no methods',
        why:
            'Usually a function did not return anything, or a search found '
            'nothing.',
        nextStep:
            'Check the value with `print(value)` before using it, and '
            'add a `return` in the function that produced it.',
      );
    }
    if (owner != null && attribute != null) {
      return ErrorExplanation(
        line: line,
        headline: 'A $owner has no “$attribute”',
        why:
            'The name after the dot must be a method or property that '
            'belongs to that type.',
        nextStep:
            'Check the spelling, and check that the variable really is '
            'a $owner — `print(type(value))` tells you.',
      );
    }
    return ErrorExplanation(
      line: line,
      headline: 'That value has no such method',
      why: message,
      nextStep: 'Check the spelling after the dot and the type of the value.',
    );
  }

  ErrorExplanation _import(String message, int? line) {
    final module = RegExp(r"No module named '([^']+)'")
        .firstMatch(message)
        ?.group(1);
    return ErrorExplanation(
      line: line,
      headline: module == null
          ? 'That module could not be imported'
          : 'There is no module called “$module” here',
      why:
          'Only the standard library and the modules bundled with the app '
          'can be imported.',
      nextStep: module == null
          ? 'Check the spelling of the import.'
          : 'Check the spelling of `$module`, or use a standard module '
                'instead.',
    );
  }

  // --- Helpers ------------------------------------------------------------

  /// Suggests the closest name already known: something the learner defined, or
  /// a built-in whose spelling is one or two keystrokes away.
  static String? _didYouMean(String name, String source) {
    final candidates = <String>[...bound(namesIn(source)), ...pythonBuiltins];
    String? best;
    var bestScore = 1 << 30;
    for (final candidate in candidates) {
      if (candidate == name) continue;
      final score = _editDistance(name.toLowerCase(), candidate.toLowerCase());
      // A typo is 1-2 edits; 3+ would be a different word.
      if (score > 2) continue;
      if (score < bestScore ||
          (score == bestScore &&
              best != null &&
              candidate.length < best.length)) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  static List<String> namesIn(String source) {
    return RegExp(
      r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=',
      multiLine: true,
    ).allMatches(source).map((m) => m.group(1)!).toList(growable: false);
  }

  static Iterable<String> bound(List<String> names) => names.toSet();

  static String _lineText(String source, int? line) {
    if (source.isEmpty || line == null || line < 1) return '';
    final lines = source.split('\n');
    if (line > lines.length) return '';
    return lines[line - 1];
  }

  static bool _hasSingleEqualsComparison(String line) {
    final trimmed = line.trim();
    if (!(trimmed.startsWith('if ') ||
        trimmed.startsWith('elif ') ||
        trimmed.startsWith('while '))) {
      return false;
    }
    if (trimmed.contains('==') || trimmed.contains('!=')) return false;
    if (trimmed.contains('>=') || trimmed.contains('<=')) return false;
    return RegExp(r'(?<![<>=!])=(?!=)').hasMatch(trimmed);
  }

  static bool _hasUnbalancedQuote(String line) {
    var single = 0;
    var double = 0;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '#' && single.isEven && double.isEven) break;
      if (ch == "'" && double.isEven) single++;
      if (ch == '"' && single.isEven) double++;
    }
    return single.isOdd || double.isOdd;
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        var best = deletion < insertion ? deletion : insertion;
        if (substitution < best) best = substitution;
        current[j] = best;
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }
}
