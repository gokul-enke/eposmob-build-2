import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/supplier_report.dart';

/// Reuses the public supplier repository/API without mutating shared list state.
class SupplierReportSource {
  const SupplierReportSource(this.repository);
  final SupplierRepository repository;
  Future<SupplierReportScope> scope(String token) async => (
        token: token,
        tenant: await repository.api.session.apiKey(),
        storeId: await repository.api.session.activeStoreId(),
        endpoint: APPUrl.supplierTransactions,
      );

  Future<List<SupplierReportOption>> directory(String token) async {
    final suppliers = await repository.fetchAll(token);
    if (suppliers == null) throw StateError('Supplier directory unavailable');
    return suppliers
        .map((s) => SupplierReportOption(id: s.id.toString(), name: s.name))
        .toList();
  }

  Future<Map<String, dynamic>> fetch(
          String token, SupplierReportQuery query, int page) =>
      repository.fetchTransactions(token,
          supplierName: null,
          supplierId: query.supplierId,
          transactionType: null,
          fromDate: query.fromDate,
          toDate: query.toDate,
          listAll: false,
          page: page);
}
