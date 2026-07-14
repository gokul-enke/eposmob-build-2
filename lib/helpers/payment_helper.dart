import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
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

      final List<String> methods = List<String>.from(data['methods'] ?? []);
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

  /// Normalizes caller-built paid methods by deducting customer change/balance
  /// from the first cash/COD entry exactly once.
  static List<Map<String, dynamic>> normalizePaidMethodsForApi({
    required List<Map<String, dynamic>> paidMethods,
    required double balanceAmount,
    String? cashMethodId,
    String? codMethodId,
  }) {
    final normalized = paidMethods
        .map((payment) {
          final method = payment['method']?.toString().trim() ?? '';
          final rawAmount = payment['amount'];
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;

          return {
            'method': method,
            'amount': amount,
          };
        })
        .where((payment) =>
            payment['method'].toString().isNotEmpty &&
            ((payment['amount'] as num?)?.toDouble() ?? 0.0) > 0)
        .toList();

    if (balanceAmount <= 0 || normalized.isEmpty) {
      return normalized;
    }

    final normalizedCashId = cashMethodId?.trim().toUpperCase();
    final normalizedCodId = codMethodId?.trim().toUpperCase();

    final adjustmentIndex = normalized.indexWhere((payment) {
      final method = payment['method'].toString().trim().toUpperCase();
      return method == 'CASH' ||
          method == 'COD' ||
          (normalizedCashId != null &&
              normalizedCashId.isNotEmpty &&
              method == normalizedCashId) ||
          (normalizedCodId != null &&
              normalizedCodId.isNotEmpty &&
              method == normalizedCodId);
    });

    if (adjustmentIndex == -1) {
      return normalized;
    }

    final adjustedAmount =
        ((normalized[adjustmentIndex]['amount'] as num).toDouble() -
                balanceAmount)
            .clamp(0.0, double.infinity);

    normalized[adjustmentIndex] = {
      'method': normalized[adjustmentIndex]['method'].toString(),
      'amount': adjustedAmount,
    };

    return normalized
        .where(
            (payment) => ((payment['amount'] as num?)?.toDouble() ?? 0.0) > 0)
        .toList();
  }

  /// Converts locally stored payment data into the exact API fields used by
  /// order sync so saved/confirmed offline orders match online submissions.
  static ({
    String? paymentMethod,
    String? paidAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
  }) buildApiPaymentPayloadFromLocal({
    required BuildContext context,
    String? storedPaymentMethod,
    String? storedPaidAmount,
    String? storedBalanceAmount,
  }) {
    final rawPaymentMethod = storedPaymentMethod?.trim();
    final balanceAmount =
        double.tryParse(storedBalanceAmount?.trim() ?? '') ?? 0.0;

    if (rawPaymentMethod == null || rawPaymentMethod.isEmpty) {
      return (
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: null,
        paidMethods: null,
      );
    }

    if (rawPaymentMethod.startsWith('{')) {
      try {
        final Map<String, dynamic> multiPaymentData =
            json.decode(rawPaymentMethod);

        if (multiPaymentData['isMultiPayment'] == true) {
          final selectedMethods =
              List<dynamic>.from(multiPaymentData['methods'] ?? const []);
          final amounts = Map<String, dynamic>.from(
              multiPaymentData['amounts'] ?? const {});

          final normalizedMethods = <String>[];
          for (final rawMethod in selectedMethods) {
            final normalized =
                _normalizeMethodIdForApi(context, rawMethod?.toString());
            if (normalized.isNotEmpty &&
                !_isCreditOnlyMethod(normalized) &&
                !normalizedMethods.contains(normalized)) {
              normalizedMethods.add(normalized);
            }
          }

          final normalizedAmounts = <String, double>{};
          for (final entry in amounts.entries) {
            final normalized =
                _normalizeMethodIdForApi(context, entry.key.toString());
            final amount = double.tryParse(entry.value.toString()) ?? 0.0;
            if (normalized.isEmpty ||
                _isCreditOnlyMethod(normalized) ||
                amount <= 0) {
              continue;
            }

            normalizedAmounts[normalized] = amount;
            if (!normalizedMethods.contains(normalized)) {
              normalizedMethods.add(normalized);
            }
          }

          final paymentMethods = normalizedMethods
              .where((methodId) => (normalizedAmounts[methodId] ?? 0.0) > 0)
              .toList();

          final paidMethods = normalizePaidMethodsForApi(
            paidMethods: paymentMethods
                .map((methodId) => {
                      'method': methodId,
                      'amount': normalizedAmounts[methodId] ?? 0.0,
                    })
                .toList(),
            balanceAmount: balanceAmount,
            cashMethodId: _buildNameToIdMap(context)['CASH'],
            codMethodId: _buildNameToIdMap(context)['COD'],
          );

          if (paidMethods.isNotEmpty) {
            return (
              paymentMethod: null,
              paidAmount: null,
              paymentMethods: paidMethods
                  .map((payment) => payment['method'].toString())
                  .toList(),
              paidMethods: paidMethods,
            );
          }
        }
      } catch (e) {
        debugPrint('PaymentHelper: Error normalizing local payment JSON: $e');
      }

      return (
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: null,
        paidMethods: null,
      );
    }

    final normalizedMethod =
        _normalizeMethodIdForApi(context, rawPaymentMethod.toString());
    final parsedPaidAmount =
        double.tryParse(storedPaidAmount?.trim() ?? '') ?? 0.0;

    if (normalizedMethod.isEmpty ||
        _isCreditOnlyMethod(normalizedMethod) ||
        parsedPaidAmount <= 0) {
      return (
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: null,
        paidMethods: null,
      );
    }

    return (
      paymentMethod: normalizedMethod,
      paidAmount: storedPaidAmount,
      paymentMethods: null,
      paidMethods: null,
    );
  }

  /// Builds a map from payment-method numeric ID → human-readable name.
  /// Example: { "7974": "CASH", "7973": "CARD", "7975": "UPI", "7976": "COD" }
  static Map<String, String> _buildIdToNameMap(BuildContext context) {
    final map = <String, String>{};
    // Dynamic/extra methods: pull id -> value/name for every configured
    // payment method so methods beyond the typed four display by name.
    try {
      final masterData =
          Provider.of<MasterDataProvider>(context, listen: false);
      for (final method in masterData.paymentMethods ?? const []) {
        map[method.id.toString()] =
            method.description.isNotEmpty ? method.description : method.value;
      }
    } catch (_) {
      // MasterDataProvider may not be available in all contexts
    }
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
      map['CREDIT'] = 'DEBIT';
      map['ONLINE'] = 'ONLINE';
    } catch (_) {
      // BillingProvider may not be available in all contexts
    }
    return map;
  }

  static Map<String, String> _buildNameToIdMap(BuildContext context) {
    final map = <String, String>{
      'DEBIT': 'DEBIT',
      'CREDIT': 'DEBIT',
      'BALANCE': 'DEBIT',
      'ONLINE': 'ONLINE',
    };
    try {
      final billing = Provider.of<BillingProvider>(context, listen: false);
      map['CASH'] = billing.cashPaymentMethodId ?? 'CASH';
      map['CARD'] = billing.cardPaymentMethodId ?? 'CARD';
      map['UPI'] = billing.upiPaymentMethodId ?? 'UPI';
      map['COD'] = billing.codPaymentMethodId ?? 'COD';
    } catch (_) {
      map['CASH'] = 'CASH';
      map['CARD'] = 'CARD';
      map['UPI'] = 'UPI';
      map['COD'] = 'COD';
    }
    return map;
  }

  static String _normalizeMethodIdForApi(
      BuildContext context, String? rawMethod) {
    if (rawMethod == null) return '';
    final method = rawMethod.trim();
    if (method.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(method)) return method;

    final upper = method.toUpperCase();
    return _buildNameToIdMap(context)[upper] ?? method;
  }

  static bool _isCreditOnlyMethod(String methodId) {
    final upper = methodId.trim().toUpperCase();
    return upper == 'DEBIT' || upper == 'CREDIT' || upper == 'BALANCE';
  }
}
