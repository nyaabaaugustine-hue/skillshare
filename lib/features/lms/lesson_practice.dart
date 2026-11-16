import 'package:skillbridge_python_lab/features/course/course_models.dart';
import 'package:skillbridge_python_lab/features/course/practice_checks.dart';
import 'package:skillbridge_python_lab/features/course/python_course_content.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';

import 'learning_map.dart';

/// A one-question knowledge check shown under a lesson video.
class QuickCheck {
  const QuickCheck({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  }) : assert(correctIndex >= 0);

  final String question;
  final List<String> options;
  final int correctIndex;

  /// Shown after the learner answers, to lock in the idea.
  final String explanation;
}

/// The hands-on part of one lesson: a Code Lab task that opens the IDE and is
/// checked against the real output of the learner's program, plus a quick check.
class LessonPractice {
  const LessonPractice({
    required this.lessonNumber,
    required this.lessonTitle,
    required this.codeLab,
    required this.quickCheck,
  });

  final String lessonNumber;
  final String lessonTitle;
  final CodeBlock codeLab;
  final QuickCheck quickCheck;

  /// The editor's exercise for this lesson. The id is per lesson so the
  /// learner's code is saved and restored as a draft.
  Exercise get exercise => Exercise(
    id: 'lesson-lab-$lessonNumber',
    title: 'Code Lab \u00b7 $lessonTitle',
    instructions: codeLab.brief,
    starterCode: codeLab.starterCode,
    requirements: codeLab.requirements,
    hints: codeLab.hints,
    expectedOutput: codeLab.expectedOutput,
  );
}

/// The practice block of an existing course practice step, so a lesson that
/// already has one shows exactly the same task and checks.
CodeBlock _courseBlock(String stepId) {
  final step = pythonKickstartCourse.steps.firstWhere((s) => s.id == stepId);
  return practiceBlockOf(step)!;
}

