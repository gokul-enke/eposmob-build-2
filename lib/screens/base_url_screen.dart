import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../resources/app_url.dart';

class BaseURLScreen extends StatefulWidget {
  @override
  _BaseURLScreenState createState() => _BaseURLScreenState();
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
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Base URL')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _baseURLController,
              decoration: InputDecoration(labelText: 'Base URL'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveBaseURL,
              child: Text('Save Base URL'),
            ),
          ],
        ),
      ),
    );
  }
}