import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import '../../../state/supplier_transactions_controller.dart';
import 'supplier_transaction_card.dart';
import 'supplier_transaction_details_dialog.dart';
import 'supplier_transaction_filter_panel.dart';
import 'supplier_transaction_report_launcher.dart';
import 'supplier_transaction_table_columns.dart';

/// Body of the supplier Transactions tab, driven by [controller]. Needs a
/// bounded height.
class SupplierTransactionsView extends StatelessWidget {
  const SupplierTransactionsView({
    super.key,
    required this.controller,
    required this.supplier,
  });

  final SupplierTransactionsController controller;
  final Supplier supplier;

  void _view(BuildContext context, SupplierTransaction transaction) {
    showSupplierTransactionDetailsDialog(context, transaction);
  }

  void _print(BuildContext context) {
    openSupplierTransactionReport(
      context,
      supplier: supplier,
      transactions: controller.allTransactions,
    );
  }

  Widget _header(BuildContext context) {
    final filtersOpen = controller.filtersVisible;
    final count = controller.filteredTransactions.length;
    return PageHeader(
      icon: Icons.receipt_long_rounded,
      title: '${'supplier_profile.tab_transactions'.tr} ($count)',
      actions: [
        HeaderAction(
          icon: filtersOpen
              ? Icons.filter_list_off_rounded
              : Icons.filter_list_rounded,
          label: filtersOpen
              ? 'supplier_profile.trans_tooltip_close_filters'.tr
              : 'supplier_profile.trans_tooltip_filter'.tr,
          active: filtersOpen,
          badge: !filtersOpen && !controller.filter.isEmpty,
          onPressed: controller.toggleFilters,
        ),
        HeaderAction(
          icon: Icons.print_outlined,
          label: 'supplier_profile.trans_tooltip_print'.tr,
          onPressed: controller.isLoading ? null : () => _print(context),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    if (controller.hasError && !controller.isLoading) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'supplier_profile.trans_load_failed'.tr,
        action: AppOutlinedButton(
          label: 'general.retry'.tr,
          icon: Icons.refresh_rounded,
          onPressed: controller.retry,
        ),
      );
    }

    return AppAdaptiveList<SupplierTransaction>(
      isLoading: controller.isLoading,
      items: controller.transactions,
      columns: supplierTransactionTableColumns(
        onView: (transaction) => _view(context, transaction),
      ),
      onRowTap: (transaction) => _view(context, transaction),
      cardBuilder: (transaction, number) => SupplierTransactionCard(
        transaction: transaction,
        rowNumber: number,
        onView: () => _view(context, transaction),
      ),
      emptyState: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'supplier_profile.trans_empty_title'.tr,
        subtitle: controller.allTransactions.isEmpty
            ? 'supplier_profile.trans_empty_no_data'.tr
            : 'supplier_profile.trans_empty_no_match'.tr,
      ),
      pagination: controller.showPagination
          ? ListPagination(
              currentPage: controller.currentPage,
              totalPages: controller.totalPages,
              itemsPerPage: controller.perPage,
              onPageChanged: controller.goToPage,
              countLabel: 'supplier_profile.trans_on_page'.trParams(
                {'count': '${controller.transactions.length}'},
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => Column(
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
                  child: SupplierTransactionFilterPanel(controller: controller),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Expanded(child: _list(context)),
          ],
        ),
      ),
    );
  }
}
