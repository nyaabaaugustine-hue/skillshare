import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/features/messages/push_message.dart';

void main() {
  group('PushMessage.fromData', () {
    test('parses announcement payloads', () {
      final message = PushMessage.fromData(<String, Object?>{
        'type': 'announcement',
        'announcementId': '  ann-7  ',
        'title': ' New course ',
        'body': ' Start learning today. ',
      });

      expect(message, isNotNull);
      expect(message!.id, 'ann-7');
      expect(message.title, 'New course');
      expect(message.body, 'Start learning today.');
    });

    test('uses safe defaults for missing copy', () {
      final message = PushMessage.fromData(<String, Object?>{
        'type': 'announcement',
        'announcementId': 'ann-8',
      });

      expect(message?.title, isNull);
      expect(message?.body, isNull);
    });

    test('ignores unrelated or malformed messages', () {
      expect(
        PushMessage.fromData(<String, Object?>{'type': 'reminder'}),
        isNull,
      );
      expect(
        PushMessage.fromData(<String, Object?>{
          'type': 'announcement',
          'announcementId': '   ',
        }),
        isNull,
      );
    });
  });
}