/// Practice for each of the 8 lessons, keyed by lesson number. Lessons 03, 06,
/// 07 and 08 reuse the course practice steps; the others add a short task that
/// fits what the lesson covers.
final Map<String, LessonPractice> lessonPractice = <String, LessonPractice>{
  '01': const LessonPractice(
    lessonNumber: '01',
    lessonTitle: 'Advancing your career with Python',
    codeLab: CodeBlock(
      heading: 'Introduce yourself',
      brief:
          'Use print() to introduce yourself in two lines: your name, then the '
          'skill you want to learn.',
      starterCode:
          '# Task: print your name on one line,\n'
          '# then the skill you want to learn on the next line.\n'
          '\n'
          '# Write your code below:\n',
      requirements: <String>[
        'Print your name',
        'Print the skill you want to learn on its own line',
      ],
      hints: <String>['Each print() call starts a new line.'],
      codeContains: <String>['print('],
      minOutputLines: 2,
    ),
    quickCheck: QuickCheck(
      question: 'Which of these is a common way people use Python in a career?',
      options: <String>[
        'Analysing data and automating tasks',
        'Designing computer chips by hand',
        'Repairing phone screens',
      ],
      correctIndex: 0,
      explanation:
          'Python is widely used for data analysis, automation, web back-ends '
          'and AI, which is why it opens so many career paths.',
    ),
  ),
  '02': const LessonPractice(
    lessonNumber: '02',
    lessonTitle: 'Demystifying Python',
    codeLab: CodeBlock(
      heading: 'Python reads top to bottom',
      brief:
          'Python runs your code from the top, one line at a time. Print three '
          'steps of a simple routine, one per line, and see them appear in '
          'order.',
      starterCode:
          '# Task: print three steps of a routine, for example\n'
          '#   Wake up\n'
          '#   Eat breakfast\n'
          '#   Study Python\n'
          '\n'
          '# Write your code below:\n',
      requirements: <String>[
        'Print three separate lines',
        'Use one print() for each step',
      ],
      hints: <String>['Three print() calls give three lines of output.'],
      codeContains: <String>['print('],
      minOutputLines: 3,
    ),
    quickCheck: QuickCheck(
      question: 'What runs your Python code?',
      options: <String>[
        'The Python interpreter',
        'A web browser only',
        'A spreadsheet program',
      ],
      correctIndex: 0,
      explanation:
          'Python is an interpreted language: the interpreter reads your code '
          'and runs it, so you can try ideas straight away.',
    ),
  ),
  '03': LessonPractice(
    lessonNumber: '03',
    lessonTitle: 'Starting with Python',
    codeLab: _courseBlock('py-practice-print'),
    quickCheck: const QuickCheck(
      question: 'What does print() do in Python?',
      options: <String>[
        'Displays a value',
        'Deletes a variable',
        'Starts a loop',
      ],
      correctIndex: 0,
      explanation:
          'print() shows whatever you give it on the screen. It is the quickest '
          'way to see what your program is doing.',
    ),
  ),
  '04': const LessonPractice(
    lessonNumber: '04',
    lessonTitle: 'Comparing Python vs Java',
    codeLab: CodeBlock(
      heading: 'Hello in one line',
      brief:
          'Java needs several lines of setup just to say hello. Python needs '
          'one. Print the message Hello from Python!',
      starterCode:
          '# Task: print exactly   Hello from Python!\n'
          '\n'
          '# Write your code below:\n',
      requirements: <String>[
        'Print the message Hello from Python!',
        'Do it with a single line of code',
      ],
      hints: <String>['Put the text inside quotes inside print().'],
      outputContains: <String>['Hello from Python!'],
      codeContains: <String>['print('],
    ),
    quickCheck: QuickCheck(
      question: 'Compared with Java, Python code for the same task is usually…',
      options: <String>[
        'Shorter and quicker to read',
        'Impossible to run on Windows',
        'Only useful for websites',
      ],
      correctIndex: 0,
      explanation:
          'Python keeps syntax light, so the same idea often takes fewer lines '
          'than in Java. That makes it a friendly first language.',
    ),
  ),
  '05': const LessonPractice(
    lessonNumber: '05',
    lessonTitle: 'Harnessing the power of Python',
    codeLab: CodeBlock(
      heading: 'Python as a calculator',
      brief:
          'Python can do the maths for you. Work out 12 multiplied by 7 and '
          'print the answer.',
      starterCode:
          '# Task: calculate 12 * 7 and print the result\n'
          '\n'
          '# Write your code below:\n',
      requirements: <String>['Multiply 12 by 7 with *', 'Print the result'],
      hints: <String>['print(12 * 7) calculates first, then shows the answer.'],
      outputContains: <String>['84'],
      codeContains: <String>['print(', '*'],
    ),
    quickCheck: QuickCheck(
      question: 'What gives Python so much power for many different jobs?',
      options: <String>[
        'A huge collection of ready-made libraries',
        'It can only do one single thing',
        'It does not need a computer',
      ],
      correctIndex: 0,
      explanation:
          'Libraries for data, web, automation and AI mean you rarely start '
          'from scratch, so you can build real things quickly.',
    ),
  ),
  '06': LessonPractice(
    lessonNumber: '06',
    lessonTitle: 'Setting up your Python environment',
    codeLab: _courseBlock('py-practice-setup'),
    quickCheck: const QuickCheck(
      question:
          'Which command shows the installed Python version in a terminal?',
      options: <String>['python --version', 'python --delete', 'print version'],
      correctIndex: 0,
      explanation:
          'Running python --version (python3 --version on some systems) '
          'confirms Python is installed and tells you which version you have.',
    ),
  ),
  '07': LessonPractice(
    lessonNumber: '07',
    lessonTitle: 'Sorting your types of data',
    codeLab: _courseBlock('py-practice-types'),
    quickCheck: const QuickCheck(
      question: 'What type is the value 3.14 in Python?',
      options: <String>['float', 'int', 'str'],
      correctIndex: 0,
      explanation:
          'Numbers with a decimal point are floats. Whole numbers are ints and '
          'text in quotes is a str.',
    ),
  ),
  '08': LessonPractice(
    lessonNumber: '08',
    lessonTitle: 'Storing data using variables',
    codeLab: _courseBlock('py-practice-variables'),
    quickCheck: const QuickCheck(
      question: 'After price = 12 and quantity = 3, what is price * quantity?',
      options: <String>['36', '123', '15'],
      correctIndex: 0,
      explanation:
          'Variables hold values, and * multiplies them: 12 \u00d7 3 = 36. '
          'Python uses the stored values when it does the sum.',
    ),
  ),
};

/// The practice for the lesson whose video is [publicId]. Falls back to the
/// first-output lesson (the original content) if the video is not on the map.
LessonPractice practiceForPublicId(String publicId) {
  final index = learningPlaces.indexWhere((p) => p.publicId == publicId);
  if (index < 0) return lessonPractice['03']!;
  return lessonPractice[learningPlaces[index].number] ?? lessonPractice['03']!;
}
