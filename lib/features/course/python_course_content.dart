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

/// Python Kickstart: the real lesson videos from the learning map, with a short
/// hands-on practice after the lessons that teach a new skill. Finishing a
/// video or a practice unlocks the next node on the Home path.
final CourseUnit pythonKickstartCourse = CourseUnit(
  id: 'python-kickstart',
  sectionLabel: 'SECTION FOUNDATIONS',
  title: 'Unit 1: Python Kickstart',
  subtitle:
      'Watch each lesson, then practise it. Finish a step to open the next one.',
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
    const CourseStep(
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
              'Store a name and two numbers in variables, then print a sentence.',
          starterCode:
              'name = "Ama"\n'
              'price = 12\n'
              'quantity = 3\n'
              '\n'
              '# Task: print a sentence that says who owes how much,\n'
              '# for example:  Ama owes 36\n'
              '# Work the total out from the variables above.\n'
              '\n'
              '# Write your code below:\n',
          requirements: <String>[
            'Use the three variables',
            'Print a result calculated from your variables',
          ],
          hints: <String>[
            'You can print several values at once: print(name, "owes", total).',
            'Multiply with *.',
          ],
          outputContains: <String>['Ama', '36'],
          codeContains: <String>['print(', '*'],
        ),
      ],
    ),
  ],
);
