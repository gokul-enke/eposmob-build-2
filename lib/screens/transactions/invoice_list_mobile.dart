import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dropdown_with_search.dart';
import '../../components/build_pagination_control.dart';
import '../../components/build_round_button.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../helpers/ui_code_labels.dart';

/// Mobile card-based layout for the invoice list screen.
///
/// This widget is 100% presentation — it owns no business logic and no
/// provider access. Everything it needs (data, controllers, focus nodes,
/// and callbacks) is passed in from `InvoiceListScreen`. This means
/// `invoice_list.dart` never needs to be touched again for mobile-only
/// changes — only this file does.
class InvoiceMobileView extends StatelessWidget {
  const InvoiceMobileView({
    super.key,
    required this.invoices,
    required this.isLoading,
    required this.selectedInvoiceIds,
    required this.onToggleSelect,
    required this.onViewDetails,
    required this.onShowActions,
    required this.searchTextController,
    required this.invoiceNumberController,
    required this.phoneController,
    required this.dateFromController,
    required this.dateToController,
    required this.invoiceNoFocusNode,
    required this.nameFocusNode,
    required this.phoneFocusNode,
    required this.dateFromFocusNode,
    required this.dateToFocusNode,
    required this.onSearchChanged,
    required this.onReset,
    required this.onSelectDate,
    required this.selectedStatus,
    required this.selectedZatcaStatus,
    required this.statusOptions,
    required this.zatcaStatusOptions,
    required this.onStatusChanged,
    required this.onZatcaStatusChanged,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.isBulkSending,
    required this.activeBulkSyncType,
    required this.onBulkSync,
    required this.onSelectPage,
    required this.onUnselectAll,
    required this.onCreateInvoice,
    required this.onRefresh,
  });

  // Data
  final List<Invoice> invoices;
  final bool isLoading;
  final Set<int> selectedInvoiceIds;

  // Row actions
  final void Function(int invoiceId, bool selected) onToggleSelect;
  final void Function(Invoice invoice) onViewDetails;
  final void Function(Invoice invoice) onShowActions;

  // Search controllers / focus nodes (owned + disposed by InvoiceListScreen)
  final TextEditingController searchTextController;
  final TextEditingController invoiceNumberController;
  final TextEditingController phoneController;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final FocusNode invoiceNoFocusNode;
  final FocusNode nameFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode dateFromFocusNode;
  final FocusNode dateToFocusNode;
  final VoidCallback onSearchChanged;
  final VoidCallback onReset;
  final Future<void> Function({required bool isFromDate}) onSelectDate;

  // Filters
  final String? selectedStatus;
  final String? selectedZatcaStatus;
  final List<String> statusOptions;
  final List<String> zatcaStatusOptions;
  final void Function(String?) onStatusChanged;
  final void Function(String?) onZatcaStatusChanged;

  // Pagination
  final int currentPage;
  final int totalPages;
  final void Function(int page) onPageChanged;

  // Bulk ZATCA sync
  final bool isBulkSending;
  final String? activeBulkSyncType;
  final Future<void> Function(String syncType, List<int> ids) onBulkSync;
  final VoidCallback onSelectPage;
  final VoidCallback onUnselectAll;

