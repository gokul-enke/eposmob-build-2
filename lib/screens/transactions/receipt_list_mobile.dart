import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/models/list_receipt.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../components/build_container_box.dart';
import '../../components/build_pagination_control.dart';
import 'widgets/share_helper.dart';

class ReceiptMobileView extends StatefulWidget {
  final List<Receipt> receipts;
  final bool isLoading;

  // Controllers
  final TextEditingController receiptNumberController;
  final TextEditingController paymentReferenceController;
  final TextEditingController searchTextController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  // Focus nodes
  final FocusNode receiptNoFocusNode;
  final FocusNode referenceNoFocusNode;
  final FocusNode nameFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode emailFocusNode;

  // Filter state
  final String? selectedStatus;
  final String? selectedPaymentMethod;
  final List<String> statusOptions;
  final List<String> paymentMethodOptions;

  // Callbacks
  final VoidCallback onSearchChanged;
  final VoidCallback onReset;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final void Function(Receipt) onViewDetails;
  final void Function(Receipt) onShare;

  // Pagination
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  // Actions
  final VoidCallback onCreateReceipt;
  final Future<void> Function() onRefresh;

  const ReceiptMobileView({
    super.key,
    required this.receipts,
    required this.isLoading,
    required this.receiptNumberController,
    required this.paymentReferenceController,
    required this.searchTextController,
    required this.phoneController,
    required this.emailController,
    required this.receiptNoFocusNode,
    required this.referenceNoFocusNode,
    required this.nameFocusNode,
    required this.phoneFocusNode,
    required this.emailFocusNode,
    required this.selectedStatus,
    required this.selectedPaymentMethod,
    required this.statusOptions,
    required this.paymentMethodOptions,
    required this.onSearchChanged,
    required this.onReset,
    required this.onStatusChanged,
    required this.onPaymentMethodChanged,
    required this.onViewDetails,
    required this.onShare,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onCreateReceipt,
    required this.onRefresh,
  });

  @override
  State<ReceiptMobileView> createState() => _ReceiptMobileViewState();
}

class _ReceiptMobileViewState extends State<ReceiptMobileView> {
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
          PaginationControl(
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
          'receipt.list_title'.tr,
          style: buildCustomStyle(
              FontWeightManager.semiBold, FontSize.s16, 0.25, ColorManager.textColor),
        ),
        ElevatedButton.icon(
          onPressed: widget.onCreateReceipt,
          icon: const Icon(Icons.add, size: 16),
          label: Text('receipt.mobile_create_button'.tr, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
        leading: const Icon(Icons.filter_list, size: 18),
        title: Text(
          _filtersExpanded ? 'receipt.hide_filters'.tr : 'receipt.show_filters'.tr,
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18, ColorManager.textColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _filterField(widget.receiptNumberController, widget.receiptNoFocusNode, 'receipt.receipt_no_hint'.tr),
                const SizedBox(height: 8),
                _filterField(widget.paymentReferenceController, widget.referenceNoFocusNode, 'receipt.reference_no_hint'.tr),
                const SizedBox(height: 8),
                _filterField(widget.searchTextController, widget.nameFocusNode, 'receipt.name_hint'.tr),
                const SizedBox(height: 8),
                _filterField(widget.phoneController, widget.phoneFocusNode, 'receipt.phone_hint'.tr),
                const SizedBox(height: 8),
                _filterField(widget.emailController, widget.emailFocusNode, 'receipt.email_hint'.tr),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Status',
                  value: widget.selectedStatus,
                  items: widget.statusOptions,
                  onChanged: widget.onStatusChanged,
                ),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Payment Methods',
                  value: widget.selectedPaymentMethod,
                  items: widget.paymentMethodOptions,
                  onChanged: widget.onPaymentMethodChanged,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: BorderSide(color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('receipt.reset_filters_button'.tr),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterField(TextEditingController controller, FocusNode focusNode, String hint) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => widget.onSearchChanged(),
      style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18, ColorManager.textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2)),
        isDense: true,
      ),
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
      hint: Text(hint, style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey)),
      items: [
        DropdownMenuItem<String>(value: null, child: Text(hint, style: const TextStyle(fontSize: 12))),
        ...items.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2)),
        isDense: true,
      ),
      isExpanded: true,
    );
  }

  Widget _buildList() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (widget.receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('receipt.no_receipts_found'.tr,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s16, 0.24, ColorManager.textColor)),
            const SizedBox(height: 6),
            Text('receipt.try_adjusting_filters'.tr,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s13, 0.19, Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: widget.receipts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ReceiptCard(
        receipt: widget.receipts[index],
        onViewDetails: widget.onViewDetails,
        onShare: widget.onShare,
      ),
    );
  }
}

// ─── Private card widget ────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final void Function(Receipt) onViewDetails;
  final void Function(Receipt) onShare;

  const _ReceiptCard({
    required this.receipt,
    required this.onViewDetails,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: receipt number + status chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      receipt.receiptNumber,
                      style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s13, 0.19, ColorManager.textColor),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: receipt.receiptNumber));
                        showScaffold(
                          context: context,
                          message: 'receipt.copied_to_clipboard'.tr,
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
                _statusChip(receipt.receiptStatus),
              ],
            ),
            const SizedBox(height: 6),

            // Customer name
            Text(
              receipt.customer.user.name,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18, Colors.black87),
            ),
            const SizedBox(height: 6),

            // Amount + type chip
            Row(
              children: [
                Text(
                  receipt.amount,
                  style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s13, 0.19, ColorManager.kPrimaryColor),
                ),
                const SizedBox(width: 8),
                _typeChip(receipt),
              ],
            ),
            const SizedBox(height: 4),

            // Payment reference
            if (receipt.paymentReference.isNotEmpty)
              Row(
                children: [
                  Text(
                    'receipt.ref_prefix'.tr.replaceAll('@reference', receipt.paymentReference),
                    style: buildCustomStyle(FontWeightManager.regular, FontSize.s11, 0.16, Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: receipt.paymentReference));
                      showScaffold(
                        context: context,
                        message: 'receipt.copied_to_clipboard'.tr,
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionBtn(Icons.visibility_outlined, 'receipt.view_action'.tr, () => onViewDetails(receipt)),
                const SizedBox(width: 8),
                _actionBtn(Icons.share_outlined, 'receipt.share_action'.tr, () => onShare(receipt)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: ColorManager.kPrimaryColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: ColorManager.kPrimaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'PAID':
        bg = Colors.green.withOpacity(0.1); fg = Colors.green; break;
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1); fg = Colors.orange; break;
      case 'FAIL':
      case 'FAILED':
        bg = Colors.red.withOpacity(0.1); fg = Colors.red; break;
      default:
        bg = Colors.grey.withOpacity(0.1); fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _typeChip(Receipt receipt) {
    final invoiceCount = receipt.receiptPayments.where((p) => p.invoiceId != null).length;
    final generalCount = receipt.receiptPayments.where((p) => p.invoiceId == null).length;
    String label; Color bg, fg;
    if (invoiceCount > 0 && generalCount > 0) {
      label = 'receipt.type_mixed'.tr; bg = Colors.orange.withOpacity(0.1); fg = Colors.orange;
    } else if (invoiceCount > 0) {
      label = 'receipt.type_invoice_payment'.tr; bg = Colors.blue.withOpacity(0.1); fg = Colors.blue;
    } else {
      label = 'receipt.type_general_payment'.tr; bg = Colors.green.withOpacity(0.1); fg = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}