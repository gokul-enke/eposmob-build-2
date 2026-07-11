import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';

/// Desktop payment-modal helpers — mirrors [BillingMobilePaymentController]
/// but targets the dialog's SVG tile rows and local modal state.
class BillingDesktopPaymentController {
  const BillingDesktopPaymentController();

  static const Set<String> coreCollectedCodes = {'CASH', 'CARD', 'UPI', 'COD'};

  bool isCoreCollectedCode(String code) =>
      coreCollectedCodes.contains(code.toUpperCase());

  /// Syncs store-specific backend ids for the four typed collected methods.
  void syncPaymentMethodIdsFromModels(
    BillingProvider bp,
    List<PaymentMethod> methods,
  ) {
    String? cashId;
    String? cardId;
    String? upiId;
    String? codId;
    for (final method in methods) {
      if (method.id.isEmpty) continue;
      switch (method.code.toUpperCase()) {
        case 'CASH':
          cashId = method.id;
          break;
        case 'CARD':
          cardId = method.id;
          break;
        case 'UPI':
          upiId = method.id;
          break;
        case 'COD':
          codId = method.id;
          break;
      }
    }
    bp.updatePaymentMethodIds(
      cashId: cashId,
      cardId: cardId,
      upiId: upiId,
      codId: codId,
    );
  }

  /// Rows rendered in the desktop payment modal (terminal methods excluded).
  List<DesktopPaymentRow> modalRows({
    required List<PaymentMethod> methods,
    required bool toCustomerCreditEnabled,
    required bool Function(String code, {String? methodId}) isSelected,
    required TextEditingController Function(String code, {String? methodId})
        controllerFor,
    required FocusNode? Function(String code, {String? methodId}) focusNodeFor,
    required String Function(String code) rowKeyFor,
  }) {
    final rows = <DesktopPaymentRow>[];

    for (final method in methods) {
      if (method.behavior == PaymentBehavior.terminal) continue;

      final code = method.code.toUpperCase();
      final isCore = isCoreCollectedCode(code);
      final methodId = isCore ? null : (method.id.isNotEmpty ? method.id : code);

      if (method.behavior == PaymentBehavior.credit) {
        if (toCustomerCreditEnabled) continue;
      }

      rows.add(
        DesktopPaymentRow(
          method: method,
          code: code,
          methodId: methodId,
          rowKey: rowKeyFor(code),
          label: _labelFor(method),
          iconAsset: iconAssetForMethod(method),
          controller: controllerFor(code, methodId: methodId),
          focusNode: focusNodeFor(code, methodId: methodId),
          selected: isSelected(code, methodId: methodId),
          readOnly: method.behavior == PaymentBehavior.credit,
        ),
      );
    }

    return rows;
  }

  String _labelFor(PaymentMethod method) {
    if (method.label.isNotEmpty) return method.label;
    switch (method.code.toUpperCase()) {
      case 'CASH':
        return 'billing.cash'.tr;
      case 'CARD':
        return 'billing.card'.tr;
      case 'UPI':
        return 'billing.upi'.tr;
      case 'COD':
        return 'COD';
      default:
        return method.code;
    }
  }

  /// SVG asset path for a payment-method tile.
  String iconAssetForMethod(PaymentMethod method) {
    final key =
        (method.iconKey ?? method.code).trim().toLowerCase();
    if (key.contains('cash') || key.contains('cod') || key.contains('ship')) {
      return ImageAssets.cashIcon;
    }
    if (key.contains('card') ||
        key.contains('upi') ||
        key.contains('qr') ||
        key.contains('wallet') ||
        key.contains('bank') ||
        key.contains('debit') ||
        key.contains('credit')) {
      return ImageAssets.creditCardIcon;
    }
    return ImageAssets.creditCardIcon;
  }

  /// Ordered collected rows (CASH/CARD/UPI/COD + dynamic) for keyboard shortcuts.
  List<DesktopPaymentRow> shortcutRows(List<DesktopPaymentRow> rows) {
    return rows
        .where((r) => r.method.behavior == PaymentBehavior.collected)
        .toList();
  }

  String? shortcutLabelForRow(List<DesktopPaymentRow> shortcutRows, int index) {
    if (index < 0 || index >= shortcutRows.length) return null;
    return 'C+${index + 1}';
  }

  /// Whether the transaction-reference field should be visible.
  bool shouldShowTransactionReference({
    required List<DesktopPaymentRow> rows,
    required bool Function(String code, {String? methodId}) isSelected,
  }) {
    for (final row in rows) {
      if (!isSelected(row.code, methodId: row.methodId)) continue;
      if (row.method.requiresReference) return true;
      final code = row.code.toUpperCase();
      if (code == 'CARD' || code == 'UPI') return true;
    }
    return false;
  }

  /// Fills CASH with the full cart total (quick cashier action).
  void fillExactCash({
    required double cartTotal,
    required void Function(String code, bool selected) setSelected,
    required TextEditingController cashController,
    required void Function(String? methodKey, String? amount) setPristine,
    required void Function() clearOthers,
  }) {
    clearOthers();
    setSelected('CASH', true);
    if (cartTotal > 0) {
      final totalStr = cartTotal.toStringAsFixed(2);
      cashController.text = totalStr;
      setPristine('cash', totalStr);
    } else {
      cashController.clear();
      setPristine(null, null);
    }
  }

  /// Clears all collected payment selections and amounts.
  void clearAllCollectedPayments({
    required Iterable<DesktopPaymentRow> rows,
    required void Function(String code, bool selected) setSelected,
    required void Function(String methodId) clearExtra,
  }) {
    for (final row in rows) {
      if (row.method.behavior != PaymentBehavior.collected) continue;
      if (row.methodId != null) {
        clearExtra(row.methodId!);
      } else {
        setSelected(row.code, false);
      }
      row.controller.clear();
    }
  }
}

/// A single row in the desktop payment modal, driven by [PaymentMethod].
class DesktopPaymentRow {
  const DesktopPaymentRow({
    required this.method,
    required this.code,
    required this.methodId,
    required this.rowKey,
    required this.label,
    required this.iconAsset,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.readOnly,
  });

  final PaymentMethod method;
  final String code;
  final String? methodId;
  final String rowKey;
  final String label;
  final String iconAsset;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool selected;
  final bool readOnly;
}
