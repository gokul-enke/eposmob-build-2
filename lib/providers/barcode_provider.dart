import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class BarcodeProvider with ChangeNotifier {
  final _barcodeController = StreamController<String>.broadcast();

  Stream<String> get barcodeStream => _barcodeController.stream;

  void addBarcode(String barcode) {
    if (OrderSubmissionCoordinator.instance.isBusy) return ;
    _barcodeController.add(barcode);
  }

  @override
  void dispose() {
    _barcodeController.close();
    super.dispose();
  }
}
