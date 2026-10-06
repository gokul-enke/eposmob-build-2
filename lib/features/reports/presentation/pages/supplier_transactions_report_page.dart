import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';
import '../../data/supplier_report_source.dart';
import '../../domain/supplier_report.dart';
import '../navigation/report_navigation.dart';
import '../state/supplier_transactions_report_controller.dart';
import '../widgets/supplier_report/supplier_report_filters.dart';
import '../widgets/supplier_report/supplier_report_frame.dart';
import '../widgets/supplier_report/supplier_report_header.dart';
import '../widgets/supplier_report/supplier_report_table.dart';

class SupplierTransactionsReportPage extends StatefulWidget {
  const SupplierTransactionsReportPage({super.key});
  @override
  State<SupplierTransactionsReportPage> createState() =>
      _SupplierTransactionsReportPageState();
}

class _SupplierTransactionsReportPageState
    extends State<SupplierTransactionsReportPage> {
  int _shownErrorRevision = 0;
  late final AuthModel _auth;
  late final SupplierProvider _suppliers;
  late final SupplierTransactionsReportController _report;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _suppliers = context.read<SupplierProvider>();
    final source = SupplierReportSource(_suppliers.repository);
    _report = SupplierTransactionsReportController(
        fetchDirectory: () => source.directory(_auth.token ?? ''),
        fetch: (query, page) => source.fetch(_auth.token ?? '', query, page));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _report.setFiltersVisible(MediaQuery.of(context).size.width >= 768);
      _run(_report.initialize());
    });
  }

  Future<void> _run(Future<void> operation) async {
    await operation;
    if (!mounted ||
        _report.errorKey == null ||
        _shownErrorRevision == _report.errorRevision) return;
    _shownErrorRevision = _report.errorRevision;
    final message =
        _report.errorKey!.tr.replaceAll('@error', '${_report.error ?? ''}');
    if (_report.errorKey ==
        'supplier_transaction_report.from_date_after_to_date') {
      AppToast.warning(context, message);
    } else {
      AppToast.error(context, message);
    }
  }

  void _view(SupplierTransactionSummary summary) {
    _suppliers
      ..setSelectedSupplierName(
          summary.displayName ?? 'supplier_transaction_report.unknown'.tr)
      ..setSelectedSupplierId(summary.supplierId);
    ReportNavigation.openSupplierTransactionDetails();
  }

  @override
  void dispose() {
    _report.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _report,
      builder: (context, _) => SupplierReportFrame(
            showFilters: _report.showFilters,
            onRefresh: () => _run(_report.load()),
            header: SupplierReportHeader(
                showFilters: _report.showFilters,
                hasActiveFilters: _report.hasActiveFilters,
                activeFiltersListenable: Listenable.merge([
                  _report.supplierInput,
                  _report.fromInput,
                  _report.toInput
                ]),
                activeFiltersBuilder: () => _report.hasActiveFilters,
                onToggle: () =>
                    _report.setFiltersVisible(!_report.showFilters)),
            filters: SupplierReportFilters(
                suppliers: _report.suppliers,
                selectedSupplierId: _report.selectedSupplierId,
                fromInput: _report.fromInput,
                toInput: _report.toInput,
                onReset: () => _run(_report.reset()),
                onSupplier: (supplier) =>
                    _run(_report.selectSupplier(supplier)),
                onDate: (date, from) => _run(_report.selectDate(date, from))),
            content: SupplierReportTable(
                rows: _report.rows,
                initializing: _report.initializing,
                onView: _view),
            pagination: PaginationControl(
                currentPage: _report.page,
                totalPages: _report.pages,
                onPageChanged: (page) => _run(_report.goToPage(page))),
          ));
}
