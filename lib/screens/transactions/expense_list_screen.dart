import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../newcomponents/custom_container_box.dart';
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
import '../../providers/master_data_provider.dart';
import 'expense_list_mobile.dart';

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

@override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<ExpenseProvider>(
            builder: (context, provider, child) {
              final currency =
                  Provider.of<AppSettingsProvider>(context, listen: false)
                          .appSettings
                          ?.currency ??
                      '';
              final categoryList = [
                'All',
                ...provider.categoryOptions
                    .map((e) => e['name']?.toString() ?? '')
                    .where((e) => e.isNotEmpty),
              ];
              final debitList = [
                'All',
                ...provider.debitAccountOptions
                    .map((e) => e['name']?.toString() ?? '')
                    .where((e) => e.isNotEmpty),
              ];
              return ExpenseMobileView(
                expenses: provider.expenses,
                isLoading: provider.isLoading,
                selectedCategory: selectedCategory,
                selectedDebitAccount: selectedDebitAccount,
                selectedStatus: selectedStatus,
                categoryOptions: categoryList,
                debitAccountOptions: debitList,
                statusOptions: provider.availableStatuses,
                searchTextController: searchTextController,
                onCategoryChanged: (val) {
                  setState(() => selectedCategory = val);
                  provider.setCategory(val ?? 'All');
                },
                onDebitAccountChanged: (val) {
                  setState(() => selectedDebitAccount = val);
                  provider.setDebitAccount(val ?? 'All');
                },
                onStatusChanged: (val) {
                  setState(() => selectedStatus = val);
                  provider.setStatus(val ?? 'All');
                },
                onReset: () => _resetFilters(provider),
                onCreateExpense: () => sideBarController.index.value = 94,
                currentPage: provider.currentPage,
                totalPages: provider.totalPages,
                onPageChanged: (page) => provider.setPage(page),
              );
            },
          ),
        ),
      );
    }
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 15),
              _buildFilterSection(),
              const SizedBox(height: 15),
              Expanded(child: _buildExpenseTable()),
              const SizedBox(height: 15),
              _buildPaginationControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
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
            ),
          ],
        ),
        CustomRoundButtonAdvanced(
          title: 'New Entry',
          fct: () {
            sideBarController.index.value = 94;
          },
          width: 140,
          height: 40,
          fontSize: 12,
          radius: 6,
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final provider = Provider.of<ExpenseProvider>(context);

    final List<String> categoriesList = [
      'All',
      ...provider.categoryOptions.map((e) => e['name']?.toString() ?? '').where((e) => e.isNotEmpty),
    ];

    final List<String> debitAccountsList = [
      'All',
      ...provider.debitAccountOptions.map((e) => e['name']?.toString() ?? '').where((e) => e.isNotEmpty),
    ];

    final List<String> statusOptions = provider.availableStatuses;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          SizedBox(
            height: 55,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FocusTraversalOrder(
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
                      height: 45,
                      autofocus: false,
                      focusNode: _categoryFilterFocus,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: CustomBoxShadowContainer(
                      height: 45,
                      circleRadius: 7,
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
                            horizontal: 10,
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FocusTraversalOrder(
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
                      height: 45,
                      autofocus: false,
                      focusNode: _debitFilterFocus,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FocusTraversalOrder(
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
                      height: 45,
                      autofocus: false,
                      focusNode: _statusFilterFocus,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: Focus(
                    focusNode: _resetButtonFocus,
                    onKey: (node, event) {
                      if (event is RawKeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                        _resetFilters(provider);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: CustomRoundButtonAdvanced(
                      title: 'Reset',
                      boxColor: Colors.white,
                      textColor: ColorManager.kPrimaryColor,
                      borderColor: ColorManager.kPrimaryColor,
                      fct: () => _resetFilters(provider),
                      height: 45,
                      width: 150,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _resetFilters(ExpenseProvider provider) {
    searchTextController.clear();
    setState(() {
      selectedCategory = null;
      selectedDebitAccount = null;
      selectedStatus = null;
    });
    provider.resetFilters();
    _categoryFilterFocus.requestFocus();
  }

  Widget _buildExpenseTable() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final currency = Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? "";
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(
                color: ColorManager.kPrimaryColor,
              ),
            ),
          );
        }

        final expenseList = provider.expenses;

        if (expenseList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 60,
                  color: ColorManager.kPrimaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 15),
                Text(
                  'No Expenses Found',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s16,
                    0.27,
                    ColorManager.textColor,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomBoxShadowContainer(
          margin: const EdgeInsets.only(top: 5),
          circleRadius: 7,
          offsetValue: const Offset(1, 1),
          blurRadius: 4.0,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: ColorManager.tableBGColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
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

                      final dateStr =
                          '${exp.paymentDate.day.toString().padLeft(2, '0')} '
                          '${_getMonthName(exp.paymentDate.month)} '
                          '${exp.paymentDate.year}';

                      return TableRow(
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.white : Colors.grey.withOpacity(0.05),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                          ),
                        ),
                        children: [
                          _buildTableCell(exp.referenceNumber),
                          _buildTableCell(dateStr),
                          _buildTableCell(exp.category),
                          _buildTableCell(exp.debitAccount),
                          _buildTableCell(exp.creditAccount),
                          _buildTableCell('$currency ${exp.amount.toStringAsFixed(2)}'),
                          Center(child: _buildStatusChip(exp.status)),
                          Center(
                            child: IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: const Icon(Icons.visibility, color: Colors.grey, size: 18),
                              onPressed: () {
                                sideBarController.index.value = 95;
                                Get.put(ExpenseViewController()).selectedRef.value =
                                    exp.referenceNumber;
                              },
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
      },
    );
  }

  Widget _buildTableHeader(String text, {Alignment alignment = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
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
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
      child: Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.1,
          ColorManager.textColor,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final provider = Provider.of<ExpenseProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
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


