import 'package:flutter/material.dart';
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
import '../../components/build_pagination_control.dart' as pagination;
import '../../providers/app_settings_provider.dart';
import '../../providers/supplier_voucher_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/supplier_voucher_print.dart';
import 'widgets/share_helper.dart';

class SupplierVoucherMobileView extends StatefulWidget {
  final List<SupplierVoucher> vouchers;
  final bool isLoading;

  // Controllers
  final TextEditingController voucherNumberController;

  // Focus nodes
  final FocusNode supplierFocusNode;
  final FocusNode typeFocusNode;
  final FocusNode statusFocusNode;

  // Filter state
  final int? selectedSupplierId;
  final String? selectedType;
  final String? selectedStatus;
  final Map<int, String> supplierOptions; // id -> name
  final List<String> typeOptions;
  final List<String> statusOptions;

  // Callbacks
  final VoidCallback onSearchChanged;
  final VoidCallback onReset;
  final ValueChanged<int?> onSupplierChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final void Function(SupplierVoucher) onViewDetails;
  final void Function(SupplierVoucher) onShare;

  // Pagination
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  // Actions
  final VoidCallback onCreateVoucher;
  final Future<void> Function() onRefresh;

  const SupplierVoucherMobileView({
    super.key,
    required this.vouchers,
    required this.isLoading,
    required this.voucherNumberController,
    required this.supplierFocusNode,
    required this.typeFocusNode,
    required this.statusFocusNode,
    required this.selectedSupplierId,
    required this.selectedType,
    required this.selectedStatus,
    required this.supplierOptions,
    required this.typeOptions,
    required this.statusOptions,
    required this.onSearchChanged,
    required this.onReset,
    required this.onSupplierChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onViewDetails,
    required this.onShare,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onCreateVoucher,
    required this.onRefresh,
  });

  @override
  State<SupplierVoucherMobileView> createState() =>
      _SupplierVoucherMobileViewState();
}

class _SupplierVoucherMobileViewState
    extends State<SupplierVoucherMobileView> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildFiltersPanel(),
          const SizedBox(height: 8),
          Expanded(child: _buildList()),
          const SizedBox(height: 8),
          pagination.PaginationControl(
            currentPage: widget.currentPage,
            totalPages: widget.totalPages,
            onPageChanged: widget.onPageChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Supplier Vouchers',
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
              0.25, ColorManager.textColor),
        ),
        ElevatedButton.icon(
          onPressed: widget.onCreateVoucher,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
        leading: const Icon(Icons.filter_list, size: 18),
        title: Text(
          _filtersExpanded ? 'Hide Filters' : 'Show Filters',
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
              0.18, ColorManager.textColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Supplier dropdown
                _supplierDropdown(),
                const SizedBox(height: 8),
                _filterField(widget.voucherNumberController, 'Voucher No.'),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Types',
                  value: widget.selectedType,
                  items: widget.typeOptions,
                  onChanged: widget.onTypeChanged,
                ),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Status',
                  value: widget.selectedStatus,
                  items: widget.statusOptions,
                  onChanged: widget.onStatusChanged,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: const BorderSide(
                          color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Reset Filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierDropdown() {
    final entries = widget.supplierOptions.entries.toList();
    return DropdownButtonFormField<int>(
      value: widget.selectedSupplierId,
      hint: Text('All Suppliers',
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey)),
      items: [
        const DropdownMenuItem<int>(
            value: null,
            child: Text('All Suppliers',
                style: TextStyle(fontSize: 12))),
        ...entries.map((e) => DropdownMenuItem<int>(
            value: e.key,
            child: Text(e.value,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis))),
      ],
      onChanged: widget.onSupplierChanged,
      decoration: _inputDecoration(),
      isExpanded: true,
    );
  }

  Widget _filterField(
      TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => widget.onSearchChanged(),
      style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
          0.18, ColorManager.textColor),
      decoration: _inputDecoration().copyWith(hintText: hint,
        hintStyle: buildCustomStyle(
            FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey)),
    );
  }

  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint,
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey)),
      items: [
        DropdownMenuItem<String>(
            value: null,
            child: Text(hint, style: const TextStyle(fontSize: 12))),
        ...items.map((s) => DropdownMenuItem<String>(
            value: s,
            child: Text(s.toUpperCase(),
                style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
      decoration: _inputDecoration(),
      isExpanded: true,
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(
              color: ColorManager.kPrimaryColor, width: 1.2)),
      isDense: true,
    );
  }

  Widget _buildList() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (widget.vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 60,
                color: ColorManager.kPrimaryColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('No vouchers found',
                style: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s16, 0.24, ColorManager.textColor)),
            const SizedBox(height: 6),
            Text('Try adjusting your filters',
                style: buildCustomStyle(FontWeightManager.regular,
                    FontSize.s13, 0.19, Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: widget.vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _SupplierVoucherCard(
        voucher: widget.vouchers[index],
        onViewDetails: widget.onViewDetails,
        onPrint: (v) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierVoucherPrintPage(
              voucher: v,
              returnToPreviousRoute: true,
            ),
          ),
        ),
        onShare: widget.onShare,
      ),
    );
  }
}

// ─── Private card widget ─────────────────────────────────────────────────────

class _SupplierVoucherCard extends StatelessWidget {
  final SupplierVoucher voucher;
  final void Function(SupplierVoucher) onViewDetails;
  final void Function(SupplierVoucher) onPrint;
  final void Function(SupplierVoucher) onShare;

  const _SupplierVoucherCard({
    required this.voucher,
    required this.onViewDetails,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.currency ??
            'INR';

    return BuildBoxShadowContainer(
      circleRadius: 10,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: voucher number + status chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  voucher.voucherNumber,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s13, 0.19, ColorManager.textColor),
                ),
                _statusChip(voucher.status),
              ],
            ),
            const SizedBox(height: 6),

            // Supplier name
            Text(
              voucher.supplier.name,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.18, Colors.black87),
            ),
            const SizedBox(height: 4),

            // Type + amount
            Row(
              children: [
                _typeChip(voucher.type),
                const SizedBox(width: 8),
                Text(
                  '$currency ${voucher.amount}',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s13, 0.19, ColorManager.kPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Dates + payment method
            Text(
              'Date: ${voucher.voucherDate}  •  Due: ${voucher.dueDate}',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s11,
                  0.16, Colors.grey),
            ),
            if (voucher.paymentMethod.isNotEmpty)
              Text(
                'Payment: ${voucher.paymentMethod}',
                style: buildCustomStyle(FontWeightManager.regular,
                    FontSize.s11, 0.16, Colors.grey),
              ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionBtn(Icons.visibility_outlined, 'View',
                    () => onViewDetails(voucher)),
                const SizedBox(width: 6),
                _actionBtn(Icons.print_outlined, 'Print',
                    () => onPrint(voucher)),
                const SizedBox(width: 6),
                _actionBtn(Icons.share_outlined, 'Share',
                    () => onShare(voucher)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
              color: ColorManager.kPrimaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: ColorManager.kPrimaryColor),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: ColorManager.kPrimaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'PAID':
        bg = Colors.green.withOpacity(0.1);
        fg = Colors.green;
        break;
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        break;
      case 'CANCELLED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(type.toUpperCase(),
          style: const TextStyle(
              color: Colors.blue,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}