import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import '../../../state/customer_transactions_controller.dart';
import 'transaction_card.dart';
import 'transaction_details_dialog.dart';
import 'transaction_filter_panel.dart';
import 'transaction_report_launcher.dart';
import 'transaction_summary_strip.dart';
import 'transaction_table_columns.dart';

/// Body of the Transactions tab, driven by [controller]. Needs a bounded
/// height.
class CustomerTransactionsView extends StatelessWidget {
  const CustomerTransactionsView({
    super.key,
    required this.controller,
    required this.customer,
  });

  final CustomerTransactionsController controller;
  final CustomerListModelData customer;

  void _view(BuildContext context, CustomerTransaction transaction) {
    showTransactionDetailsDialog(context, transaction);
  }

  void _print(BuildContext context) {
    openTransactionReport(
      context,
      TransactionReportData.build(
        customer: customer,
        transactions: controller.transactions,
        totals: controller.totals,
        range: controller.filter.range,
      ),
    );
  }

  String _countLabel() => 'customer_profile.tx_on_page'
      .trParams({'count': '${controller.transactions.length}'});

  Widget _header(BuildContext context) {
    final filtersOpen = controller.filtersVisible;
    return PageHeader(
      icon: Icons.receipt_long_rounded,
      title: 'customer_transactions.title'.tr,
      subtitle: _countLabel(),
      actions: [
        HeaderAction(
          icon: filtersOpen
              ? Icons.filter_list_off_rounded
              : Icons.filter_list_rounded,
          label: filtersOpen
              ? 'customer_transactions.tooltip_close_filters'.tr
              : 'customer_transactions.tooltip_filter'.tr,
          active: filtersOpen,
          onPressed: controller.toggleFilters,
        ),
        HeaderAction(
          icon: Icons.print_outlined,
          label: 'customer_transactions.tooltip_print'.tr,
          onPressed: () => _print(context),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    if (controller.hasError && !controller.isLoading) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'customer_profile.tx_load_failed'.tr,
        action: AppOutlinedButton(
          label: 'customer_orders.btn_try_again'.tr,
          icon: Icons.refresh_rounded,
          onPressed: controller.retry,
        ),
      );
    }

    final showPagination = controller.lastPage > 1;
    return AppAdaptiveList<CustomerTransaction>(
      isLoading: controller.isLoading,
      items: controller.transactions,
      columns: transactionTableColumns(onView: (t) => _view(context, t)),
      onRowTap: (t) => _view(context, t),
      cardBuilder: (transaction, number) => TransactionCard(
        transaction: transaction,
        rowNumber: number,
        onView: () => _view(context, transaction),
      ),
      emptyState: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'customer_transactions.title_empty'.tr,
        subtitle: 'customer_transactions.msg_empty'.tr,
      ),
      pagination: showPagination
          ? ListPagination(
              currentPage: controller.currentPage,
              totalPages: controller.lastPage,
              itemsPerPage: controller.perPage,
              onPageChanged: controller.goToPage,
              countLabel: _countLabel(),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final showSummary = !controller.isLoading &&
              !controller.hasError &&
              controller.transactions.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: AppSpacing.lg),
              if (controller.filtersVisible) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: TransactionFilterPanel(controller: controller),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (showSummary) ...[
                TransactionSummaryStrip(totals: controller.totals),
                const SizedBox(height: AppSpacing.md),
              ],
              Expanded(child: _list(context)),
            ],
          );
        },
      ),
    );
  }
}
