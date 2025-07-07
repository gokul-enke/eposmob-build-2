import 'package:flutter/material.dart';
import 'package:virtual_keyboard_custom_layout/virtual_keyboard_custom_layout.dart';
import 'package:hive/hive.dart';

/// Manages the state and visibility of a virtual keyboard.
/// This provider does not own the TextEditingController instances - they should be
/// created, managed and disposed by the widgets that use the keyboard.
class KeyboardProvider extends ChangeNotifier {
  bool _showKeyboard = false;
  bool _showKeyboardFeature = true;
  String _keyboardType = 'text';
  TextEditingController? _controller;
  bool _shouldReplaceOnFirstInput = false;
  Size _numericKeyboardSize = const Size(450, 350);
  Size _alphanumericKeyboardSize = const Size(500, 400);

  // Persisted keyboard position (top-left anchor) – defaults to (50,200)
  Offset _keyboardPosition = const Offset(50, 200);

  // Hive box for persisting simple keyboard settings
  Box<dynamic>? _settingsBox;

  // Constructor – load persisted preferences
  KeyboardProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      // Open or get existing box lazily – using a simple untyped box for primitives
      _settingsBox = await Hive.openBox('keyboard_settings');

      // Restore persisted values (with sensible defaults if absent)
      _showKeyboardFeature = _settingsBox!.get('showKeyboardFeature', defaultValue: true);

      _numericKeyboardSize = Size(
        (_settingsBox!.get('numericWidth') ?? 450).toDouble(),
        (_settingsBox!.get('numericHeight') ?? 350).toDouble(),
      );

      _alphanumericKeyboardSize = Size(
        (_settingsBox!.get('alphaWidth') ?? 500).toDouble(),
        (_settingsBox!.get('alphaHeight') ?? 400).toDouble(),
      );

      _keyboardPosition = Offset(
        (_settingsBox!.get('posX') ?? 50).toDouble(),
        (_settingsBox!.get('posY') ?? 200).toDouble(),
      );

      // Notify listeners so UI rebuilds with restored settings
      notifyListeners();
    } catch (e) {
      // If Hive fails, fall back to defaults without crashing the app
      debugPrint('KeyboardProvider: Failed to initialise Hive – $e');
    }
  }

  // Public getters
  Offset get keyboardPosition => _keyboardPosition;

  // Update persisted position
  void setKeyboardPosition(Offset position) {
    _keyboardPosition = position;
    _settingsBox?.put('posX', position.dx);
    _settingsBox?.put('posY', position.dy);
    notifyListeners();
  }

  bool get showKeyboard => _showKeyboard;
  bool get showKeyboardFeature => _showKeyboardFeature;
  String get keyboardType => _keyboardType;
  TextEditingController? get controller => _controller;
  bool get shouldReplaceOnFirstInput => _shouldReplaceOnFirstInput;
  Size get numericKeyboardSize => _numericKeyboardSize;
  Size get alphanumericKeyboardSize => _alphanumericKeyboardSize;

  Size getKeyboardSize(VirtualKeyboardType keyboardType) {
    switch (keyboardType) {
      case VirtualKeyboardType.Numeric:
        return _numericKeyboardSize;
      case VirtualKeyboardType.Alphanumeric:
        return _alphanumericKeyboardSize;
      default:
        return _alphanumericKeyboardSize;
    }
  }

  void setKeyboardSize(VirtualKeyboardType keyboardType, Size size) {
    switch (keyboardType) {
      case VirtualKeyboardType.Numeric:
        _numericKeyboardSize = size;
        _settingsBox?.put('numericWidth', size.width);
        _settingsBox?.put('numericHeight', size.height);
        break;
      case VirtualKeyboardType.Alphanumeric:
        _alphanumericKeyboardSize = size;
        _settingsBox?.put('alphaWidth', size.width);
        _settingsBox?.put('alphaHeight', size.height);
        break;
      default:
        _alphanumericKeyboardSize = size;
        _settingsBox?.put('alphaWidth', size.width);
        _settingsBox?.put('alphaHeight', size.height);
        break;
    }
    notifyListeners();
  }

  void resetKeyboardSizes() {
    _numericKeyboardSize = const Size(450, 350);
    _alphanumericKeyboardSize = const Size(500, 400);

    // Remove persisted sizes so defaults are used next launch
    _settingsBox?.delete('numericWidth');
    _settingsBox?.delete('numericHeight');
    _settingsBox?.delete('alphaWidth');
    _settingsBox?.delete('alphaHeight');
    notifyListeners();
  }

  void featureOn() {
    _showKeyboardFeature = true;
    _settingsBox?.put('showKeyboardFeature', true);
    notifyListeners();
  }

  void featureOff() {
    _showKeyboardFeature = false;
    // Ensure keyboard is hidden when feature is turned off
    if (_showKeyboard) hide();
    _settingsBox?.put('showKeyboardFeature', false);
    notifyListeners();
  }

  /// Shows the virtual keyboard for the given controller.
  /// Note: The controller should be managed (created/disposed) by the calling widget.
  /// [replaceOnFirstInput] - if true, the first keystroke will replace all existing text
  void show(String type, TextEditingController controller,
      {bool replaceOnFirstInput = false}) {
    try {
      hide();
      // This will throw if controller is disposed
      controller.text;
      _showKeyboard = true;
      _keyboardType = type;
      _controller = controller;
      _shouldReplaceOnFirstInput = replaceOnFirstInput;
      notifyListeners();
    } catch (e) {
      debugPrint(
          'Warning: Attempted to show keyboard with disposed controller');
      return;
    }
  }

  void hide() {
    _showKeyboard = false;
    _controller = null;
    _shouldReplaceOnFirstInput = false;
    notifyListeners();
  }

  /// Clears the controller reference and replace flag when focus is lost
  void clear() {
    _controller = null;
    _shouldReplaceOnFirstInput = false;
    _showKeyboard = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Clear references but don't dispose the controller as we don't own it
    _controller = null;
    super.dispose();
  }
}
