/// The Python vocabulary the editor knows about: reserved keywords and the
/// built-in functions a beginner will meet first.
///
/// Kept free of Flutter imports so it can be shared by the editor's completion
/// strip, the error explainer and plain unit tests.
library;

/// Reserved words that cannot be used as variable names.
const List<String> pythonKeywords = <String>[
  'False',
  'None',
  'True',
  'and',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'class',
  'continue',
  'def',
  'del',
  'elif',
  'else',
  'except',
  'finally',
  'for',
  'from',
  'global',
  'if',
  'import',
  'in',
  'is',
  'lambda',
  'nonlocal',
  'not',
  'or',
  'pass',
  'raise',
  'return',
  'try',
  'while',
  'with',
  'yield',
];

/// Built-in callables and values worth completing for a beginner.
///
/// Deliberately a curated subset: offering `vars`, `globals` and `memoryview`
/// would bury `print` and `range` on a phone-sized strip.
const List<String> pythonBuiltins = <String>[
  'abs',
  'all',
  'any',
  'bool',
  'dict',
  'enumerate',
  'float',
  'format',
  'input',
  'int',
  'isinstance',
  'len',
  'list',
  'max',
  'min',
  'open',
  'print',
  'range',
  'round',
  'set',
  'sorted',
  'str',
  'sum',
  'tuple',
  'type',
  'zip',
];

/// Built-ins that are called rather than read. Completing these appends an
/// opening parenthesis so the learner lands inside the call.
const Set<String> pythonCallables = <String>{
  'abs',
  'all',
  'any',
  'bool',
  'dict',
  'enumerate',
  'float',
  'format',
  'input',
  'int',
  'isinstance',
  'len',
  'list',
  'max',
  'min',
  'open',
  'print',
  'range',
  'round',
  'set',
  'sorted',
  'str',
  'sum',
  'tuple',
  'type',
  'zip',
};

/// Keywords that open a block and therefore expect a trailing colon.
const Set<String> pythonBlockKeywords = <String>{
  'if',
  'elif',
  'else',
  'for',
  'while',
  'def',
  'class',
  'try',
  'except',
  'finally',
  'with',
  'async',
};

/// True when [word] is a reserved Python keyword.
bool isPythonKeyword(String word) => pythonKeywords.contains(word);

/// True when [word] is one of the curated built-ins.
bool isPythonBuiltin(String word) => pythonBuiltins.contains(word);
