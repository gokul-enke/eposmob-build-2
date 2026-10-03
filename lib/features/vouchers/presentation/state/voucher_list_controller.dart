import 'package:flutter/material.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';

/// Owns page inputs and pending work; provider filtering is supplied by the page.
class VoucherListController extends ChangeNotifier {
  VoucherListController(
      {required VoidCallback search, ExportController? export})
      : export = export ?? ExportController(),
        ownsExport = export == null {
    debouncer = SearchDebouncer(search);
  }
  final ExportController export;
  final bool ownsExport;
  late final SearchDebouncer debouncer;
  final tableScroll = ScrollController();
  final searchTextController = TextEditingController();
  final voucherNumberController = TextEditingController();
  final dateFromController = TextEditingController();
  final dateToController = TextEditingController();
  String? selectedType;
  String? selectedStatus;
  int? selectedSupplierId;
  bool showFilters = true;
  bool visibilityInitialized = false;
  bool isInitialized = false;
  bool _disposed = false;
  bool get disposed => _disposed;

  void update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void reset() {
    debouncer.cancel();
    update(() {
      searchTextController.clear();
      voucherNumberController.clear();
      dateFromController.clear();
      dateToController.clear();
      selectedType = null;
      selectedStatus = null;
      selectedSupplierId = null;
    });
  }

  bool get hasActiveFilters =>
      searchTextController.text.isNotEmpty ||
      voucherNumberController.text.isNotEmpty ||
      dateFromController.text.isNotEmpty ||
      dateToController.text.isNotEmpty ||
      selectedType != null ||
      selectedStatus != null ||
      selectedSupplierId != null;

  @override
  void dispose() {
    _disposed = true;
    debouncer.dispose();
    if (ownsExport) export.dispose();
    tableScroll.dispose();
    searchTextController.dispose();
    voucherNumberController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    super.dispose();
  }
}
