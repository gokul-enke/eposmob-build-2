import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeyboardFocusHighlightProvider extends ChangeNotifier {
  static const String preferenceKey = 'keyboard_focus_highlight_enabled';

  bool _enabled = true;
  bool _isLoaded = false;

  bool get enabled => _enabled;
  bool get isLoaded => _isLoaded;

  KeyboardFocusHighlightProvider() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(preferenceKey) ?? true;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value && _isLoaded) return;
    _enabled = value;
    _isLoaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, value);
  }
}
