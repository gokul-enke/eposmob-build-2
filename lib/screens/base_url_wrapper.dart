import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_url_screen.dart';
import 'login/login.dart';

class BaseUrlWrapper extends StatefulWidget {
  const BaseUrlWrapper({super.key});

  @override
  State<BaseUrlWrapper> createState() => _BaseUrlWrapperState();
}

class _BaseUrlWrapperState extends State<BaseUrlWrapper> {
  bool? _isBaseURLSet;

  @override
  void initState() {
    super.initState();
    _checkBaseURL();
  }

  Future<void> _checkBaseURL() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseURL = "https://epos.enke.ae";
    // String? baseURL = null;
    // String? baseURL = prefs.getString('baseURL');
    setState(() {
      _isBaseURLSet = baseURL != null && baseURL.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBaseURLSet == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_isBaseURLSet == true) {
      return const SignInScreen();
    } else {
      return BaseURLScreen();
    }
  }
}
