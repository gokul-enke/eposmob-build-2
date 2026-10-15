import 'package:flutter/material.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/invoices/presentation/pages/invoice_list_page.dart';

/// Compatibility route. Details, actions and create modal stay at their
/// original locations; only the listing lives in the Invoices feature.
class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key, this.export});
  final ExportController? export;
  static const filtersKey = InvoiceListPage.filtersKey;
  static const filterToggleKey = InvoiceListPage.filterToggleKey;
  static const exportKey = InvoiceListPage.exportKey;
  static const refreshKey = InvoiceListPage.refreshKey;
  @override
  Widget build(BuildContext context) => InvoiceListPage(export: export);
}
