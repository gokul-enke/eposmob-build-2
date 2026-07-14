import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../newcomponents/custom_container_box.dart';
import '../../newcomponents/custom_dialog_box.dart';
import '../../newcomponents/custom_round_button.dart';
import '../../newcomponents/custom_dropdown_with_search.dart';
import '../../components/build_pagination_control.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../models/master_data.dart';
import '../../models/expense.dart';
import '../../providers/master_data_provider.dart';
import '../dashboard/widgets/dashboard_responsive.dart';
import 'widgets/expense_list_responsive.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final SideBarController sideBarController = Get.find<SideBarController>();
  final TextEditingController searchTextController = TextEditingController();

  final FocusNode _categoryFilterFocus = FocusNode();
  final FocusNode _referenceFilterFocus = FocusNode();
  final FocusNode _debitFilterFocus = FocusNode();
  final FocusNode _statusFilterFocus = FocusNode();
  final FocusNode _resetButtonFocus = FocusNode();

  String? selectedCategory;
  String? selectedDebitAccount;
  String? selectedStatus;

  @override
  void initState() {
    super.initState();
    searchTextController.addListener(() {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      provider.setReference(searchTextController.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null) {
        final provider = Provider.of<ExpenseProvider>(context, listen: false);
        provider.fetchGeneralPayments(accessToken: token, type: 'EXPENSE');
        provider.fetchAccountOptions(accessToken: token);
        _loadCategoriesFromMasterData();
      }
      _categoryFilterFocus.requestFocus();
    });
  }

  Future<void> _loadCategoriesFromMasterData() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    final categories = await _fetchFirstAvailableMasterData(
      masterDataProvider,
      const ['EXPENSE_CATEGORY', 'EXPENSE_CATEGORIES'],
    );
    if (!mounted) return;
    if (categories != null && categories.isNotEmpty) {
      expenseProvider.setCategoryOptionsFromMasterData(categories);
    }
  }

  Future<List<MasterDataValue>?> _fetchFirstAvailableMasterData(
    MasterDataProvider provider,
    List<String> codes,
  ) async {
    for (final code in codes) {
      try {
        final result = await provider.fetchMasterData(code);
        final data = result?.data;
        if (data != null && data.isNotEmpty) {
          return data;
        }
      } catch (_) {
        // Try next candidate code.
      }
    }
    return null;
  }

  @override
  void dispose() {
    searchTextController.dispose();
    _categoryFilterFocus.dispose();
    _referenceFilterFocus.dispose();
    _debitFilterFocus.dispose();
    _statusFilterFocus.dispose();
    _resetButtonFocus.dispose();
    super.dispose();
  }

  bool _hasActiveFilters() {
    return selectedCategory != null ||
        selectedDebitAccount != null ||
        selectedStatus != null ||
        searchTextController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = expenseListIsPhone(context);

    return ExpenseListShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isPhone),
          const SizedBox(height: 12),
          if (!isPhone) ...[
            _buildFilterSection(isPhone),
            const SizedBox(height: 12),
          ],
          Expanded(child: _buildExpenseTable(isPhone)),
          const SizedBox(height: 12),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Expenses',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.20,
            Colors.grey,
          ),
        ),
        const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
        Text(
          'List',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.20,
            ColorManager.kPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isPhone) {
    return ExpenseListPageHeader(
      title: 'Expenses',
      breadcrumb: _buildBreadcrumb(),
      filterAction: isPhone
          ? ExpenseListFilterToggle(
              showFilters: false,
              hasActiveFilters: _hasActiveFilters(),
              onPressed: _openMobileFilterSheet,
            )
          : null,
      trailing: SizedBox(
        width: isPhone ? 108 : 140,
        child: CustomRoundButtonAdvanced(
          title: 'New Entry',
          fct: () {
            sideBarController.index.value = 94;
          },
          width: isPhone ? 108 : 140,
          height: isPhone ? 40 : 44,
          fontSize: 12,
          radius: 8,
        ),
      ),
    );
  }

  void _openMobileFilterSheet() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.35,
            maxChildSize: 0.82,
            expand: false,
            builder: (_, scrollController) {
              return Material(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: Text(
                                'Filters',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.25,
                                  ColorManager.textColor,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: [
                          _buildMobileFilterFields(provider),
                          const SizedBox(height: 16),
                          _buildResetButton(
                            provider,
                            fullWidth: true,
                            popSheet: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileFilterFields(ExpenseProvider provider) {
    final List<String> categoriesList = [
      'All',
      ...provider.categoryOptions
          .map((e) => e['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty),
    ];

    final List<String> debitAccountsList = [
      'All',
      ...provider.debitAccountOptions
          .map((e) => e['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty),
    ];

    final List<String> statusOptions = provider.availableStatuses;

    return ExpenseListMobileFilterFields(
      categoryFilter: _buildCategoryFilter(categoriesList, provider),
      referenceFilter: _buildReferenceFilter(),
      debitFilter: _buildDebitFilter(debitAccountsList, provider),
      statusFilter: _buildStatusFilter(statusOptions, provider),
    );
  }

  Widget _buildFilterSection(bool isPhone) {
    final provider = Provider.of<ExpenseProvider>(context);

    final List<String> categoriesList = [
      'All',
      ...provider.categoryOptions
          .map((e) => e['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty),
    ];

    final List<String> debitAccountsList = [
      'All',
      ...provider.debitAccountOptions
          .map((e) => e['name']?.toString() ?? '')
          .where((e) => e.isNotEmpty),
    ];

    final List<String> statusOptions = provider.availableStatuses;

    return ExpenseListContentCard(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExpenseListSectionTitle(title: 'Filters'),
            const SizedBox(height: 12),
            if (isPhone) ...[
              _buildCategoryFilter(categoriesList, provider),
              const SizedBox(height: 10),
              _buildReferenceFilter(),
              const SizedBox(height: 10),
              _buildDebitFilter(debitAccountsList, provider),
              const SizedBox(height: 10),
              _buildStatusFilter(statusOptions, provider),
              const SizedBox(height: 12),
              _buildResetButton(provider, fullWidth: true),
            ] else ...[
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategoryFilter(categoriesList, provider)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildReferenceFilter()),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDebitFilter(debitAccountsList, provider)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatusFilter(statusOptions, provider)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _buildResetButton(provider, fullWidth: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categoriesList, ExpenseProvider provider) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: CustomDropDownWithSearch<String>(
        key: const ValueKey('list_category_filter_dropdown'),
        hintText: 'All Categories',
        value: selectedCategory,
        items: categoriesList,
        onChanged: (val) {
          setState(() {
            selectedCategory = val;
          });
          provider.setCategory(val ?? 'All');
        },
        displayText: (item) => item,
        showName: false,
        height: 44,
        autofocus: false,
        focusNode: _categoryFilterFocus,
      ),
    );
  }

  Widget _buildReferenceFilter() {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(2),
      child: CustomBoxShadowContainer(
        height: 44,
        circleRadius: 10,
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        child: TextFormField(
          controller: searchTextController,
          focusNode: _referenceFilterFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _debitFilterFocus.requestFocus(),
          cursorColor: ColorManager.kPrimaryColor,
          cursorHeight: 13,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Reference No',
            hintStyle: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDebitFilter(List<String> debitAccountsList, ExpenseProvider provider) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: CustomDropDownWithSearch<String>(
        key: const ValueKey('list_debit_account_filter_dropdown'),
        hintText: 'All Debit Accounts',
        value: selectedDebitAccount,
        items: debitAccountsList,
        onChanged: (val) {
          setState(() {
            selectedDebitAccount = val;
          });
          provider.setDebitAccount(val ?? 'All');
        },
        displayText: (item) => item,
        showName: false,
        height: 44,
        autofocus: false,
        focusNode: _debitFilterFocus,
      ),
    );
  }

  Widget _buildStatusFilter(List<String> statusOptions, ExpenseProvider provider) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(4),
      child: CustomDropDownWithSearch<String>(
        key: const ValueKey('list_status_filter_dropdown'),
        hintText: 'All Status',
        value: selectedStatus,
        items: statusOptions,
        onChanged: (val) {
          setState(() {
            selectedStatus = val;
          });
          provider.setStatus(val ?? 'All');
        },
        displayText: (item) => item,
        showName: false,
        height: 44,
        autofocus: false,
        focusNode: _statusFilterFocus,
      ),
    );
  }

  Widget _buildResetButton(
    ExpenseProvider provider, {
    required bool fullWidth,
    bool popSheet = false,
  }) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(5),
      child: Focus(
        focusNode: _resetButtonFocus,
        onKey: (node, event) {
          if (event is RawKeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _resetFilters(provider, popSheet: popSheet);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: CustomRoundButtonAdvanced(
          title: 'Reset',
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: () => _resetFilters(provider, popSheet: popSheet),
          height: 44,
          width: fullWidth ? double.infinity : 150,
          fontSize: 12,
          radius: 8,
        ),
      ),
    );
  }

  void _resetFilters(ExpenseProvider provider, {bool popSheet = false}) {
    searchTextController.clear();
    setState(() {
      selectedCategory = null;
      selectedDebitAccount = null;
      selectedStatus = null;
    });
    provider.resetFilters();
    _categoryFilterFocus.requestFocus();
    if (popSheet && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openExpenseView(String referenceNumber) {
    sideBarController.index.value = 95;
    Get.put(ExpenseViewController()).selectedRef.value = referenceNumber;
  }

  Widget _buildExpenseTable(bool isPhone) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final currency =
            Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? "";

        if (provider.isLoading) {
          return const ExpenseListContentCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(
                  color: ColorManager.kPrimaryColor,
                ),
              ),
            ),
          );
        }

        final expenseList = provider.expenses;

        if (expenseList.isEmpty) {
          return ExpenseListContentCard(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: ColorManager.kPrimaryColor.withOpacity(0.45),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Expenses Found',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.27,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your filters or create a new entry',
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.10,
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isPhone) const DashboardSectionHeader(title: 'Expense records'),
            Expanded(
              child: isPhone
                  ? _buildMobileList(expenseList, currency)
                  : _buildDesktopTable(expenseList, currency),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.1,
                Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s11,
                0.1,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Expense> expenseList, String currency) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: expenseList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exp = expenseList[index];
        final dateStr = _formatPaymentDate(exp.paymentDate);

        return InkWell(
          onTap: () => _openExpenseView(exp.referenceNumber),
          borderRadius: BorderRadius.circular(14),
          child: ExpenseListContentCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              exp.referenceNumber,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s13,
                                0.15,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: exp.referenceNumber));
                              showScaffold(
                                context: context,
                                message: 'Reference number copied to clipboard',
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
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currency ${exp.amount.toStringAsFixed(2)}',
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s13,
                        0.1,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExpenseListStatusPill(status: exp.status),
                  ],
                ),
                Divider(color: Colors.grey.withOpacity(0.08), height: 16),
                _buildInfoRow('Payment date', dateStr),
                _buildInfoRow('Category', exp.category),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Expense> expenseList, String currency) {
    return ExpenseListResponsiveTable(
      table: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorManager.tableBGColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.2),
                6: FlexColumnWidth(1.0),
                7: FlexColumnWidth(0.8),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('Reference number'),
                    _buildTableHeader('Payment date'),
                    _buildTableHeader('Category'),
                    _buildTableHeader('Debit A/c'),
                    _buildTableHeader('Credit A/c'),
                    _buildTableHeader('Amount'),
                    _buildTableHeader('Status', alignment: Alignment.center),
                    _buildTableHeader('View', alignment: Alignment.center),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.2),
                  6: FlexColumnWidth(1.0),
                  7: FlexColumnWidth(0.8),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: expenseList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final exp = entry.value;
                  final dateStr = _formatPaymentDate(exp.paymentDate);

                  return TableRow(
                    decoration: BoxDecoration(
                      color: idx.isEven
                          ? Colors.white
                          : Colors.grey.withOpacity(0.04),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    children: [
                       TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 10.0),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  exp.referenceNumber,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.1,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: exp.referenceNumber));
                                  showScaffold(
                                    context: context,
                                    message:
                                        'Reference number copied to clipboard',
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
                        ),
                      ),
                      _buildTableCell(dateStr),
                      _buildTableCell(exp.category),
                      _buildTableCell(exp.debitAccount),
                      _buildTableCell(exp.creditAccount),
                      _buildTableCell(
                        '$currency ${exp.amount.toStringAsFixed(2)}',
                      ),
                      Center(child: ExpenseListStatusPill(status: exp.status)),
                      Center(
                        child: ExpenseListViewAction(
                          onPressed: () => _openExpenseView(exp.referenceNumber),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {Alignment alignment = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s12,
            0.1,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.1,
          ColorManager.textColor,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final provider = Provider.of<ExpenseProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Center(
        child: PaginationControl(
          currentPage: provider.currentPage,
          totalPages: provider.totalPages,
          onPageChanged: (page) {
            provider.setPage(page);
          },
        ),
      ),
    );
  }

  String _formatPaymentDate(DateTime paymentDate) {
    return '${paymentDate.day.toString().padLeft(2, '0')} '
        '${_getMonthName(paymentDate.month)} '
        '${paymentDate.year}';
  }

  String _getMonthName(int monthNum) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (monthNum >= 1 && monthNum <= 12) {
      return months[monthNum - 1];
    }
    return '';
  }
}

class ExpenseViewController extends GetxController {
  var selectedRef = ''.obs;
}
