import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pre-fills demo credentials in debug builds when nothing is saved yet.
class DebugLoginAutofill {
  DebugLoginAutofill._();

  static const String demoApiKey =
      'DEMO_FUNZCART_vqguo7a24ezI8a69o2q0FlQsPXPZRzrw';
  static const String demoEmail = 'salesexecutive2@funzcart.in';
  static const String demoPassword = '123456';

  static Future<void> applyApiKeyIfNeeded(
    TextEditingController controller,
  ) async {
    if (!kDebugMode) return;

    final prefs = await SharedPreferences.getInstance();
    final savedApiKey = prefs.getString('api_key');
    if (savedApiKey != null && savedApiKey.trim().isNotEmpty) return;
    if (controller.text.trim().isNotEmpty) return;

    controller.text = demoApiKey;
  }

  static Future<void> applyLoginIfNeeded({
    required TextEditingController emailController,
    required TextEditingController passwordController,
  }) async {
    if (!kDebugMode) return;

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('emailRemember') ?? '';
    final savedPassword = prefs.getString('passwordRemember') ?? '';

    if (rememberMe &&
        savedEmail.trim().isNotEmpty &&
        savedPassword.isNotEmpty) {
      return;
    }

    if (emailController.text.trim().isNotEmpty ||
        passwordController.text.trim().isNotEmpty) {
      return;
    }

    emailController.text = demoEmail;
    passwordController.text = demoPassword;
  }
}
