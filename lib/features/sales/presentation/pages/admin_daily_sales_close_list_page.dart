import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/models/sales_executive.dart' as exec_model;
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

import '../state/daily_close_list_controller.dart';
import '../widgets/closing/list/admin_daily_close_daily_sales_table.dart';
import '../widgets/closing/list/admin_daily_close_empty_state.dart';
import '../widgets/closing/list/admin_daily_close_mobile_card.dart';
import '../widgets/closing/list/daily_close_list_filters.dart';
import '../widgets/closing/list/daily_close_list_inputs.dart';
import '../widgets/orders/sales_pagination.dart';

class AdminDailySalesCloseListPage extends StatefulWidget {
  const AdminDailySalesCloseListPage({super.key});

  @override
  State<AdminDailySalesCloseListPage> createState() =>
      _AdminDailySalesCloseListPageState();
}

class _AdminDailySalesCloseListPageState
    extends State<AdminDailySalesCloseListPage> {
  DailyCloseListInputs _listInputs(SalesProvider provider) =>
      DailyCloseListInputs(
          rows: provider.dailySalesCloseList,
          currency: _settings.appSettings?.currency ?? 'INR',
          onView: (data) => _showViewDetailModal(context, data));
  late final DailyCloseListController _controller;
  late final SalesProvider _sales;
  late final SalesExecutiveProvider _executives;
  late final AppSettingsProvider _settings;
  late final AuthModel _auth;
  late final StoreSessionProvider _store;
  TextEditingController get dateController => _controller.dateController;
  DateTime? get selectedDate => _controller.selectedDate;
  set selectedDate(DateTime? value) => _controller.selectedDate = value;
  Key get calendarPickerKey => _controller.calendarPickerKey;
  set calendarPickerKey(Key value) => _controller.calendarPickerKey = value;
  bool get isLoading => _controller.loading;
  exec_model.SalesExecutive? get selectedExecutive =>
      _controller.selectedExecutive;
  set selectedExecutive(exec_model.SalesExecutive? value) =>
      _controller.selectedExecutive = value;
  @override
  void initState() {
    super.initState();
    _sales = context.read<SalesProvider>();
    _executives = context.read<SalesExecutiveProvider>();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _store = context.read<StoreSessionProvider>();
    _controller = DailyCloseListController(
        request: (page, date, executive) => DailyCloseListRequest(
            token: _auth.token ?? '',
            storeId: _store.activeStore?.storeId ?? 0,
            userId: executive?.id,
            date: date,
            page: page),
        fetch: (query) => _sales.fetchDailySalesClose(
            accessToken: query.token,
            storeId: query.storeId,
            userId: query.userId,
            startDate: query.date,
            endDate: query.date,
            page: query.page));
    _controller.addListener(_changed);

    // Set default date to null (no filter)
    selectedDate = null;
    dateController.text = '';
    // Ensure filters are shown by default on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isMobile = _isMobile(context);
      _sales.setFiltersVisibility(!isMobile);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _executives.fetchSalesExecutives(context);
      fetchData();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> fetchData({int page = 1}) => _controller.load(page: page);

  Future<void> refreshData() async {
    resetSearch();
  }

  void resetSearch() {
    setState(() {
      selectedDate = null;
      dateController.text = '';
      selectedExecutive = null;
      calendarPickerKey = UniqueKey();
    });
    fetchData(page: 1);

    // Optionally hide filters after reset on mobile
    if (_isMobile(context)) {
      _sales.setFiltersVisibility(false);
    }
  }

// Helper method to check if device is mobile
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  void _showViewDetailModal(BuildContext context, DailySalesCloseData data) {
    final salesProvider = _sales;
    salesProvider.setSelectedDailySalesCloseData(data);
    salesProvider.setReturnIndex(SideBarController
        .adminDailySalesCloseListScreenIndex); // Admin list index
    SalesNavigation.openDailyCloseDetails();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_isMobile(context) ? 12 : 22),
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
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'daily_sales_close.admin_title'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Consumer<SalesProvider>(
                          builder: (context, salesProvider, child) {
                            final hasFilters = selectedDate != null;

                            return Stack(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    salesProvider.showFilters
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined,
                                    color: ColorManager.kPrimaryColor,
                                  ),
                                  onPressed: () {
                                    salesProvider.toggleFilters();
                                  },
                                  tooltip: salesProvider.showFilters
                                      ? 'Hide Filters'
                                      : 'Show Filters',
                                ),
                                if (hasFilters)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Filter Section
                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    if (!salesProvider.showFilters) {
                      return const SizedBox.shrink();
                    }

                    return Consumer<SalesExecutiveProvider>(
                        builder: (context, executives, child) =>
                            DailyCloseListFilters(
                                calendarPickerKey: calendarPickerKey,
                                dateLabel: 'daily_sales_close.filter_date'.tr,
                                onDateSelected: (date) {
                                  _controller.update(() {
                                    selectedDate = date;
                                    dateController.text =
                                        DateFormat('yyyy-MM-dd').format(date);
                                  });
                                  fetchData();
                                },
                                onReset: resetSearch,
                                executiveField: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                              'daily_sales_close.sales_executive'
                                                  .tr,
                                              style: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  FontSize.s14,
                                                  0.27,
                                                  Colors.black
                                                      .withOpacity(0.6)))),
                                      CustomDropDownWithSearch<
                                              exec_model.SalesExecutive>(
                                          hintText:
                                              'daily_sales_close.hint_select_employee'
                                                  .tr,
                                          items: executives.salesExecutives,
                                          displayText: (exec) => exec.name,
                                          value: selectedExecutive,
                                          onChanged: (exec) {
                                            _controller.update(
                                                () => selectedExecutive = exec);
                                            fetchData();
                                          },
                                          searchHintText:
                                              'daily_sales_close.search_hint_name'
                                                  .tr)
                                    ])));
                  },
                ),

                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    return salesProvider.showFilters
                        ? const SizedBox(height: 20)
                        : const SizedBox.shrink();
                  },
                ),

                // Table Section
                Expanded(
                  child: Consumer<SalesProvider>(
                    builder: (context, salesProvider, child) {
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (salesProvider.dailySalesCloseList.isEmpty) {
                        return AdminDailyCloseEmptyState(
                            inputs: _listInputs(salesProvider));
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: _isMobile(context)
                                ? ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: salesProvider
                                        .dailySalesCloseList.length,
                                    itemBuilder: (context, index) {
                                      final data = salesProvider
                                          .dailySalesCloseList[index];
                                      return AdminDailyCloseMobileCard(
                                          data: data,
                                          onView: () => _showViewDetailModal(
                                              context, data));
                                    },
                                  )
                                : AdminDailyCloseDailySalesTable(
                                    inputs: _listInputs(salesProvider)),
                          ),
                          if (salesProvider.dailySalesClosePagination != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: SalesPagination(
                                currentPage: salesProvider
                                        .dailySalesClosePagination
                                        ?.currentPage ??
                                    1,
                                totalPages: salesProvider
                                        .dailySalesClosePagination?.lastPage ??
                                    1,
                                onPageChanged: (int page) {
                                  debugPrint('=== PAGINATION CLICKED ===');
                                  debugPrint('User clicked page: $page');
                                  fetchData(page: page);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
