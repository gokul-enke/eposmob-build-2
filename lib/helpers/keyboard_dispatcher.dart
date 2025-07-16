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
      debugPrint("[KeyboardDispatcher] Key Event: ${event.logicalKey.keyLabel}");

      // Buffer characters
      if (event.logicalKey.keyLabel.isNotEmpty &&
          event.logicalKey.keyLabel.length == 1) {
        _buffer.write(event.logicalKey.keyLabel);
        debugPrint("[KeyboardDispatcher] Buffer: ${_buffer.toString()}");
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        debugPrint("[KeyboardDispatcher] Enter key detected.");
        // On Enter, process the barcode
        final barcode = _buffer.toString();
        _buffer.clear();

        if (barcode.isNotEmpty) {
          debugPrint("[KeyboardDispatcher] Processing barcode: $barcode");
          try {
            context.read<BarcodeProvider>().addBarcode(barcode);
            debugPrint(
                "[KeyboardDispatcher] Called addProductByBarcode for '$barcode'");
          } catch (e) {
            debugPrint("[KeyboardDispatcher] Error calling provider: $e");
          }
        } else {
          debugPrint("[KeyboardDispatcher] Barcode buffer was empty.");
        }
      }

      // Clear buffer if there's a pause (e.g., 50ms) to prevent partial scans from sticking around
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () {
        if (_buffer.isNotEmpty) {
          debugPrint("[KeyboardDispatcher] Clearing buffer due to timeout.");
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
