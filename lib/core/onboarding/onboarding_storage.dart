import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has completed onboarding (first-run flow).
class OnboardingStorage {
  OnboardingStorage._();

  static const String _keyCompleted = 'onboarding_completed';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  static Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
  }
}
