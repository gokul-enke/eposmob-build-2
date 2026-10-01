import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';

import '../../../../domain/models/customer_list.dart';
import '../../../state/customer_transactions_controller.dart';

/// Display helpers for one [CustomerTransaction].
abstract final class TransactionLabels {
  static String reference(CustomerTransaction transaction) {
    final value = transaction.referenceId;
    return value == null || value.isEmpty
        ? 'customer_transactions.label_no_reference'.tr
        : value;
  }

  static String date(CustomerTransaction transaction) =>
      DateHelper.formatISODate(transaction.date ?? '');

  /// The amount as the API sends it (keeps its sign) plus the currency.
  static String amount(CustomerTransaction transaction) =>
      '${transaction.amount ?? ''} ${transaction.currency ?? ''}'.trim();

  static Color amountColor(CustomerTransaction transaction) =>
      CustomerTransactionsController.isCredit(transaction)
          ? AppColors.green
          : AppColors.red;

  static String orNa(String? value) =>
      value == null || value.isEmpty ? 'general.na'.tr : value;

  static IconData icon(String? type) => switch (type?.toLowerCase()) {
        'sale' => Icons.shopping_cart_checkout,
        'refund' => Icons.replay_circle_filled_outlined,
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

/// Status pill of a transaction.
class TransactionStatusBadge extends StatelessWidget {
  const TransactionStatusBadge({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: TransactionLabels.orNa(status),
        tone: TransactionLabels.statusTone(status),
      );
}

/// Round icon tile for a transaction type.
class TransactionTypeIcon extends StatelessWidget {
  const TransactionTypeIcon({super.key, required this.type, this.size = 40});

  final String? type;
  final double size;

  @override
  Widget build(BuildContext context) => AppIconTile(
        icon: TransactionLabels.icon(type),
        size: size,
        radius: size / 2,
        background: AppColors.softBlue,
        foreground: AppColors.primary,
      );
}
