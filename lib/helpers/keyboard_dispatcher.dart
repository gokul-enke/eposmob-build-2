import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
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

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Check if any text field has focus - if so, don't intercept keyboard events
      final primaryFocus = FocusManager.instance.primaryFocus;

      final focusedWidget = primaryFocus?.context?.widget;
      final isEditable = focusedWidget is EditableText;

      if (isEditable) {
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

  @override
  Widget build(BuildContext context) => RawKeyboardListener(
        autofocus: true,
        focusNode: _focusNode,
        onKey: _onKey,
        child: widget.child,
      );
}
