import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/main.dart';

void main() {
  group('announcementIdFromFragment', () {
    test('reads the worker notification link', () {
      expect(announcementIdFromFragment('/announcements/abc-123'), 'abc-123');
    });

    test('accepts a fragment with a leading hash', () {
      expect(announcementIdFromFragment('#/announcements/42'), '42');
    });

    test('decodes escaped announcement ids', () {
      expect(announcementIdFromFragment('/announcements/a%2Fb%3Fc'), 'a/b?c');
    });

    test('ignores query strings and other routes', () {
      expect(announcementIdFromFragment('/announcements/12?x=1'), '12');
      expect(announcementIdFromFragment('/announcements/'), isNull);
      expect(announcementIdFromFragment('/settings'), isNull);
      expect(announcementIdFromFragment(''), isNull);
    });

    test('ignores malformed escaping', () {
      expect(announcementIdFromFragment('/announcements/%ZZ'), isNull);
    });
  });
}
