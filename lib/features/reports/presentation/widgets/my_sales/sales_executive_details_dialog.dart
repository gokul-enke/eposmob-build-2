import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/sales_executive_report.dart';

String _tr(String key) => 'sales_executive_report.$key'.tr;

/// Shows every total of one sales executive for [dateRange].
Future<void> showSalesExecutiveDetailsDialog(
  BuildContext context, {
  required SalesExecutiveReportData report,
  required String currency,
  required String dateRange,
}) {
  return AppDialog.show<void>(
    context,
    title: _tr('executive_details'),
    maxWidth: 640,
    child: SalesExecutiveDetails(
        report: report, currency: currency, dateRange: dateRange),
  );
}

/// Executive information and financial summary sections.
class SalesExecutiveDetails extends StatelessWidget {
  const SalesExecutiveDetails({
    super.key,
    required this.report,
    required this.currency,
    required this.dateRange,
  });

  final SalesExecutiveReportData report;
  final String currency;
  final String dateRange;

  @override
  Widget build(BuildContext context) {
    final na = _tr('na');
    final totals = <String, String>{
      'total_sales': report.formattedTotalSales,
      'total_payment_received': report.formattedTotalPaymentReceived,
      'total_amount_collected_on_sale': report.formattedTotalCollectedOnSale,
      'total_credit_collected_prev': report.formattedCreditCollectedPrev,
      'total_upi_sales': report.formattedUpiSales,
      'total_card_sales': report.formattedCardSales,
      'total_online_sales': report.formattedOnlineSales,
      'total_cash_sales': report.formattedCashSales,
      'total_credit_amount': report.formattedCreditSales,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionCard(
          title: _tr('executive_information'),
          icon: Icons.badge_outlined,
          child: InfoGrid(minColumnWidth: 200, maxColumns: 2, children: [
            InfoRow(label: _tr('name'), value: report.name ?? na),
            InfoRow(label: _tr('phone'), value: report.phone ?? na),
            InfoRow(label: _tr('date_range'), value: dateRange),
            InfoRow(
                label: _tr('total_orders'), value: '${report.orderCount ?? 0}'),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: _tr('financial_summary'),
          icon: Icons.payments_outlined,
          child: Column(children: [
            for (final entry in totals.entries)
              InfoRow(label: _tr(entry.key), value: '$currency ${entry.value}'),
          ]),
        ),
      ],
    );
  }
}
