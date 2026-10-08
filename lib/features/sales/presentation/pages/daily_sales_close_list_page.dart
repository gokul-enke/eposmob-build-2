import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/sales/domain/models/day_close_pending_status.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/closing/open_shift_modal.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

import '../state/daily_close_list_controller.dart';
import '../widgets/closing/day_close_mobile_card.dart';
import '../widgets/closing/day_close_modal.dart';
import '../widgets/closing/list/daily_close_daily_sales_table.dart';
import '../widgets/closing/list/daily_close_empty_state.dart';
import '../widgets/closing/list/daily_close_list_filters.dart';
import '../widgets/closing/list/daily_close_list_header.dart';
import '../widgets/closing/list/daily_close_list_inputs.dart';
import '../widgets/orders/sales_pagination.dart';

class DailySalesCloseListPage extends StatefulWidget {
  const DailySalesCloseListPage({super.key});

  @override
  State<DailySalesCloseListPage> createState() =>
      _DailySalesCloseListPageState();
}

class _DailySalesCloseListPageState extends State<DailySalesCloseListPage> {
  DailyCloseListInputs _listInputs(SalesProvider provider) =>
      DailyCloseListInputs(
          rows: provider.dailySalesCloseList,
          currency: _settings.appSettings?.currency ?? 'INR',
          onView: (data) => _showViewDetailModal(context, data));
  late final DailyCloseListController _controller;
  late final SalesProvider _sales;
  late final AppSettingsProvider _settings;
  late final AuthModel _auth;
  late final StoreSessionProvider _store;
  TextEditingController get dateController => _controller.dateController;
  DateTime? get selectedDate => _controller.selectedDate;
  set selectedDate(DateTime? value) => _controller.selectedDate = value;
  Key get calendarPickerKey => _controller.calendarPickerKey;
  set calendarPickerKey(Key value) => _controller.calendarPickerKey = value;
  bool get isLoading => _controller.loading;
  DayClosePendingStatus? get pendingStatus => _controller.pendingStatus;
  Widget _buildFilterToggleButton(SalesProvider salesProvider) {
    return FilterToggleButton(
      key: const ValueKey('day-close-filter-toggle'),
      showFilters: salesProvider.showFilters,
      hasActiveFilters: selectedDate != null,
      onPressed: salesProvider.toggleFilters,
      showTooltip: 'daily_sales_close.show_filters'.tr,
      hideTooltip: 'daily_sales_close.hide_filters'.tr,
    );
  }

  @override
  void initState() {
    super.initState();
    _sales = context.read<SalesProvider>();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _store = context.read<StoreSessionProvider>();
    _controller = DailyCloseListController(
        request: (page, date, executive) => DailyCloseListRequest(
            token: _auth.token ?? '',
            storeId: _store.activeStore?.storeId ?? 0,
            userId: _auth.userId ?? 0,
            date: date,
            page: page),
        fetch: (query) => _sales.fetchDailySalesClose(
            accessToken: query.token,
            storeId: query.storeId,
            userId: query.userId,
            startDate: query.date,
            endDate: query.date,
            page: query.page),
        fetchPending: (query) => _sales.fetchDayClosePendingStatus(
            accessToken: query.token,
            storeId: query.storeId,
            userId: query.userId ?? 0));
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

  void _showDayCloseModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DayCloseModal(
          onSuccess: () {
            fetchData(page: 1);
          },
          openDraft: pendingStatus?.openDraft,
        );
      },
    );
  }

  void _showOpenShiftModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return OpenShiftModal(
          onSuccess: () {
            fetchData(page: 1);
          },
        );
      },
    );
  }

  void _showViewDetailModal(BuildContext context, DailySalesCloseData data) {
    final salesProvider = _sales;
    salesProvider.setSelectedDailySalesCloseData(data);
    salesProvider.setReturnIndex(
        SideBarController.dailySalesCloseListScreenIndex); // User list index
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
                Consumer<SalesProvider>(
                    builder: (context, sales, child) => DailyCloseListHeader(
                        isMobile: _isMobile(context),
                        canOpenShift: pendingStatus?.canOpenShift == true,
                        onOpenShift: () => _showOpenShiftModal(context),
                        onDayClose: () => _showDayCloseModal(context),
                        filterToggle: _buildFilterToggleButton(sales))),
                const SizedBox(height: 15),

                // Filter Section
                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    if (!salesProvider.showFilters) {
                      return const SizedBox.shrink();
                    }

                    return DailyCloseListFilters(
                        calendarPickerKey: calendarPickerKey,
                        dateLabel: 'sales.date_col'.tr,
                        onDateSelected: (date) {
                          _controller.update(() {
                            selectedDate = date;
                            dateController.text =
                                DateFormat('yyyy-MM-dd').format(date);
                          });
                          fetchData();
                        },
                        onReset: resetSearch);
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
                        return DailyCloseEmptyState(
                            inputs: _listInputs(salesProvider));
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: _isMobile(context)
                                ? ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    itemCount: salesProvider
                                        .dailySalesCloseList.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: DayCloseMobileCard(
                                          currency:
                                              _settings.appSettings?.currency ??
                                                  'SAR',
                                          data: salesProvider
                                              .dailySalesCloseList[index],
                                          onTap: () {
                                            _showViewDetailModal(
                                              context,
                                              salesProvider
                                                  .dailySalesCloseList[index],
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  )
                                : DailyCloseDailySalesTable(
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

// Day Close Modal Widget
