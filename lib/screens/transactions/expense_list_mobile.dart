import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_pagination_control.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/expense_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../newcomponents/custom_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'expense_list_screen.dart';

class ExpenseMobileView extends StatefulWidget {
  final List<dynamic> expenses;
  final bool isLoading;

  // Filter state
  final String? selectedCategory;
  final String? selectedDebitAccount;
  final String? selectedStatus;
  final List<String> categoryOptions;
  final List<String> debitAccountOptions;
  final List<String> statusOptions;

  // Controllers
  final TextEditingController searchTextController;

  // Callbacks
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onDebitAccountChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onReset;
  final VoidCallback onCreateExpense;

  // Pagination
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const ExpenseMobileView({
    super.key,
    required this.expenses,
    required this.isLoading,
    required this.selectedCategory,
    required this.selectedDebitAccount,
    required this.selectedStatus,
    required this.categoryOptions,
    required this.debitAccountOptions,
    required this.statusOptions,
    required this.searchTextController,
    required this.onCategoryChanged,
    required this.onDebitAccountChanged,
    required this.onStatusChanged,
    required this.onReset,
    required this.onCreateExpense,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  State<ExpenseMobileView> createState() => _ExpenseMobileViewState();
}

class _ExpenseMobileViewState extends State<ExpenseMobileView> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Expenses',
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
              0.25, ColorManager.textColor),
        ),
        ElevatedButton.icon(
          onPressed: widget.onCreateExpense,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Entry', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                // Reference No search
                TextFormField(
                  controller: widget.searchTextController,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.18, ColorManager.textColor),
                  decoration: _inputDecoration('Reference No'),
                ),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Categories',
                  value: widget.selectedCategory,
                  items: widget.categoryOptions,
                  onChanged: widget.onCategoryChanged,
                ),
                const SizedBox(height: 8),
                _dropdownField(
                  hint: 'All Debit Accounts',
                  value: widget.selectedDebitAccount,
                  items: widget.debitAccountOptions,
                  onChanged: widget.onDebitAccountChanged,
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: buildCustomStyle(
          FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey),
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
        ...items
            .where((s) => s != 'All')
            .map((s) => DropdownMenuItem<String>(
                value: s,
                child:
                    Text(s, style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
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
      ),
      isExpanded: true,
    );
  }

  Widget _buildList() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (widget.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 60,
                color: ColorManager.kPrimaryColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('No Expenses Found',
                style: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s16, 0.27, ColorManager.textColor)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: widget.expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _ExpenseCard(expense: widget.expenses[index]),
    );
  }
}

// ─── Private card widget ─────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final dynamic expense;

  const _ExpenseCard({required this.expense});

  String _getMonthName(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.currency ??
            '';
    final sideBarController = Get.find<SideBarController>();

    final dateStr =
        '${expense.paymentDate.day.toString().padLeft(2, '0')} '
        '${_getMonthName(expense.paymentDate.month)} '
        '${expense.paymentDate.year}';

    return CustomBoxShadowContainer(
      circleRadius: 10,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: reference + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    expense.referenceNumber,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s13, 0.19, ColorManager.textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusChip(expense.status),
              ],
            ),
            const SizedBox(height: 6),

            // Category + date
            Row(
              children: [
                Icon(Icons.category_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(expense.category,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.18, Colors.black87)),
                const Spacer(),
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateStr,
                    style: buildCustomStyle(FontWeightManager.regular,
                        FontSize.s11, 0.16, Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),

            // Debit / Credit accounts
            Text(
              'Debit: ${expense.debitAccount}',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s11,
                  0.16, Colors.grey),
            ),
            Text(
              'Credit: ${expense.creditAccount}',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s11,
                  0.16, Colors.grey),
            ),
            const SizedBox(height: 6),

            // Amount + view button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currency ${expense.amount.toStringAsFixed(2)}',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s14, 0.21, ColorManager.kPrimaryColor),
                ),
                InkWell(
                  onTap: () {
                    sideBarController.index.value = 95;
                    Get.put(ExpenseViewController()).selectedRef.value =
                        expense.referenceNumber;
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              ColorManager.kPrimaryColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 13, color: ColorManager.kPrimaryColor),
                        const SizedBox(width: 4),
                        Text('View',
                            style: TextStyle(
                                fontSize: 11,
                                color: ColorManager.kPrimaryColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
            color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}