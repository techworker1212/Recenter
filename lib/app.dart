import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_controller.dart';
import 'theme.dart';

class RecenterApp extends StatelessWidget {
  const RecenterApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Recenter',
          debugShowCheckedModeBanner: false,
          theme: recenterTheme(),
          darkTheme: recenterDarkTheme(),
          themeMode: controller.settings.themeMode,
          home: controller.settings.onboardingComplete
              ? HomeScreen(controller: controller)
              : OnboardingScreen(controller: controller),
        );
      },
    );
  }
}
