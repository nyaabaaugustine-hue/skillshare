import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/skillbridge_exec.py` is a deliberate copy of the single source of truth
/// (`python_app/skillbridge_exec.py`): the web worker falls back to it when the
/// bundled-asset URL is not reachable. If this test fails, copy the file:
///
///     Copy-Item python_app\skillbridge_exec.py web\skillbridge_exec.py
void main() {
  String normalised(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  test('web executor copy matches python_app/skillbridge_exec.py', () {
    expect(
      normalised('web/skillbridge_exec.py'),
      normalised('python_app/skillbridge_exec.py'),
    );
  });

  test('the web worker knows both executor locations', () {
    final worker = File('web/pyodide_worker.js').readAsStringSync();
    expect(worker, contains('assets/python_app/skillbridge_exec.py'));
    expect(worker, contains("'skillbridge_exec.py'"));
  });
}
