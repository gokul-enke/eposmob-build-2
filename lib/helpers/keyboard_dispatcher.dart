import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:provider/provider.dart';

class KeyboardDispatcher extends StatefulWidget {
  final Widget child;
  const KeyboardDispatcher({super.key, required this.child});

  @override
  State<KeyboardDispatcher> createState() => _KeyboardDispatcherState();
}

class _KeyboardDispatcherState extends State<KeyboardDispatcher> {
  final StringBuffer _buffer = StringBuffer();
  Timer? _debounce;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final editable = _focusedEditableText();
      if (editable != null) {
        final keyboardProvider =
            Provider.of<KeyboardProvider>(context, listen: false);
        if (keyboardProvider.showKeyboardFeature ||
            keyboardProvider.physicalKeyboardConnected) {
          _insertPrintableCharacter(event, editable);
        }
        return;
      }

      // Keep focused dialog fields usable during receipt handling. Only the
      // unfocused barcode path is paused; never carry a partial scan past it.
      if (OrderSubmissionCoordinator.instance.isBusy) {
        _debounce?.cancel();
        _buffer.clear();
        return;
      }

      // Handle special keys that should not be buffered
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.shift ||
          event.logicalKey == LogicalKeyboardKey.control ||
          event.logicalKey == LogicalKeyboardKey.alt ||
          event.logicalKey == LogicalKeyboardKey.meta) {
        // Don't buffer these keys, just pass them through
        return;
      }

      // Buffer characters for barcode scanning
      if (event.logicalKey.keyLabel.isNotEmpty &&
          event.logicalKey.keyLabel.length == 1) {
        _buffer.write(event.logicalKey.keyLabel);
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // On Enter, process the barcode
        final barcode = _buffer.toString();
        _buffer.clear();

        if (barcode.isNotEmpty) {
          try {
            context.read<BarcodeProvider>().addBarcode(barcode);
          } catch (e) {
            debugPrint("❌ [KeyboardDispatcher] Error calling provider: $e");
          }
        }
      }

      // Clear buffer if there's a pause (e.g., 100ms) to prevent partial scans from sticking around
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () {
        if (_buffer.isNotEmpty) {
          _buffer.clear();
        }
      });
    }
  }

  EditableText? _focusedEditableText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    if (context.widget is EditableText) {
      return context.widget as EditableText;
    }
    return context.findAncestorWidgetOfExactType<EditableText>();
  }

  /// Flutter's custom [TextInputControl] prevents Android from creating a
  /// platform input connection. Printable USB/Bluetooth key events therefore
  /// need to be applied to the focused EditableText here. Navigation,
  /// deletion, selection and clipboard shortcuts remain handled by
  /// EditableText's standard shortcut/action system.
  void _insertPrintableCharacter(KeyDownEvent event, EditableText editable) {
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return;
    }

    String? character = event.character;
    if (character == null || character.isEmpty) {
      final label = event.logicalKey.keyLabel;
      if (label.length != 1) return;
      character = HardwareKeyboard.instance.isShiftPressed
          ? label.toUpperCase()
          : label.toLowerCase();
    }

    // Control characters (Enter, Tab, Escape, etc.) are handled by the normal
    // EditableText action system, not inserted into single-line fields.
    if (character.codeUnitAt(0) < 0x20) return;

    final oldValue = editable.controller.value;
    final selection = oldValue.selection.isValid
        ? oldValue.selection
        : TextSelection.collapsed(offset: oldValue.text.length);
    var newValue = oldValue.copyWith(
      text: selection.textBefore(oldValue.text) +
          character +
          selection.textAfter(oldValue.text),
      selection: TextSelection.collapsed(
        offset: selection.start + character.length,
      ),
      composing: TextRange.empty,
    );

    for (final formatter in editable.inputFormatters ?? const []) {
      newValue = formatter.formatEditUpdate(oldValue, newValue);
    }
    if (newValue != oldValue) {
      editable.controller.value = newValue;
      // Updating the controller directly bypasses EditableText's normal
      // user-editing pipeline, so preserve the field callback explicitly.
      if (newValue.text != oldValue.text) {
        editable.onChanged?.call(newValue.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: widget.child,
      );
}
