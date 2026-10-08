import 'package:flutter/material.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

class LocalOrderDetailInputs {
  const LocalOrderDetailInputs(
      {required this.order,
      required this.currency,
      required this.record,
      required this.methodLabel,
      required this.onPrint,
      required this.onDelete,
      required this.onClose});
  final SavedOrder order;
  final String currency;
  final LocalSaleSyncRecord? record;
  final String Function(String) methodLabel;
  final VoidCallback onPrint, onDelete, onClose;
}
