import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/core/onboarding/onboarding_storage.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  bool showSplash = true;
  bool showOnboarding = false;
  int tabIndex = 0;

  static const Duration splashDuration = Duration(milliseconds: 2200);

  bool get isDark => themeMode == ThemeMode.dark;

  void toggleTheme() {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> handleSplashDone() async {
    final bool completed = await OnboardingStorage.hasCompleted();
    showSplash = false;
    showOnboarding = !completed;
    notifyListeners();
  }

  Future<void> handleOnboardingDone() async {
    await OnboardingStorage.setCompleted();
    showOnboarding = false;
    notifyListeners();
  }

  void selectTab(int index) {
    tabIndex = index;
    notifyListeners();
  }
}

