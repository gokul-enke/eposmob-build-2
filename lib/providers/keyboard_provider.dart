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
  final bool _enablePersistence;
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

  // Focus listener state – generation counter so the latest focus always wins
  // even when multiple focus changes happen in the same frame.
  int _focusCheckGeneration = 0;

  // WidgetsBindingObserver to catch system keyboard opening
  _KeyboardSuppressorObserver? _bindingObserver;

  bool _isDisposed = false;
  bool _focusListenerInstalled = false;
  bool _physicalKeyboardConnected = false;

  static const MethodChannel _hardwareKeyboardChannel =
      MethodChannel('com.enke.cloudposai/keyboard');
  final TextInputControl _virtualKeyboardInputControl =
      _VirtualKeyboardTextInputControl();

  // Constructor – load persisted preferences
  KeyboardProvider({bool enablePersistence = true})
      : _enablePersistence = enablePersistence {
    // The in-memory default is enabled, so apply it synchronously. Waiting for
    // Hive left a startup window in which Android's IME could open first.
    _applySystemKeyboardPolicy();
    _startListeningToFocus();
    _listenForPhysicalKeyboardChanges();
    if (_enablePersistence) {
      _initHive();
    }
  }

  Future<void> _initHive() async {
    try {
      // Open or get existing box lazily – using a simple untyped box for primitives
      _settingsBox = await Hive.openBox('keyboard_settings');

      if (_isDisposed) {
        return;
      }

      // Restore persisted values. If the key is absent, keep the in-memory
      // value (e.g. login/api-key screens call featureOff() before Hive opens).
      if (_settingsBox!.containsKey('showKeyboardFeature')) {
        _showKeyboardFeature = _settingsBox!.get('showKeyboardFeature') as bool;
      }

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

      // Apply global keyboard control based on the persisted preference.
      _applySystemKeyboardPolicy();
      if (_showKeyboardFeature) {
        _startListeningToFocus();
      } else {
        _stopListeningToFocus();
      }

      // Notify listeners so UI rebuilds with restored settings
      if (!_isDisposed) {
        notifyListeners();
      }
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
  bool get physicalKeyboardConnected => _physicalKeyboardConnected;
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
    _applySystemKeyboardPolicy();
    _startListeningToFocus();
    notifyListeners();
  }

  void featureOff() {
    _showKeyboardFeature = false;
    // Ensure keyboard is hidden when feature is turned off
    if (_showKeyboard) hide();
    _settingsBox?.put('showKeyboardFeature', false);
    _applySystemKeyboardPolicy();
    _stopListeningToFocus();
    notifyListeners();
  }

  /// Shows the virtual keyboard for the given controller.
  /// Note: The controller should be managed (created/disposed) by the calling widget.
  /// [replaceOnFirstInput] - if true, the first keystroke will replace all existing text
  void show(String type, TextEditingController controller,
      {bool replaceOnFirstInput = false}) {
    try {
      // This will throw if controller is disposed
      controller.text;

      // Normalize aliases used across the app ('numeric' → 'number').
      final normalizedType =
          (type == 'numeric' || type == 'number') ? 'number' : 'text';

      // Already showing for this controller with the same options – no-op.
      if (_showKeyboard &&
          identical(_controller, controller) &&
          _keyboardType == normalizedType &&
          _shouldReplaceOnFirstInput == replaceOnFirstInput) {
        return;
      }

      _showKeyboard = true;
      _keyboardType = normalizedType;
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
    if (!_showKeyboard && _controller == null) return;
    _showKeyboard = false;
    _controller = null;
    _shouldReplaceOnFirstInput = false;
    // Keep the OS keyboard suppressed when the feature is on.
    if (_showKeyboardFeature) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
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
    _isDisposed = true;
    _hardwareKeyboardChannel.setMethodCallHandler(null);
    // Do not leave a process-wide custom input control installed after the
    // provider that owns it has gone away (important for tests and hot reload).
    TextInput.restorePlatformInputControl();
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

  /// Installs a no-op visual input control before a field asks Flutter to show
  /// the platform IME. Unlike calling `TextInput.hide` after a metrics change,
  /// this prevents the Android keyboard from appearing in the first place.
  ///
  /// A connected physical keyboard also suppresses the platform IME, but does
  /// not alter [_showKeyboardFeature]. The app's virtual keyboard therefore
  /// remains controlled exclusively by its own Boolean.
  void _applySystemKeyboardPolicy() {
    final suppressSystemKeyboard =
        _showKeyboardFeature || _physicalKeyboardConnected;
    if (suppressSystemKeyboard) {
      TextInput.setInputControl(_virtualKeyboardInputControl);
      _installKeyboardSuppressor();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } else {
      TextInput.restorePlatformInputControl();
      _removeKeyboardSuppressor();
    }
  }

  void _listenForPhysicalKeyboardChanges() {
    _hardwareKeyboardChannel.setMethodCallHandler((call) async {
      if (call.method == 'physicalKeyboardChanged') {
        _setPhysicalKeyboardConnected(call.arguments == true);
      }
    });

    _hardwareKeyboardChannel
        .invokeMethod<bool>('isPhysicalKeyboardConnected')
        .then((connected) => _setPhysicalKeyboardConnected(connected ?? false))
        .catchError((Object _) {
      // The channel exists only on Android. Other platforms keep their normal
      // behavior, with suppression still following the feature Boolean.
    });
  }

  void _setPhysicalKeyboardConnected(bool connected) {
    if (_isDisposed || _physicalKeyboardConnected == connected) return;
    _physicalKeyboardConnected = connected;
    _applySystemKeyboardPolicy();
    notifyListeners();
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
    if (_focusListenerInstalled) return;
    FocusManager.instance.addListener(_onGlobalFocusChange);
    _focusListenerInstalled = true;
  }

  void _stopListeningToFocus() {
    if (!_focusListenerInstalled) return;
    FocusManager.instance.removeListener(_onGlobalFocusChange);
    _focusListenerInstalled = false;
  }

  void _onGlobalFocusChange() {
    if (!_showKeyboardFeature) return;

    // Eagerly dismiss system keyboard on every focus change so it never
    // appears even briefly while we determine the new field.
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Bump generation so every focus change schedules a fresh check.
    // Previously a boolean latch dropped later focus changes in the same
    // frame (e.g. dialog auto-focuses quantity, then price.requestFocus()).
    final int generation = ++_focusCheckGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || generation != _focusCheckGeneration) return;
      _autoShowForFocusedField();
    });
  }

  void _autoShowForFocusedField() {
    if (!_showKeyboardFeature) return;

    final FocusNode? focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) {
      if (_showKeyboard) hide();
      return;
    }

    // A scope holding primary focus means no concrete field is focused yet
    // (e.g. a dialog route that just opened). Never guess by searching the
    // scope's subtree – that binds the *first* EditableText in tree order
    // (quantity) instead of the field that will actually receive focus
    // (price). Wait for the real field's own focus event.
    if (focusNode is FocusScopeNode) return;

    final BuildContext? ctx = focusNode.context;
    if (ctx == null) {
      // Focus moved onto a non-widget target (e.g. keyboard key). Keep the
      // current binding so typing continues to go to the active field.
      return;
    }

    // A TextField attaches its FocusNode to a Focus widget created *inside*
    // EditableText.build, so the owning EditableText is the nearest
    // ancestor of the focus node's context – never a descendant. Walking up
    // is also precise: it can only ever find the field that truly has focus,
    // unlike a subtree search which grabs unrelated fields (the whole-app
    // search from KeyboardDispatcher's focus node used to bind the product
    // search field and pop an alphanumeric keyboard after dialogs closed).
    EditableText? editableText;
    if (ctx.widget is EditableText) {
      editableText = ctx.widget as EditableText;
    }
    editableText ??= ctx.findAncestorWidgetOfExactType<EditableText>();

    if (editableText != null) {
      final controller = editableText.controller;

      // Skip if already showing for this exact controller
      if (_showKeyboard && identical(_controller, controller)) return;

      final type =
          isNumericKeyboardType(editableText.keyboardType) ? 'number' : 'text';
      show(type, controller);
    }
    // If focus left every EditableText (button, list, keyboard chrome), keep
    // the current binding. Callers must hide() explicitly on dialog close so
    // key taps on the virtual keyboard do not tear it down mid-entry.
  }

  /// True for [TextInputType.number], [TextInputType.phone], and
  /// [TextInputType.numberWithOptions] (decimal/signed variants share the
  /// number index but fail `== TextInputType.number`).
  static bool isNumericKeyboardType(TextInputType inputType) {
    return inputType.index == TextInputType.number.index ||
        inputType.index == TextInputType.phone.index;
  }
}

/// Replaces Flutter's visual/platform text input control while retaining the
/// normal EditableText connection. Direct controller edits from the virtual
/// keyboard and key events from a USB/Bluetooth keyboard continue to work.
class _VirtualKeyboardTextInputControl with TextInputControl {}

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
