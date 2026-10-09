import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import '../domain/supplier_ledger_query.dart';

class SupplierLedgerPage {
  const SupplierLedgerPage(this.items, this.currentPage, this.totalPages);
  final List<TransactionModel> items;
  final int currentPage, totalPages;
}

/// Compatibility boundary for the existing provider and API/parser contracts.
class SupplierLedgerRepository {
  SupplierLedgerRepository(this.provider);
  final TransactionProvider provider;
  void setAccessToken(String token) => provider.setAccessToken(token);
  String? supplierId(String name) =>
      provider.lookupSupplierIdByName(name)?.toString();
  List<String> get supplierOptions => provider.getSupplierOptions();
  Future<SupplierLedgerPage> fetchPage(
      SupplierLedgerQuery query, int page, int pageSize) async {
    await provider.fetchTransactionsFromServerV2(
        supplierId: query.supplierId,
        transactionType: query.transactionType,
        type: query.type,
        page: page,
        perPage: pageSize);
    return SupplierLedgerPage(
        List.of(provider.listTransactionModelDataList ?? <TransactionModel>[]),
        provider.transactionCurrentPage,
        provider.transactionTotalPages);
  }

  Future<List<TransactionModel>> snapshot(SupplierLedgerQuery query,
          {bool applyLocalFilters = false,
          void Function(int, int)? onProgress}) =>
      provider.fetchTransactionsForExport(
          supplierId: query.supplierId,
          transactionType: query.transactionType,
          type: query.type,
          search: applyLocalFilters ? query.search : null,
          status: applyLocalFilters ? query.status : null,
          supplierName: applyLocalFilters ? query.supplierName : null,
          onProgress: onProgress);
  List<TransactionModel> filter(
          List<TransactionModel> items, SupplierLedgerQuery query) =>
      TransactionProvider.filterTransactions(items,
          search: query.search,
          status: query.status,
          supplierName: query.supplierName);
}
