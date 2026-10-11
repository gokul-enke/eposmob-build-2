import 'package:flutter/material.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/receipts/presentation/pages/receipt_list_page.dart';

/// Existing route and constructor retained for the feature-owned list page.
class ReceiptListScreen extends StatelessWidget {
  const ReceiptListScreen({super.key, this.export});
  final ExportController? export;
  static const filtersKey = ReceiptListPage.filtersKey;
  static const filterToggleKey = ReceiptListPage.filterToggleKey;
  static const exportKey = ReceiptListPage.exportKey;
  static const refreshKey = ReceiptListPage.refreshKey;
  @override
  Widget build(BuildContext context) => ReceiptListPage(export: export);
}
