import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../resources/app_url.dart';

class BaseURLScreen extends StatefulWidget {
  const BaseURLScreen({super.key});

  @override
  State<BaseURLScreen> createState() => _BaseURLScreenState();
}

class _BaseURLScreenState extends State<BaseURLScreen> {
  final TextEditingController _baseURLController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBaseURL();
  }

  _loadBaseURL() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseURL = prefs.getString('baseURL');
    if (baseURL != null) {
      _baseURLController.text = baseURL;
    }
  }

  _saveBaseURL() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseURL', _baseURLController.text);
    setState(() {
      APPUrl.baseURL = _baseURLController.text;
    });
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Base URL')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _baseURLController,
              decoration: const InputDecoration(labelText: 'Base URL'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveBaseURL,
              child: const Text('Save Base URL'),
            ),
          ],
        ),
      ),
    );
  }
}