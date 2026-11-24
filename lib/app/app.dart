import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_exception.dart';
import '../features/auth/auth_controller.dart';
import '../features/home/home_screen.dart';
import '../features/messages/announcement_controller.dart';
import '../features/messages/announcement_repository.dart';
import '../features/settings/settings_controller.dart';
import 'router.dart';
import 'theme.dart';

class SkillBridgeApp extends StatelessWidget {
  const SkillBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillBridge Academy',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: context.watch<SettingsController>().themeMode,
      home: const HomeScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        return ChangeNotifierProvider<AnnouncementController>(
          create: (_) {
            final auth = context.read<AuthController?>();
            return AnnouncementController(
              repository: HttpAnnouncementRepository(
                call: (method, path, {body}) {
                  if (auth == null) throw const AuthenticationException();
                  return auth.requestSharedApi(method, path, body: body);
                },
              ),
            );
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
