part of '../pages/customer_report_details_page.dart';

extension on _SimpleTransactionDetailsScreenState {
  CustomerReportDetailsQuery get _exportQuery => CustomerReportDetailsQuery(
        customerId:
            (context.read<CustomerProvider>().selectedCustomerId ?? '').trim(),
        // Reset clears the legacy print controller, not the selected customer.
        customerName: context.read<TransactionProvider>().customerName,
        transactionType: searchTransactionType,
        status: searchStatus,
        type: searchType,
        from: _fromDateController.text,
        to: _toDateController.text,
      );

  bool get _canExport {
    if (!_exportDataReady ||
        initLoading ||
        !(filteredTransactions?.isNotEmpty ?? false)) {
      return false;
    }
    final query = _exportQuery;
    final session = _currentExportSession;
    return query.hasCustomer &&
        _exportLoadedCustomer ==
            (id: query.customerId, name: query.customerName) &&
        _exportLoadedSession == session &&
        session.token.isNotEmpty &&
        (session.tenant?.isNotEmpty ?? false);
  }

  ({String token, String? tenant, int? store}) get _currentExportSession => (
        token: context.read<AuthModel>().token ?? '',
        tenant: _exportPreferences?.getString('api_key'),
        store: _exportPreferences?.getInt('active_store_id'),
      );

  Future<void> _runExport() async {
    if (!_canExport || _export.busy) return;
    final query = _exportQuery;
    final revision = _exportRevision;
    final session = _currentExportSession;
    final invoices = context.read<InvoiceProvider>();
    final ok = await _export.run(context, createFile: () async {
      void checkScope() {
        if (!mounted ||
            revision != _exportRevision ||
            initLoading ||
            query != _exportQuery ||
            session != _currentExportSession) {
          throw StateError(
              'Customer details export selection or session changed.');
        }
      }

      checkScope();
      final rows = await fetchCustomerReportDetailsSnapshot((page) async {
        checkScope();
        final response = await invoices.listAllTransaction(
          accessToken: session.token,
          customerId: query.customerId.isEmpty ? null : query.customerId,
          customerName: query.customerId.isEmpty ? query.customerName : null,
          page: page,
          updateState: false,
        );
        checkScope();
        return response;
      }, query,
          onProgress: (page, last) => _export.setStage(
              'customer_transaction_report.export_fetching'
                  .trParams({'page': '$page', 'total': '$last'})));
      checkScope();
      final File file = await CustomerReportDetailsExport.build(rows, query);
      checkScope();
      return file;
    }, shareText: 'customer_transaction_report.transaction_details'.tr);
    if (!ok && mounted) {
      AppToast.error(context, 'customer_transaction_report.export_error'.tr);
    }
  }
}
