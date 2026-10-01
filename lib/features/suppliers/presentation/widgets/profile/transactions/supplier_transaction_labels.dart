import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import '../../../state/supplier_transactions_controller.dart';

/// Display helpers for one [SupplierTransaction].
abstract final class SupplierTransactionLabels {
  static String orNa(String? value) =>
      value == null || value.trim().isEmpty ? 'general.na'.tr : value;

  static String reference(SupplierTransaction transaction) =>
      transaction.reference.trim().isEmpty
          ? 'supplier_profile.trans_label_no_reference'.tr
          : transaction.reference;

  /// Currency and amount as the API sends them.
  static String amount(SupplierTransaction transaction) =>
      '${transaction.currency} ${transaction.amount}'.trim();

  static Color amountColor(SupplierTransaction transaction) =>
      SupplierTransactionsController.isCredit(transaction)
          ? AppColors.green
          : AppColors.red;

  static IconData icon(String? type) => switch (type?.toLowerCase()) {
        'credit' => Icons.add_circle_outline,
        'debit' => Icons.remove_circle_outline,
        'payment' => Icons.payment,
        _ => Icons.receipt_long,
      };

  static AppBadgeTone statusTone(String? status) =>
      switch (status?.toLowerCase()) {
        'succ' || 'completed' => AppBadgeTone.success,
        'fail' || 'failed' => AppBadgeTone.danger,
        'init' || 'pending' => AppBadgeTone.warning,
        _ => AppBadgeTone.neutral,
      };
}

/// Status pill of a supplier transaction.
class SupplierTransactionStatusBadge extends StatelessWidget {
  const SupplierTransactionStatusBadge({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: SupplierTransactionLabels.orNa(status),
        tone: SupplierTransactionLabels.statusTone(status),
      );
}

/// Round icon tile for a credit/debit/payment transaction.
class SupplierTransactionTypeIcon extends StatelessWidget {
  const SupplierTransactionTypeIcon({
    super.key,
    required this.type,
    this.size = 40,
  });

  final String? type;
  final double size;

  @override
  Widget build(BuildContext context) => AppIconTile(
        icon: SupplierTransactionLabels.icon(type),
        size: size,
        radius: size / 2,
        background: AppColors.softBlue,
        foreground: AppColors.primary,
      );
}
