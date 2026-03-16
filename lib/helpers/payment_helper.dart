import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:provider/provider.dart';

/// Helper class to parse locally stored multi-payment JSON into
/// human-readable payment data suitable for receipt printing.
class PaymentHelper {
  /// Parses the raw `paymentMethod` string stored in a local SavedOrder
  /// and returns a record with:
  ///   - `paymentMethodDisplay`: a clean string like "CASH, CARD" for the customer section
  ///   - `paymentBreakdown`: a map like `{CASH: 10.0, CARD: 5.0}` for the totals box
  ///
  /// If the string is not multi-payment JSON, returns `null` so callers
  /// can fall back to passing the original value.
  static ({String paymentMethodDisplay, Map<String, dynamic> paymentBreakdown})?
      parseLocalMultiPayment(BuildContext context, String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) return null;

    // Only attempt parsing if it looks like JSON
    if (!paymentMethod.startsWith('{')) return null;

    try {
      final Map<String, dynamic> data = json.decode(paymentMethod);
      if (data['isMultiPayment'] != true) return null;

      final List<String> methods =
          List<String>.from(data['methods'] ?? []);
      final Map<String, dynamic> amounts =
          Map<String, dynamic>.from(data['amounts'] ?? {});

      // Build an ID → human-readable-name map from BillingProvider
      final idToName = _buildIdToNameMap(context);

      // Build the clean breakdown: { "CASH": 10.0, "CARD": 5.0 }
      final Map<String, dynamic> breakdown = {};
      final List<String> displayNames = [];

      for (final methodId in methods) {
        final amountStr = amounts[methodId]?.toString() ?? '0';
        final amount = double.tryParse(amountStr) ?? 0;
        if (amount <= 0) continue;

        final name = idToName[methodId] ?? methodId; // fallback to raw id
        breakdown[name] = amount;
        if (!displayNames.contains(name)) {
          displayNames.add(name);
        }
      }

      // Also pick up any amounts whose key wasn't in the methods list
      // (e.g. DEBIT stored directly)
      for (final entry in amounts.entries) {
        if (methods.contains(entry.key)) continue; // already handled
        final amount = double.tryParse(entry.value.toString()) ?? 0;
        if (amount <= 0) continue;
        final name = idToName[entry.key] ?? entry.key;
        if (!breakdown.containsKey(name)) {
          breakdown[name] = amount;
          displayNames.add(name);
        }
      }

      if (breakdown.isEmpty) return null;

      return (
        paymentMethodDisplay: displayNames.join(', '),
        paymentBreakdown: breakdown,
      );
    } catch (e) {
      debugPrint('PaymentHelper: Error parsing multi-payment JSON: $e');
      return null;
    }
  }

  /// Builds a map from payment-method numeric ID → human-readable name.
  /// Example: { "7974": "CASH", "7973": "CARD", "7975": "UPI", "7976": "COD" }
  static Map<String, String> _buildIdToNameMap(BuildContext context) {
    final map = <String, String>{};
    try {
      final billing = Provider.of<BillingProvider>(context, listen: false);
      if (billing.cashPaymentMethodId != null) {
        map[billing.cashPaymentMethodId!] = 'CASH';
      }
      if (billing.cardPaymentMethodId != null) {
        map[billing.cardPaymentMethodId!] = 'CARD';
      }
      if (billing.upiPaymentMethodId != null) {
        map[billing.upiPaymentMethodId!] = 'UPI';
      }
      if (billing.codPaymentMethodId != null) {
        map[billing.codPaymentMethodId!] = 'COD';
      }
      // DEBIT is always stored as the literal string "DEBIT"
      map['DEBIT'] = 'DEBIT';
    } catch (_) {
      // BillingProvider may not be available in all contexts
    }
    return map;
  }
}
