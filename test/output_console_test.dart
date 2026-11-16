import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillbridge_python_lab/features/editor/widgets/output_console.dart';
import 'package:skillbridge_python_lab/features/python_runtime/execution_result.dart';

void main() {
  testWidgets('explains a Python error and gives a next-step checklist', (
    tester,
  ) async {
    const result = ExecutionResult(
      status: ExecutionStatus.error,
      stderr: 'SyntaxError: invalid syntax',
      exception: ExecutionException(
        type: 'SyntaxError',
        message: 'invalid syntax',
        line: 1,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: OutputConsole(
              result: result,
              source: 'if score = 5:\n  print(score)',
            ),
          ),
        ),
      ),
    );

    expect(find.text('What happened?'), findsOneWidget);
    expect(find.text('A comparison used a single ='), findsOneWidget);
    expect(find.text('Why it happened'), findsOneWidget);
    expect(find.text('Try this next'), findsOneWidget);
    expect(find.text('Change the single `=` to `==`.'), findsOneWidget);
    expect(find.text('Quick debugging checklist'), findsOneWidget);
    expect(
      find.text('Your code is still here. Edit it and run again.'),
      findsOneWidget,
    );
  });
}
