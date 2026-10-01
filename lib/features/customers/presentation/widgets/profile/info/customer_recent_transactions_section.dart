import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import 'customer_info_format.dart';

/// The customer's three most recent transactions (newest first) and how many
/// more there are.
class CustomerRecentTransactionsSection extends StatelessWidget {
  const CustomerRecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.fallbackCurrency,
  });

  static const int visibleCount = 3;

  /// Oldest first, as the API returns them.
  final List<CustomerTransaction> transactions;

  /// Used when a transaction has no currency of its own.
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.reversed.take(visibleCount).toList();
    final hidden = transactions.length - recent.length;

    return SectionCard(
      title: 'customer_profile.view_section_transactions'.tr,
      icon: Icons.history,
      trailing: Text(
        'customer_profile.view_transactions_count'
            .trParams({'count': '${transactions.length}'}),
        style: AppTextStyles.caption,
      ),
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.subtleBorder),
            _TransactionRow(
              transaction: recent[i],
              fallbackCurrency: fallbackCurrency,
            ),
          ],
          if (hidden > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'customer_profile.view_more_transactions_count'
                    .trParams({'count': '$hidden'}),
                textAlign: TextAlign.center,
                style: AppTextStyles.button.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.fallbackCurrency,
  });

  final CustomerTransaction transaction;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final color = CustomerInfoFormat.transactionColor(t.type);
    final isCredit = t.type?.trim().toLowerCase() == 'credit';
    final title = t.transactionType?.trim().isNotEmpty == true
        ? t.transactionType!
        : 'customer_profile.view_label_transaction'.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          AppIconTile(
            icon: CustomerInfoFormat.transactionIcon(t.type),
            size: 38,
            iconSize: 18,
            background: color.withValues(alpha: .1),
            foreground: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.value),
                const SizedBox(height: 2),
                Text(
                  '${'customer_profile.view_label_ref'.tr}: '
                  '${CustomerInfoFormat.orNotAvailable(t.referenceId)}',
                  style: AppTextStyles.caption,
                ),
                if (t.date?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(t.date!, style: AppTextStyles.sectionHint),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${t.amount ?? '0'} '
                '${t.currency ?? fallbackCurrency}',
                style: AppTextStyles.value.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(
                CustomerInfoFormat.orNotAvailable(t.paymentMethod),
                style: AppTextStyles.sectionHint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
