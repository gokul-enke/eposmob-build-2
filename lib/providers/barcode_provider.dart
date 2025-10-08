import 'dart:async';
import 'package:flutter/material.dart';

class BarcodeProvider with ChangeNotifier {
  final _barcodeController = StreamController<String>.broadcast();

  Stream<String> get barcodeStream => _barcodeController.stream;

  void addBarcode(String barcode) {
    debugPrint("🟢 [BarcodeProvider] ========== BARCODE RECEIVED ==========");
    debugPrint("🟢 [BarcodeProvider] Barcode: '$barcode'");
    debugPrint("🟢 [BarcodeProvider] Barcode length: ${barcode.length}");
    debugPrint("🟢 [BarcodeProvider] Adding to stream...");
    _barcodeController.add(barcode);
    debugPrint("🟢 [BarcodeProvider] Barcode added to stream successfully");
    debugPrint("🟢 [BarcodeProvider] ========================================\n");
  }

  @override
  void dispose() {
    debugPrint("🟢 [BarcodeProvider] Disposing BarcodeProvider");
    _barcodeController.close();
    super.dispose();
  }
}
