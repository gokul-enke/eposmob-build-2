import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:virtual_keyboard_custom_layout/virtual_keyboard_custom_layout.dart';
import 'package:hive/hive.dart';

/// Manages the state and visibility of a virtual keyboard.
/// This provider does not own the TextEditingController instances - they should be
/// created, managed and disposed by the widgets that use the keyboard.
///
/// **Global keyboard control**: When the feature is enabled via [featureOn],
/// the system keyboard is suppressed via [SystemChannels.textInput] and a
/// [FocusManager] listener auto-shows the virtual keyboard whenever any text
/// field gains focus. Individual fields do NOT need `readOnly`, `onTap`,
/// or `useSystemKeyboard` overrides.
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

  // Focus listener state
  bool _focusCheckScheduled = false;

  // WidgetsBindingObserver to catch system keyboard opening
  _KeyboardSuppressorObserver? _bindingObserver;

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

      // Apply global keyboard control based on persisted preference
      if (_showKeyboardFeature) {
        _installKeyboardSuppressor();
        _startListeningToFocus();
      }

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
    _installKeyboardSuppressor();
    _startListeningToFocus();
    notifyListeners();
  }

  void featureOff() {
    _showKeyboardFeature = false;
    // Ensure keyboard is hidden when feature is turned off
    if (_showKeyboard) hide();
    _settingsBox?.put('showKeyboardFeature', false);
    _removeKeyboardSuppressor();
    _stopListeningToFocus();
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
    _removeKeyboardSuppressor();
    _stopListeningToFocus();
    // Clear references but don't dispose the controller as we don't own it
    _controller = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // System keyboard suppression – uses a WidgetsBindingObserver to detect
  // when the OS keyboard metrics change (i.e. keyboard appearing) and
  // immediately hides it via the platform channel.
  // ---------------------------------------------------------------------------

  void _installKeyboardSuppressor() {
    if (_bindingObserver != null) return;
    _bindingObserver = _KeyboardSuppressorObserver(this);
    WidgetsBinding.instance.addObserver(_bindingObserver!);
  }

  void _removeKeyboardSuppressor() {
    if (_bindingObserver == null) return;
    WidgetsBinding.instance.removeObserver(_bindingObserver!);
    _bindingObserver = null;
  }

  // ---------------------------------------------------------------------------
  // Global focus listener – auto-shows virtual keyboard for any text field
  // ---------------------------------------------------------------------------

  void _startListeningToFocus() {
    FocusManager.instance.addListener(_onGlobalFocusChange);
  }

  void _stopListeningToFocus() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
  }

  void _onGlobalFocusChange() {
    if (!_showKeyboardFeature) return;

    // Eagerly dismiss system keyboard on every focus change so it never
    // appears even briefly while we determine the new field.
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (_focusCheckScheduled) return;
    _focusCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCheckScheduled = false;
      _autoShowForFocusedField();
    });
  }

  void _autoShowForFocusedField() {
    if (!_showKeyboardFeature) return;

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) return;

    final ctx = primaryFocus.context!;
    EditableText? editableText;

    // 1. Check if focused widget itself is an EditableText
    if (ctx.widget is EditableText) {
      editableText = ctx.widget as EditableText;
    }

    // 2. Check descendants (TextField wraps EditableText as a child)
    if (editableText == null) {
      void findEditableText(Element element) {
        if (editableText != null) return;
        if (element.widget is EditableText) {
          editableText = element.widget as EditableText;
          return;
        }
        element.visitChildren(findEditableText);
      }
      ctx.visitChildElements(findEditableText);
    }

    // 3. Check ancestors (edge case)
    if (editableText == null) {
      ctx.visitAncestorElements((element) {
        if (element.widget is EditableText) {
          editableText = element.widget as EditableText;
          return false;
        }
        return true;
      });
    }

    if (editableText != null) {
      final controller = editableText!.controller;

      // Skip if already showing for this exact controller
      if (_showKeyboard && identical(_controller, controller)) return;

      final type = _isNumericKeyboardType(editableText!.keyboardType)
          ? 'number'
          : 'text';
      show(type, controller);
    } else {
      // Focus moved away from a text field – hide virtual keyboard
      if (_showKeyboard) hide();
    }
  }

  static bool _isNumericKeyboardType(TextInputType inputType) {
    return inputType.index == TextInputType.number.index ||
        inputType == TextInputType.phone;
  }
}

/// Watches for system keyboard appearance via bottom inset changes and
/// immediately hides it when the virtual keyboard feature is active.
class _KeyboardSuppressorObserver extends WidgetsBindingObserver {
  final KeyboardProvider _provider;

  _KeyboardSuppressorObserver(this._provider);

  @override
  void didChangeMetrics() {
    if (!_provider._showKeyboardFeature) return;

    // When the system keyboard opens, the bottom viewInsets increase.
    // Fire hide immediately to dismiss it.
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > 0) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }
}
