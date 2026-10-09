import 'package:flutter/material.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/supplier_ledger/presentation/pages/supplier_ledger_list_page.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey =
      ValueKey('supplier-transactions-filter-toggle');
  static const exportKey = ValueKey('supplier-transactions-export');
  static const refreshKey = ValueKey('supplier-transactions-refresh');
  static const filtersKey = ValueKey('supplier-transactions-filters');

  static const pageSize = 50;

  @override
  Widget build(BuildContext context) => SupplierLedgerListPage(export: export);
}
