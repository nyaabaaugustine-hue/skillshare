import 'dart:math';

import 'package:skillbridge_python_lab/features/lms/learning_map.dart';

import 'course_models.dart';

const String _heroPreview = 'assets/course_previews/python_quick_start.png';

CourseStep _video(int index) {
  final place = learningPlaces[index];
  return CourseStep(
    id: 'py-video-${place.number}',
    title: place.title,
    subtitle: 'Watch the lesson',
    kind: CourseStepKind.video,
    xp: 20,
    previewAsset: previewForPlace(place.number),
    blocks: <CourseBlock>[
      VideoBlock(
        heading: place.title,
        subtitle: 'Lesson ${place.number} · ${place.duration}',
        publicId: place.publicId,
      ),
    ],
  );
}

/// The numbers behind the "Storing Data" practice.
///
/// They are chosen once per launch, so a learner who copies the answer from a
/// previous session (or types it as text) fails: the total they must print is
/// different, and [CodeBlock.forbiddenLiterals] rejects the literal outright.
class _PracticeValues {
  const _PracticeValues({required this.price, required this.quantity});

  final int price;
  final int quantity;

  int get total => price * quantity;

  static _PracticeValues pick({Random? random}) {
    final rng = random ?? Random();
    var price = 11 + rng.nextInt(9); // 11..19
    final quantity = 3 + rng.nextInt(5); // 3..7
    if (price == quantity) price += 1;
    return _PracticeValues(price: price, quantity: quantity);
  }
}

final _PracticeValues _practice = _PracticeValues.pick();

/// Python Kickstart: the real lesson videos from the learning map, with a short
/// hands-on practice after the lessons that teach a new skill. Finishing a
/// video or a practice unlocks the next node on the Home path.
final CourseUnit pythonKickstartCourse = _buildCourse();

