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
      debugPrint("🔵 [KeyboardDispatcher] ========== KEY EVENT START ==========");
      debugPrint("🔵 [KeyboardDispatcher] Key: ${event.logicalKey.keyLabel}");
      debugPrint("🔵 [KeyboardDispatcher] Key ID: ${event.logicalKey.keyId}");

      // Check if any text field has focus - if so, don't intercept keyboard events
      final currentFocus = FocusScope.of(context);
      debugPrint("🔵 [KeyboardDispatcher] FocusScope.hasFocus: ${currentFocus.hasFocus}");
      debugPrint("🔵 [KeyboardDispatcher] FocusScope.hasPrimaryFocus: ${currentFocus.hasPrimaryFocus}");
      
      if (currentFocus.hasFocus && currentFocus.hasPrimaryFocus == false) {
        // A text field has focus, let it handle the keyboard events
        debugPrint("⚠️ [KeyboardDispatcher] Text field has focus, passing through event");
        debugPrint("🔵 [KeyboardDispatcher] ========== KEY EVENT END (SKIPPED) ==========\n");
        return;
      }

      debugPrint("✅ [KeyboardDispatcher] No text field focus - will process key");

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
        debugPrint("⚠️ [KeyboardDispatcher] Special key detected, passing through");
        debugPrint("🔵 [KeyboardDispatcher] ========== KEY EVENT END (SPECIAL KEY) ==========\n");
        return;
      }

      // Buffer characters for barcode scanning
      if (event.logicalKey.keyLabel.isNotEmpty &&
          event.logicalKey.keyLabel.length == 1) {
        _buffer.write(event.logicalKey.keyLabel);
        debugPrint("📝 [KeyboardDispatcher] Character buffered: ${event.logicalKey.keyLabel}");
        debugPrint("📝 [KeyboardDispatcher] Current buffer: '${_buffer.toString()}'");
        debugPrint("📝 [KeyboardDispatcher] Buffer length: ${_buffer.length}");
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        debugPrint("🎯 [KeyboardDispatcher] ========== ENTER KEY DETECTED ==========");
        // On Enter, process the barcode
        final barcode = _buffer.toString();
        debugPrint("🎯 [KeyboardDispatcher] Final buffer before clear: '$barcode'");
        debugPrint("🎯 [KeyboardDispatcher] Buffer length: ${barcode.length}");
        _buffer.clear();
        debugPrint("🎯 [KeyboardDispatcher] Buffer cleared");

        if (barcode.isNotEmpty) {
          debugPrint("✅ [KeyboardDispatcher] Processing barcode: '$barcode'");
          try {
            context.read<BarcodeProvider>().addBarcode(barcode);
            debugPrint("✅ [KeyboardDispatcher] Successfully sent barcode to BarcodeProvider");
          } catch (e) {
            debugPrint("❌ [KeyboardDispatcher] Error calling provider: $e");
          }
        } else {
          debugPrint("⚠️ [KeyboardDispatcher] Barcode buffer was empty - nothing to process");
        }
        debugPrint("🎯 [KeyboardDispatcher] ========== ENTER KEY PROCESSING DONE ==========");
      } else {
        debugPrint("⚠️ [KeyboardDispatcher] Unhandled key: ${event.logicalKey.keyLabel}");
      }

      // Clear buffer if there's a pause (e.g., 100ms) to prevent partial scans from sticking around
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () {
        if (_buffer.isNotEmpty) {
          debugPrint("⏱️ [KeyboardDispatcher] Timeout reached - clearing buffer: '${_buffer.toString()}'");
          _buffer.clear();
        }
      });
      
      debugPrint("🔵 [KeyboardDispatcher] ========== KEY EVENT END ==========\n");
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
