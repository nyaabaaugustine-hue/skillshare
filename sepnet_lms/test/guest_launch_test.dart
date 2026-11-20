import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/auth/guest_launch.dart';

void main() {
  group('guestLaunchRequested', () {
    test('accepts the explicit guest launch flag', () {
      expect(guestLaunchRequested(Uri.parse('https://academy.test/app?guest=1')), isTrue);
    });

    test('does not treat other or missing values as guest mode', () {
      expect(guestLaunchRequested(Uri.parse('https://academy.test/app')), isFalse);
      expect(guestLaunchRequested(Uri.parse('https://academy.test/app?guest=true')), isFalse);
      expect(guestLaunchRequested(Uri.parse('https://academy.test/app?guest=0')), isFalse);
    });
  });
}
