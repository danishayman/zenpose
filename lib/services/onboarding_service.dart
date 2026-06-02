import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService._internal();

  static final OnboardingService instance = OnboardingService._internal();

  static const String _completedKey = 'zenpose_onboarding_completed_v1';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
