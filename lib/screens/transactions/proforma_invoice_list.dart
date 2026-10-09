import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/proforma_invoices/presentation/pages/proforma_list_page.dart';

const double proformaMobileBreakpoint = ListLayoutBreakpoints.mobileBelow;
bool useProformaMobileLayout(double width) => width < proformaMobileBreakpoint;

class ProformaInvoiceListScreen extends StatelessWidget {
  const ProformaInvoiceListScreen({super.key, this.export});
  final ExportController? export;
  static const filtersKey = ProformaListPage.filtersKey;
  static const filterToggleKey = ProformaListPage.filterToggleKey;
  static const exportKey = ProformaListPage.exportKey;
  static const refreshKey = ProformaListPage.refreshKey;
  @override
  Widget build(BuildContext context) => ProformaListPage(export: export);
}
