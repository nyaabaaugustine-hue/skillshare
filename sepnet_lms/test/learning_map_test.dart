import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/lms/learning_map.dart';

void main() {
  test('normalizes both legacy and current academy tags', () {
    expect(
      videoTitleFromPublicId('https://example.com/01._SkillsBridge.mp4'),
      'SkillBridge Academy',
    );
    expect(
      videoTitleFromPublicId('https://example.com/02._SkillBridge.mp4'),
      'SkillBridge Academy',
    );
  });
}
