import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';
import '../../data/customer_report_details_snapshot.dart';
import '../../domain/customer_report_details_query.dart';
import '../export/customer_report_details_export.dart';
import '../widgets/customer_report/details/customer_report_details_filters.dart';
import '../widgets/customer_report/details/customer_report_details_results.dart';

part '../state/customer_report_details_state.dart';
part '../state/customer_report_details_print.dart';
part '../state/customer_report_details_export_state.dart';

class SimpleTransactionDetailsScreen extends StatefulWidget {
  const SimpleTransactionDetailsScreen({super.key, this.export});

  final ExportController? export;

  static const backKey = ValueKey('customer-report-details-back');
  static const filtersKey = ValueKey('customer-report-details-filters');
  static const filterToggleKey =
      ValueKey('customer-report-details-filter-toggle');
  static const refreshKey = ValueKey('customer-report-details-refresh');
  static const printKey = ValueKey('customer-report-details-print');
  static const exportKey = ValueKey('customer-report-details-export');
  static const fromKey = ValueKey('customer-report-details-from');
  static const toKey = ValueKey('customer-report-details-to');

  @override
  State<SimpleTransactionDetailsScreen> createState() =>
      _SimpleTransactionDetailsScreenState();
}

class _SimpleTransactionDetailsScreenState
    extends State<SimpleTransactionDetailsScreen>
    with
        CustomerReportDetailsState<SimpleTransactionDetailsScreen>,
        CustomerReportDetailsPrint<SimpleTransactionDetailsScreen> {
  late final ExportController _export;

  @override
  void initState() {
    super.initState();
    _export = widget.export ?? ExportController();
  }

  @override
  void dispose() {
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  String _tr(String key) => 'customer_transaction_report.$key'.tr;

  void _selectFilter(TextEditingController controller, String? value,
      ValueChanged<String> updateSearch) {
    setState(() {
      controller.text = value ?? '';
      updateSearch(value ?? '');
    });
    _applyFilters();
  }

  void _selectDate(TextEditingController controller, DateTime value) {
    setState(() => controller.text = DateFormat('yyyy-MM-dd').format(value));
    _applyFilters();
  }

  DateTime? _dateValue(TextEditingController controller) =>
      controller.text.isEmpty
          ? null
          : DateFormat('yyyy-MM-dd').parse(controller.text);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _export,
      builder: (context, _) => ListPageScaffold<ListTransaction>(
            header: PageHeader(
              icon: Icons.receipt_long_outlined,
              title: _tr('transaction_details'),
              leading: AppOutlinedButton(
                key: SimpleTransactionDetailsScreen.backKey,
                label: _tr('all_customers'),
                icon: Icons.arrow_back,
                onPressed: () => sideBarController.index.value =
                    SideBarController.customerTransactionsReportScreenIndex,
              ),
              primaryActions: [
                AppPrimaryButton(
                  key: SimpleTransactionDetailsScreen.printKey,
                  label: _tr('print'),
                  icon: Icons.print_outlined,
                  onPressed: _printReport,
                ),
              ],
              actions: [
                HeaderAction.filters(
                  key: SimpleTransactionDetailsScreen.filterToggleKey,
                  showFilters: _showFilters,
                  showLabel: 'list.filters'.tr,
                  hideLabel: 'list.hide_filters'.tr,
                  badge: !_showFilters &&
                      (searchTransactionType.isNotEmpty ||
                          searchStatus.isNotEmpty ||
                          searchType.isNotEmpty ||
                          _fromDateController.text.isNotEmpty ||
                          _toDateController.text.isNotEmpty),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
                HeaderAction(
                  key: SimpleTransactionDetailsScreen.exportKey,
                  icon: Icons.ios_share_rounded,
                  label: _export.busy
                      ? (_export.stage ?? 'list.exporting'.tr)
                      : 'list.export'.tr,
                  busy: _export.busy,
                  onPressed: _canExport && !_export.busy ? _runExport : null,
                ),
                HeaderAction(
                  key: SimpleTransactionDetailsScreen.refreshKey,
                  icon: Icons.refresh_rounded,
                  label: 'list.refresh'.tr,
                  onPressed: loadInitData,
                ),
              ],
            ),
            showFilters: _showFilters,
            filters: customerReportDetailsFilters(
              key: SimpleTransactionDetailsScreen.filtersKey,
              transactionType: _transactionTypeController.text,
              status: _statusController.text,
              type: _typeController.text,
              transactionTypes: transactionTypes,
              statuses: statuses,
              types: types,
              optionLabel: _getTranslatedLabel,
              from: _dateValue(_fromDateController),
              to: _dateValue(_toDateController),
              fromKey: SimpleTransactionDetailsScreen.fromKey,
              toKey: SimpleTransactionDetailsScreen.toKey,
              onTransactionType: (value) => _selectFilter(
                  _transactionTypeController,
                  value,
                  (selected) => searchTransactionType = selected),
              onStatus: (value) => _selectFilter(_statusController, value,
                  (selected) => searchStatus = selected),
              onType: (value) => _selectFilter(
                  _typeController, value, (selected) => searchType = selected),
              onFrom: (value) => _selectDate(_fromDateController, value),
              onTo: (value) => _selectDate(_toDateController, value),
              onReset: _resetFilters,
            ),
            isLoading: initLoading,
            items: filteredTransactions ?? [],
            columns: customerReportDetailsColumns(),
            minTableWidth: 1050,
            cardBuilder: (transaction, number) => CustomerReportDetailsCard(
                transaction: transaction, number: number),
            onRefresh: loadInitData,
            emptyState: AppEmptyState(
              icon: Icons.account_balance_outlined,
              title: _tr('no_transactions_available'),
              subtitle: _tr('try_adjusting_filters'),
            ),
          ));
}