  // Header
  final VoidCallback onCreateInvoice;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildFiltersPanel(context),
          const SizedBox(height: 8),
          _buildSelectionBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildList()),
          _buildPagination(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Invoice List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: "Create",
          fct: onCreateInvoice,
          fontSize: 12,
          height: 40,
          width: 100,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Filters (collapsed by default to save vertical space on small screens)
  // ---------------------------------------------------------------------
  Widget _buildFiltersPanel(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: BuildBoxShadowContainer(
        circleRadius: 10,
        width: double.infinity,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding:
              const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            "Filters",
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                0.20, ColorManager.textColor),
          ),
          leading: const Icon(Icons.filter_list,
              color: ColorManager.kPrimaryColor, size: 20),
          children: [
            _mobileTextField(
              controller: invoiceNumberController,
              focusNode: invoiceNoFocusNode,
              hint: "Invoice No",
            ),
            const SizedBox(height: 10),
            _mobileTextField(
              controller: searchTextController,
              focusNode: nameFocusNode,
              hint: "Name",
            ),
            const SizedBox(height: 10),
            _mobileTextField(
              controller: phoneController,
              focusNode: phoneFocusNode,
              hint: "Phone",
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _mobileDateField(
                    controller: dateFromController,
                    focusNode: dateFromFocusNode,
                    isFromDate: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _mobileDateField(
                    controller: dateToController,
                    focusNode: dateToFocusNode,
                    isFromDate: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BuildDropDownWithSearch<String>(
              title: null,
              showName: false,
              hintText: 'invoice.all_status'.tr,
              value: selectedStatus,
              items:
                  statusOptions.where((s) => s != "All Status").toList(),
              onChanged: onStatusChanged,
              displayText: (status) => UiCodeLabels.status(status),
              height: 45,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            BuildDropDownWithSearch<String>(
              title: null,
              showName: false,
              hintText: 'invoice.all_zatca_status'.tr,
              value: selectedZatcaStatus,
              items: zatcaStatusOptions
                  .where((s) => s != "All ZATCA Status")
                  .toList(),
              onChanged: onZatcaStatusChanged,
              displayText: (status) => UiCodeLabels.zatca(status),
              height: 45,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CustomRoundButton(
                title: "general.reset".tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: onReset,
                height: 42,
                width: double.infinity,
                fontSize: FontSize.s12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return BuildBoxShadowContainer(
      height: 45,
      width: double.infinity,
      circleRadius: 7,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        onChanged: (_) => onSearchChanged(),
        cursorColor: ColorManager.kPrimaryColor,
        cursorHeight: 13,
        textInputAction: TextInputAction.next,
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
            0.18, ColorManager.textColor),
        decoration: decoration.copyWith(
          hintText: hint,
          hintStyle: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
              0.18, ColorManager.textColor),
          focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
            borderRadius: BorderRadius.circular(7),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  Widget _mobileDateField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFromDate,
  }) {
    return BuildBoxShadowContainer(
      height: 45,
      width: double.infinity,
      circleRadius: 7,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
        onTap: () => onSelectDate(isFromDate: isFromDate),
        cursorColor: ColorManager.kPrimaryColor,
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s11,
            0.18, ColorManager.textColor),
        decoration: decoration.copyWith(
          hintText: "DD/MM/YYYY",
          hintStyle: buildCustomStyle(FontWeightManager.medium, FontSize.s11,
              0.18, ColorManager.textColor),
          prefixIcon: const Icon(Icons.calendar_today,
              size: 15, color: ColorManager.kPrimaryColor),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
            borderRadius: BorderRadius.circular(7),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Selection / bulk sync bar
  // ---------------------------------------------------------------------
  Widget _buildSelectionBar() {
    final hasSelection = selectedInvoiceIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _bulkButton(
                title: "Sync ALL",
                color: Colors.blueAccent,
                syncType: 'all',
              ),
              const SizedBox(width: 8),
              _bulkButton(
                title: "Sync Failed",
                color: Colors.redAccent,
                syncType: 'failed',
              ),
              const SizedBox(width: 8),
              _bulkButton(
                title: "Sync Not Sent",
                color: Colors.orangeAccent,
                syncType: 'not_sent',
              ),
              const SizedBox(width: 8),
              _bulkButton(
                title: "Sync Selected",
                color: hasSelection ? Colors.lightBlue : Colors.grey,
                syncType: 'selected',
                enabled: hasSelection,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              "${selectedInvoiceIds.length} selected",
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.20, ColorManager.textColor),
            ),
            const SizedBox(width: 12),
            if (invoices.isNotEmpty &&
                selectedInvoiceIds.length < invoices.length)
              InkWell(
                onTap: onSelectPage,
                child: Text(
                  "Select Page",
                  style: buildCustomStyle(FontWeightManager.bold,
                      FontSize.s11, 0.18, ColorManager.kPrimaryColor),
                ),
              ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onUnselectAll,
              child: Text(
                "Unselect",
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s11,
                    0.18, const Color.fromARGB(255, 198, 78, 78)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bulkButton({
    required String title,
    required Color color,
    required String syncType,
    bool enabled = true,
  }) {
    return CustomRoundButton(
      title: title,
      boxColor: color,
      textColor: Colors.white,
      borderColor: Colors.transparent,
      isLoading: isBulkSending && activeBulkSyncType == syncType,
      fct: (isBulkSending || !enabled)
          ? () {}
          : () async {
              final ids = syncType == 'selected'
                  ? selectedInvoiceIds.toList()
                  : const <int>[];
              await onBulkSync(syncType, ids);
            },
      height: 36,
      width: 118,
      fontSize: FontSize.s10,
    );
  }

  // ---------------------------------------------------------------------
  // Card list
  // ---------------------------------------------------------------------
  Widget _buildList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (invoices.isEmpty) {
      return _buildNoInvoicesFoundUI();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final isSelected = selectedInvoiceIds.contains(invoice.id);
        return _InvoiceCard(
          invoice: invoice,
          isSelected: isSelected,
          onToggleSelect: (value) => onToggleSelect(invoice.id, value),
          onViewDetails: () => onViewDetails(invoice),
          onShowActions: () => onShowActions(invoice),
        );
      },
    );
  }

  Widget _buildNoInvoicesFoundUI() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 56, color: ColorManager.kPrimaryColor.withOpacity(0.7)),
          const SizedBox(height: 12),
          Text(
            'No invoices found',
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s16,
                0.27, ColorManager.textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search criteria',
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s12, 0.20, Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------
  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PaginationControl(
        currentPage: currentPage,
        totalPages: totalPages,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

/// A single invoice rendered as a card, used only on mobile.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onViewDetails,
    required this.onShowActions,
  });

  final Invoice invoice;
  final bool isSelected;
  final void Function(bool selected) onToggleSelect;
  final VoidCallback onViewDetails;
  final VoidCallback onShowActions;

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      width: double.infinity,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: ColorManager.kPrimaryColor,
                    onChanged: (v) => onToggleSelect(v ?? false),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          invoice.invoiceNumber,
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s14, 0.18, ColorManager.textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: invoice.invoiceNumber));
                          showScaffold(
                            context: context,
                            message: 'Invoice number copied to clipboard',
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 14,
                          color: ColorManager.textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(invoice.status),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.customer.user.name.toString(),
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s13, 0.15, ColorManager.textColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Amount: ${invoice.amount}",
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.13, Colors.black54),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Type: ${invoice.type}",
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.13, Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Invoice: ${invoice.invoiceDate}",
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.13, Colors.black54),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Due: ${invoice.dueDate}",
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.13, Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: _zatcaChip(invoice),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.visibility,
                      size: 20,
                      color: ColorManager.kPrimaryColor.withOpacity(0.9)),
                  onPressed: onViewDetails,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(Icons.more_vert,
                      size: 20,
                      color: ColorManager.kPrimaryColor.withOpacity(0.9)),
                  onPressed: onShowActions,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'PAID':
        bg = Colors.green.withOpacity(0.1);
        fg = Colors.green;
        break;
      case 'PENDING':
        bg = Colors.orange.withOpacity(0.1);
        fg = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
        bg = Colors.red.withOpacity(0.1);
        fg = Colors.red;
        break;
      default:
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        UiCodeLabels.status(status),
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _zatcaChip(Invoice invoice) {
    String label = 'invoice.zatca_status_not_sent'.tr;
    Color bg = Colors.orange.withOpacity(0.12);
    Color fg = Colors.orange;

    final zatcaStatus = invoice.zatcaStatus?.toLowerCase();
    final zatcaRequestStatus = invoice.zatcaRequestStatus?.toLowerCase();

    final isPass = zatcaStatus == 'pass' ||
        zatcaStatus == 'success' ||
        zatcaStatus == 'sent';
    final isFailed = zatcaRequestStatus == 'failed';
    final isPending =
        zatcaRequestStatus == 'pending' || zatcaRequestStatus == 'processing';

    if (isPass) {
      label = 'invoice.zatca_status_sent'.tr;
      bg = Colors.green.withOpacity(0.12);
      fg = Colors.green;
    } else if (isFailed) {
      label = 'invoice.zatca_status_failed'.tr;
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red;
    } else if (isPending) {
      label = 'invoice.zatca_status_pending'.tr;
      bg = Colors.blue.withOpacity(0.12);
      fg = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
