import 'dart:convert';

/// Formats a saved order's stored `paymentMethod` into a short human-readable
/// summary for the orders list (e.g. "Cash 100.00, Card 50.00", or "Cash").
///
/// Extracted verbatim from `orders_tab.dart`'s `_formatPaymentSummary` so the
/// multi-payment JSON parsing is pure and unit-testable.
String formatOrderPaymentSummary(String? paymentMethod) {
  if (paymentMethod == null || paymentMethod.isEmpty) return 'N/A';
  try {
    if (paymentMethod.trim().startsWith('{')) {
      final map = jsonDecode(paymentMethod) as Map<String, dynamic>;
      final methods = List<String>.from(map['methods'] ?? const []);
      final amounts = Map<String, dynamic>.from(map['amounts'] ?? const {});
      final parts = <String>[];
      for (final m in methods) {
        final raw = amounts[m];
        final num? val = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
        if (val != null && val > 0) {
          final label = m[0] + m.substring(1).toLowerCase();
          parts.add('$label ${val.toStringAsFixed(2)}');
        } else {
          final label = m[0] + m.substring(1).toLowerCase();
          parts.add(label);
        }
      }
      if (parts.isEmpty) return 'Multiple';
      // Avoid overly long text
      return parts.length > 3
          ? parts.take(3).join(', ') + ' +' + (parts.length - 3).toString()
          : parts.join(', ');
    }
  } catch (_) {
    // Fall through to simple handling
  }
  final up = paymentMethod.toUpperCase();
  switch (up) {
    case 'CASH':
    case 'CARD':
    case 'UPI':
    case 'DEBIT':
      return up[0] + up.substring(1).toLowerCase();
    default:
      return paymentMethod;
  }
}
