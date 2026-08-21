import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/document_configurations.dart';

bool isKotDocumentConfigEnabled(DocumentConfig? config) {
  return config == null || config.isEnabled;
}

Future<void> invokeKotPrintSuccessCallback(
  Future<void> Function()? callback,
) async {
  if (callback == null) return;
  try {
    await callback();
  } catch (error) {
    debugPrint('[KotPrintPage] Post-print callback failed: $error');
  }
}

double calculateKotTotal(List<Map<String, dynamic>> items) {
  return items.fold<double>(0, (sum, item) {
    final explicitTotal = _asDouble(item['totalPrice'] ?? item['total_price']);
    if (explicitTotal != null) {
      return sum + explicitTotal;
    }

    final quantity = _asDouble(item['quantity']) ?? 0;
    final unitPrice = _asDouble(item['unitPrice'] ??
            item['unit_price'] ??
            item['rate'] ??
            item['price']) ??
        0;
    return sum + (quantity * unitPrice);
  });
}

String formatKotAmount(double amount) => amount.toStringAsFixed(2);

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().replaceAll(',', '').trim());
}
