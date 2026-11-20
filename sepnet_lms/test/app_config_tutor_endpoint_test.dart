import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge_python_lab/core/config/app_config.dart';

AppConfig _config({String tutor = '', String shared = ''}) => AppConfig(
  environment: 'test',
  lmsBaseUrl: '',
  lmsClientId: '',
  runtimeKind: PythonRuntimeKind.fake,
  pythonExecutable: 'python',
  executionTimeout: const Duration(seconds: 1),
  maxOutputChars: 1000,
  aiTutorBaseUrl: tutor,
  sharedApiBaseUrl: shared,
);

void main() {
  group('AppConfig.aiTutorEndpoint', () {
    test('an explicit Worker URL wins and loses any trailing slash', () {
      final config = _config(
        tutor: 'https://tutor.example.workers.dev/',
        shared: 'https://site.example',
      );
      expect(config.aiTutorEndpoint, 'https://tutor.example.workers.dev');
    });

    test('without a Worker URL it uses the website proxy', () {
      // This is what removes the second build define: one site origin now
      // covers sign-in, the leaderboard and the tutor.
      final config = _config(shared: 'https://site.example/');
      expect(config.aiTutorEndpoint, 'https://site.example/api/tutor');
    });

    test('no site and no Worker means no cloud tutor', () {
      expect(_config().aiTutorEndpoint, '');
      expect(_config(shared: '   ').aiTutorEndpoint, '');
    });
  });
}
