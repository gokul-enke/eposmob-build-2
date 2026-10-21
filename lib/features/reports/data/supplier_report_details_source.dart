import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';

import '../domain/supplier_report.dart';
import '../domain/supplier_report_details_query.dart';
import 'supplier_report_source.dart';

/// Same repository, endpoint, list_all=true and date bounds as legacy View.
/// Repository reads do not replace the shared supplier directory or selection.
class SupplierReportDetailsSource {
  const SupplierReportDetailsSource(this.repository);
  final SupplierRepository repository;

  Future<SupplierReportScope> scope(String token) =>
      SupplierReportSource(repository).scope(token);

  Future<Map<String, dynamic>> fetch(
          String token, SupplierReportDetailsQuery query,
          {int? page}) =>
      repository.fetchTransactions(
        token,
        supplierId: query.supplier.id.isEmpty ? null : query.supplier.id,
        fromDate: query.from.isEmpty ? null : query.from,
        toDate: query.to.isEmpty ? null : query.to,
        listAll: true,
        page: page,
      );
}
