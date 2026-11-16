import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillbridge_python_lab/features/auth/family_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FamilyLink password hashing', () {
    test('verifies the password it was created with', () {
      final link = FamilyLink.create(
        studentName: 'Ama Mensah',
        studentEmail: 'ama@academy.test',
        guardianName: 'Kofi Mensah',
        guardianEmail: 'kofi@academy.test',
        guardianLogin: 'kofi@academy.test',
        password: 'secret123',
        random: Random(1),
      );

      expect(link.verifyPassword('secret123'), isTrue);
      expect(link.verifyPassword('wrong'), isFalse);
      expect(link.passwordSalt, isNotEmpty);
      expect(link.passwordHash, isNotEmpty);
    });

    test('never stores the plaintext password', () {
      final link = FamilyLink.create(
        studentName: 'Ama',
        studentEmail: 'ama@x.test',
        guardianName: 'Kofi',
        guardianEmail: 'k@example.test',
        guardianLogin: 'k.parent123',
        password: 'PlainPass1',
        random: Random(2),
      );

      final json = link.toJson().toString();
      expect(json.contains('PlainPass1'), isFalse);
      expect(link.passwordHash, isNot(contains('PlainPass1')));
    });

    test('two links with the same password get different salted hashes', () {
      final a = FamilyLink.create(
        studentName: 'A',
        studentEmail: 'a@x.test',
        guardianName: 'G',
        guardianEmail: 'c@example.test',
        guardianLogin: 'g.parent1',
        password: 'same-password',
        random: Random(3),
      );
      final b = FamilyLink.create(
        studentName: 'B',
        studentEmail: 'b@x.test',
        guardianName: 'G',
        guardianEmail: 'c@example.test',
        guardianLogin: 'g.parent2',
        password: 'same-password',
        random: Random(4),
      );

      expect(a.passwordSalt, isNot(b.passwordSalt));
      expect(a.passwordHash, isNot(b.passwordHash));
    });

    test('withPassword issues a new secret and invalidates the old one', () {
      final link = FamilyLink.create(
        studentName: 'A',
        studentEmail: 'a@x.test',
        guardianName: 'G',
        guardianEmail: 'c@example.test',
        guardianLogin: 'g.parent1',
        password: 'old-secret',
        random: Random(5),
      );

      final rotated = link.withPassword('new-secret', random: Random(6));
      expect(rotated.verifyPassword('new-secret'), isTrue);
      expect(rotated.verifyPassword('old-secret'), isFalse);
      expect(rotated.guardianLogin, link.guardianLogin);
    });
  });

  group('FamilyLink matching', () {
    final link = FamilyLink.create(
      studentName: 'Ama Mensah',
      studentEmail: 'ama@academy.test',
      guardianName: 'Kofi Mensah',
      guardianEmail: 'kofi@academy.test',
      guardianLogin: 'kofi@academy.test',
      password: 'secret123',
      random: Random(7),
    );

    test('matches the guardian login case-insensitively', () {
      expect(link.matchesLogin('KOFI@academy.test'), isTrue);
      expect(link.matchesLogin('  kofi@academy.test  '), isTrue);
      expect(link.matchesLogin('someone-else'), isFalse);
    });

    test('matches the student email case-insensitively', () {
      expect(link.matchesStudentEmail('AMA@academy.test'), isTrue);
      expect(link.matchesStudentEmail('nope@x.test'), isFalse);
    });
  });

  group('FamilyLink generation', () {
    test('generateLogin slugs the name and appends .parentNNN', () {
      final login = FamilyLink.generateLogin(
        guardianName: 'Yaa Boateng',
        random: Random(8),
      );
      expect(login, startsWith('yaa.boateng.parent'));
      final suffix = login.split('.parent').last;
      expect(int.parse(suffix), inInclusiveRange(100, 999));
    });

    test('generateLogin falls back to "guardian" for a non-alphabet name', () {
      final login = FamilyLink.generateLogin(
        guardianName: '!!!',
        random: Random(9),
      );
      expect(login, startsWith('guardian.parent'));
    });

    test('generatePassword is readable and unique-ish', () {
      final p1 = FamilyLink.generatePassword(Random(10));
      final p2 = FamilyLink.generatePassword(Random(11));
      expect(p1, matches(RegExp(r'^[A-Za-z]+-\d{4}$')));
      expect(p1, isNot(p2));
    });
  });

  group('FamilyLinkStore', () {
    test(
      'saves and finds a link by guardian login and student email',
      () async {
        final store = FamilyLinkStore();
        final link = FamilyLink.create(
          studentName: 'Ama Mensah',
          studentEmail: 'ama@academy.test',
          guardianName: 'Kofi Mensah',
          guardianEmail: 'kofi@academy.test',
          guardianLogin: 'kofi@academy.test',
          password: 'secret123',
          random: Random(12),
        );
        await store.save(link);

        expect(
          (await store.findByLogin('kofi@academy.test'))?.studentName,
          'Ama Mensah',
        );
        expect(
          (await store.findByStudentEmail('ama@academy.test'))?.guardianLogin,
          'kofi@academy.test',
        );
        expect(await store.findByLogin('unknown'), isNull);
      },
    );

    test(
      'saving a second link for the same guardian replaces the first',
      () async {
        final store = FamilyLinkStore();
        FamilyLink make(String student) => FamilyLink.create(
          studentName: student,
          studentEmail: '$student@x.test',
          guardianName: 'Kofi',
          guardianEmail: 'kofi@x.test',
          guardianLogin: 'kofi@x.test',
          password: 'pw',
          random: Random(student.length),
        );

        await store.save(make('first'));
        await store.save(make('second'));

        final all = await store.all();
        expect(all.length, 1);
        expect(all.single.studentName, 'second');
      },
    );

    test('survives a corrupt stored entry', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'family.links': 'not-json',
      });
      final store = FamilyLinkStore();
      expect(await store.all(), isEmpty);
    });

    test('round-trips through JSON', () async {
      final store = FamilyLinkStore();
      final link = FamilyLink.create(
        studentName: 'Ama',
        studentEmail: 'ama@x.test',
        guardianName: 'Kofi',
        guardianEmail: 'k@example.test',
        guardianLogin: 'k.parent100',
        password: 'pw',
        random: Random(13),
      );
      await store.save(link);

      final restored = FamilyLink.fromJson((await store.all()).single.toJson());
      expect(restored.guardianLogin, 'k.parent100');
      expect(restored.verifyPassword('pw'), isTrue);
    });
  });
}