CourseUnit _buildCourse() => CourseUnit(
  id: 'python-kickstart',
  version: 1,
  sectionLabel: 'SECTION FOUNDATIONS',
  title: 'Unit 1: Python Kickstart',
  subtitle: 'Watch each lesson, then practise it. Finish a step to open the next one.',
  steps: <CourseStep>[
    _video(0),
    _video(1),
    _video(2),
    const CourseStep(
      id: 'py-practice-print',
      title: 'Practice: Your First Output',
      subtitle: 'Use print()',
      kind: CourseStepKind.coding,
      xp: 40,
      previewAsset: _heroPreview,
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'Your First Output',
          brief: 'Use print() to show a message and a number on screen.',
          workedExample: 'print("Hello, Ama!")\nprint(12)',
          whyItWorks:
              'Each print() call displays its value and starts a new line. '
              'Text needs quotes; numbers do not.',
          takeaway: 'Show text and numbers in the output with print().',
          starterCode:
              '# Task: print a greeting that includes your name,\n'
              '# then print your age on its own line.\n'
              '\n'
              '# Write your code below:\n',
          requirements: <String>[
            'Print a greeting with your name',
            'Print a number on its own line',
          ],
          hints: <String>[
            'Text goes inside quotes, numbers do not.',
            'Each print() call starts a new line.',
          ],
          codeContains: <String>['print('],
          minOutputLines: 2,
        ),
      ],
    ),
    _video(3),
    _video(4),
    _video(5),
    const CourseStep(
      id: 'py-practice-setup',
      title: 'Practice: Check Your Setup',
      subtitle: 'Run your first script',
      kind: CourseStepKind.coding,
      xp: 40,
      previewAsset: 'assets/course_previews/lesson_06_functions.png',
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'Check Your Setup',
          brief: 'Run a script to prove your Python environment works.',
          workedExample:
              'import sys\nprint("Python is ready!")\nprint(sys.version)',
          whyItWorks:
              'Importing sys makes Python version information available as '
              'sys.version, which print() can display.',
          takeaway: 'Run a script and inspect the Python version.',
          starterCode:
              'import sys\n'
              '\n'
              '# Task: print the message Python is ready!\n'
              '# then print the Python version using sys.version\n'
              '\n'
              '# Write your code below:\n',
          requirements: <String>[
            'Run the script without errors',
            'See "Python is ready!" in the output',
            'Print the version using sys.version',
          ],
          hints: <String>['sys.version is a value, so print(sys.version).'],
          outputContains: <String>['Python is ready!'],
          codeContains: <String>['sys.version'],
          minOutputLines: 2,
        ),
      ],
    ),
    _video(6),
    const CourseStep(
      id: 'py-practice-types',
      title: 'Practice: Types of Data',
      subtitle: 'Use type()',
      kind: CourseStepKind.coding,
      xp: 40,
      previewAsset: 'assets/course_previews/lesson_07_lists.png',
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'Types of Data',
          brief: 'Print the type of a whole number, a decimal and some text.',
          workedExample: 'print(type(10))',
          whyItWorks:
              'type() reports what kind of value it receives. The same call '
              'works with numbers and text.',
          takeaway:
              'Use type() to check whether a value is an int, float or str.',
          starterCode:
              '# Task: print the type of each value below using type()\n'
              '#   10        a whole number\n'
              '#   3.14      a decimal\n'
              '#   "Python"  some text\n'
              '\n'
              '# Write your code below:\n',
          requirements: <String>[
            'Show int, float and str in the output',
            'Use type() for each value',
          ],
          hints: <String>['print(type(10)) shows what kind of value 10 is.'],
          outputContains: <String>[
            "<class 'int'>",
            "<class 'float'>",
            "<class 'str'>",
          ],
          codeContains: <String>['type('],
        ),
      ],
    ),
    _video(7),
    CourseStep(
      id: 'py-practice-variables',
      title: 'Practice: Storing Data',
      subtitle: 'Use variables',
      kind: CourseStepKind.coding,
      xp: 50,
      previewAsset: 'assets/course_previews/lesson_03_arithmetic.png',
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'Storing Data',
          brief:
              'Ama buys ${_practice.quantity} items at ${_practice.price} cedis '
              'each. Work the total out from the variables, then print who owes '
              'how much — for example "Ama owes 48".',
          workedExample:
              'price = 12\nquantity = 3\ntotal = price * quantity\n'
              'print("Ama owes", total)',
          whyItWorks:
              'Variables keep values so you can calculate with them later. '
              'The * operator multiplies the two numbers before print() shows '
              'the result.',
          takeaway: 'Store values, calculate from them and print the result.',
          starterCode:
              'name = "Ama"\n'
              'price = ${_practice.price}\n'
              'quantity = ${_practice.quantity}\n'
              '\n'
              '# Task: print a sentence that says who owes how much.\n'
              '# Work the total out from the variables above —\n'
              '# do not type the answer as text.\n'
              '\n'
              '# Write your code below:\n',
          requirements: <String>[
            'Use the three variables',
            'Print a total worked out in code from price and quantity',
          ],
          hints: <String>[
            'You can print several values at once: print(name, "owes", total).',
            'Multiply with * and store the result in a variable called total.',
          ],
          // The expected total is generated per launch, so it cannot be copied
          // from the brief, a previous session, or the worked example.
          outputContains: <String>['Ama', '${_practice.total}'],
          codeContains: <String>['print(', '*'],
          forbiddenLiterals: <String>['${_practice.total}'],
        ),
      ],
    ),
    // Debugging practice: the starter code is deliberately broken. Reading a
    // bug and fixing it is a different skill from writing code from a blank
    // file, and it is the skill that transfers to real work.
    CourseStep(
      id: 'py-fix-bug-loop',
      title: 'Fix the bug: the endless loop',
      subtitle: 'Debug a loop',
      kind: CourseStepKind.coding,
      xp: 45,
      previewAsset: _heroPreview,
      blocks: <CourseBlock>[
        CodeBlock(
          heading: 'Fix the bug: the endless loop',
          brief:
              'This loop should print 1, 2 and 3 and then stop. Instead it '
              'keeps printing until the app has to stop it. Find the missing '
              'line and fix it — do not rewrite the whole program.',
          whyItWorks:
              'A while loop repeats until its condition is false. count starts '
              'at 1 and never changes, so count <= 3 stays true forever. Adding '
              'count += 1 moves it forward and the loop ends after 3.',
          takeaway:
              'Every while loop must change something its condition depends '
              'on, or it never ends.',
          starterCode:
              '# Bug: this loop never stops.\n'
              'count = 1\n'
              'while count <= 3:\n'
              '    print(count)\n'
              '\n'
              '# Fix the loop above — it should print 1, 2, 3 and stop.\n',
          requirements: <String>[
            'The program finishes without being stopped',
            'It prints exactly 1, 2 and 3, each on its own line',
          ],
          hints: <String>[
            'What changes inside the loop? Right now: nothing.',
            'Add one line inside the loop that increases count.',
          ],
          expectedOutput: '1\n2\n3',
          codeContains: <String>['while'],
        ),
      ],
    ),
    CourseStep(
      id: 'py-fix-bug-concat',
      title: 'Fix the bug: the total is text',
      subtitle: 'Debug types',
      kind: CourseStepKind.coding,
      xp: 45,
      previewAsset: _heroPreview,
      blocks: <CodeBlock>[
        CodeBlock(
          heading: 'Fix the bug: the total is text',
          brief:
              'The program prints "Total: 123" but a total of 12 and 3 is 36. '
              'The numbers are being glued together as text. Fix the '
              'calculation so it multiplies instead.',
          whyItWorks:
              'str() turns a number into text, and + between two pieces of text '
              'joins them: "12" + "3" is "123". Multiplying the numbers with * '
              'gives arithmetic: 12 * 3 is 36.',
          takeaway:
              'Text plus text joins; numbers with * and + calculate. Only turn '
              'a number into text when you are printing it.',
          starterCode:
              '# Bug: this prints Total: 123 instead of Total: 36.\n'
              'price = 12\n'
              'quantity = 3\n'
              'total = str(price) + str(quantity)\n'
              'print("Total:", total)\n'
              '\n'
              '# Fix the total above — do not type the answer as text.\n',
          requirements: <String>[
            'It prints Total: 36',
            'The total is calculated from price and quantity, not typed',
          ],
          hints: <String>[
            'str() makes text. Do you need text here?',
            'Two numbers multiplied use *, not +.',
          ],
          expectedOutput: 'Total: 36',
          codeContains: <String>['*'],
          forbiddenLiterals: <String>['36'],
        ),
      ],
    ),
  ],
);
