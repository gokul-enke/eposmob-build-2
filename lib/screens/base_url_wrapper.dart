import 'package:flutter/material.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/screens/api_key_screen.dart';
import 'login/login.dart';

class BaseUrlWrapper extends StatefulWidget {
  const BaseUrlWrapper({super.key});

  @override
  State<BaseUrlWrapper> createState() => _BaseUrlWrapperState();
}

class _BaseUrlWrapperState extends State<BaseUrlWrapper> {
  bool? _hasApiKey;
  final SharedPreferenceProvider _prefs = SharedPreferenceProvider();

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    try {
      bool hasKey = await _prefs.hasApiKey();
      setState(() {
        _hasApiKey = hasKey;
      });
    } catch (e) {
      setState(() {
        _hasApiKey = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasApiKey == null) {
      // Loading state
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_hasApiKey == true) {
      // API key exists, go to login
      return const SignInScreen();
    } else {
      // No API key, show setup screen
      return const ApiKeyScreen();
    }
  }
}