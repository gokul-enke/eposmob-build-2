import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// A general payment as an accountant writes it: "Dr <account>  amount"
/// over an indented "Cr <account>  amount". A missing account reads
/// "Choose an account".
class GeneralPaymentJournal extends StatelessWidget {
  const GeneralPaymentJournal({
    super.key,
    required this.debit,
    required this.credit,
    required this.amount,
  });

  final String? debit;
  final String? credit;

  /// Formatted, e.g. "SAR 2,000.00", or "—".
  final String amount;

  Widget _line(String side, String? account, {required bool credit}) => Padding(
        padding: EdgeInsetsDirectional.only(start: credit ? AppSpacing.xxl : 0),
        child: Row(children: [
          SizedBox(
              width: 44,
              child: Text(side,
                  style: AppTextStyles.label
                      .copyWith(fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(account ?? 'general_payments.journal_choose'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                      color: account == null
                          ? AppColors.hint
                          : AppColors.heading))),
          const SizedBox(width: AppSpacing.md),
          Text(amount, style: AppTextStyles.value),
        ]),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('general_payments.journal_title'.tr,
                style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.xs),
            _line('general_payments.journal_dr'.tr, debit, credit: false),
            const SizedBox(height: AppSpacing.xxs),
            _line('general_payments.journal_cr'.tr, credit, credit: true),
          ],
        ),
      );
}
