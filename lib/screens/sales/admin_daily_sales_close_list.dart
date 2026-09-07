import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/models/sales_executive.dart' as exec_model;
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../models/daily_sales_close.dart';

class AdminDailySalesCloseListScreen extends StatefulWidget {
  const AdminDailySalesCloseListScreen({super.key});

  @override
  State<AdminDailySalesCloseListScreen> createState() =>
      _AdminDailySalesCloseListScreenState();
}

class _AdminDailySalesCloseListScreenState extends State<AdminDailySalesCloseListScreen> {
  final TextEditingController dateController = TextEditingController();
  DateTime? selectedDate;
  Key calendarPickerKey = UniqueKey();
  bool isLoading = false;
  exec_model.SalesExecutive? selectedExecutive;

  @override
  void initState() {
    super.initState();
    // Set default date to null (no filter)
    selectedDate = null;
    dateController.text = '';
    // Ensure filters are shown by default on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isMobile = _isMobile(context);
      Provider.of<SalesProvider>(context, listen: false)
          .setFiltersVisibility(!isMobile);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SalesExecutiveProvider>(context, listen: false)
          .fetchSalesExecutives(context);
      fetchData();
    });
  }

  @override
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  Future<void> fetchData({int page = 1}) async {
    debugPrint('=== DEBUG: Admin fetchData START ===');
    debugPrint('Fetching daily sales close data for ALL users...');

    setState(() {
      isLoading = true;
    });
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;
      final date = dateController.text.isEmpty ? null : dateController.text;
      final userId = selectedExecutive?.id;

      // DEBUG: Print parameters
      debugPrint('=== DEBUG: Admin fetchData Parameters ===');
      debugPrint('Page: $page');
      debugPrint('Date: $date');
      debugPrint('Store ID: $storeId');
      debugPrint('User ID Filter: ${userId ?? "NONE (All Employees)"}');

      // Call with userId: null to fetch all employees
      await salesProvider.fetchDailySalesClose(
        accessToken: authModel.token ?? '',
        startDate: date,
        endDate: date,
        page: page,
        userId: userId, 
        storeId: storeId,
      );

      debugPrint('=== DEBUG: Admin fetchData SUCCESS ===');
    } catch (e) {
      debugPrint('=== DEBUG: Admin fetchData ERROR ===');
      debugPrint('Error fetching daily sales close: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

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
      Provider.of<SalesProvider>(context, listen: false)
          .setFiltersVisibility(false);
    }
  }

// Helper method to check if device is mobile
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildActionButtons(DailySalesCloseData data, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility,
              size: 18, color: ColorManager.kPrimaryColor),
          onPressed: () {
            _showViewDetailModal(context, data);
          },
        ),
      ],
    );
  }

  void _showViewDetailModal(BuildContext context, DailySalesCloseData data) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    salesProvider.setSelectedDailySalesCloseData(data);
    salesProvider.setReturnIndex(84); // Admin list index
    Get.find<SideBarController>().index.value = 79;
  }

  Widget _buildDailySalesTable(SalesProvider provider) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: const BoxDecoration(
              color: ColorManager.tableBGColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 2.0,
                ),
              ],
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(60), // ID
                1: FlexColumnWidth(2), // Sales Executive
                2: FlexColumnWidth(2), // Phone
                3: FlexColumnWidth(2), // Store
                4: FlexColumnWidth(2), // Closing Period
                5: FlexColumnWidth(1.5), // Total Orders
                6: FlexColumnWidth(2), // Total Sales
                7: FlexColumnWidth(2), // Online Sales
                8: FlexColumnWidth(2), // Cash Sales
                9: FlexColumnWidth(2), // Credit Amount
                10: FixedColumnWidth(100), // Action
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('daily_sales_close.col_id'.tr),
                    _buildTableHeader('daily_sales_close.sales_executive'.tr),
                    _buildTableHeader('daily_sales_close.col_phone'.tr),
                    _buildTableHeader('daily_sales_close.col_store'.tr),
                    _buildTableHeader('daily_sales_close.col_closing_period'.tr),
                    _buildTableHeader('daily_sales_close.total_orders'.tr),
                    _buildTableHeader('daily_sales_close.total_sales'.tr),
                    _buildTableHeader('daily_sales_close.online_sales'.tr),
                    _buildTableHeader('daily_sales_close.cash_sales'.tr),
                    _buildTableHeader('daily_sales_close.credit_amount'.tr),
                    _buildTableHeader('daily_sales_close.action'.tr),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(60), // ID
                      1: FlexColumnWidth(2), // Sales Executive
                      2: FlexColumnWidth(2), // Phone
                      3: FlexColumnWidth(2), // Store
                      4: FlexColumnWidth(2), // Closing Period
                      5: FlexColumnWidth(1.5), // Total Orders
                      6: FlexColumnWidth(2), // Total Sales
                      7: FlexColumnWidth(2), // Online Sales
                      8: FlexColumnWidth(2), // Cash Sales
                      9: FlexColumnWidth(2), // Credit Amount
                      10: FixedColumnWidth(100), // Action
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...provider.dailySalesCloseList
                          .asMap()
                          .entries
                          .map((entry) {
                        int index = entry.key;
                        DailySalesCloseData data = entry.value;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  data.salesExecutive?.id?.toString() ?? '-'),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  data.salesExecutive?.name ?? '-'),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  data.salesExecutive?.phone ?? '-'),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(data.store?.name ?? '-'),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(data.closingPeriod ?? '-'),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  data.totalOrders?.toString() ?? '0'),
                            ),
                            SizedBox(
                              height: 55,
                              child: Consumer<AppSettingsProvider>(
                                builder: (context, appSettingsProvider, child) {
                                  final currency = appSettingsProvider
                                          .appSettings?.currency ??
                                      'INR';
                                  return _buildTableCell(
                                      "$currency ${data.totalSales ?? '0.00'}");
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Consumer<AppSettingsProvider>(
                                builder: (context, appSettingsProvider, child) {
                                  final currency = appSettingsProvider
                                          .appSettings?.currency ??
                                      'INR';
                                  return _buildTableCell(
                                      "$currency ${data.totalOnline ?? '0.00'}");
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Consumer<AppSettingsProvider>(
                                builder: (context, appSettingsProvider, child) {
                                  final currency = appSettingsProvider
                                          .appSettings?.currency ??
                                      'INR';
                                  return _buildTableCell(
                                      "$currency ${data.totalCash ?? '0.00'}");
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Consumer<AppSettingsProvider>(
                                builder: (context, appSettingsProvider, child) {
                                  final currency = appSettingsProvider
                                          .appSettings?.currency ??
                                      'INR';
                                  return _buildTableCell(
                                      "$currency ${data.totalCredit ?? '0.00'}");
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: _buildActionButtons(data, context)),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(SalesProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'daily_sales_close.no_records_admin'.tr,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'daily_sales_close.no_records_subtitle'.tr,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First row of filters
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Filter
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'daily_sales_close.filter_date'.tr,
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.27,
                                        Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    circleRadius: 7,
                                    height: 45,
                                    child: Center(
                                      child: CalendarPickerTableCell(
                                        key: calendarPickerKey,
                                        hintText: 'daily_sales_close.select_date'.tr,
                                        onDateSelected: (DateTime date) {
                                          setState(() {
                                            selectedDate = date;
                                            dateController.text =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(date);
                                          });
                                          fetchData();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                             const SizedBox(width: 15),
                             // Employee Filter
                             Expanded(
                               flex: 1,
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Padding(
                                     padding: const EdgeInsets.all(8.0),
                                     child: Text(
                                       'daily_sales_close.sales_executive'.tr,
                                       style: buildCustomStyle(
                                         FontWeightManager.regular,
                                         FontSize.s14,
                                         0.27,
                                         Colors.black.withOpacity(0.6),
                                       ),
                                     ),
                                   ),
                                   Consumer<SalesExecutiveProvider>(
                                     builder: (context, execProvider, child) {
                                       return CustomDropDownWithSearch<exec_model.SalesExecutive>(
                                         hintText: 'daily_sales_close.hint_select_employee'.tr,
                                         items: execProvider.salesExecutives,
                                         displayText: (exec) => exec.name,
                                         value: selectedExecutive,
                                         onChanged: (exec) {
                                           setState(() {
                                             selectedExecutive = exec;
                                           });
                                           fetchData();
                                         },
                                         searchHintText: 'daily_sales_close.search_hint_name'.tr,
                                       );
                                     },
                                   ),
                                 ],
                               ),
                             ),
                             const SizedBox(width: 15),

                            // Reset button
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 35.0),
                                child: CustomRoundButton(
                                  title: 'general.reset'.tr,
                                  boxColor: Colors.white,
                                  textColor: ColorManager.kPrimaryColor,
                                  fct: resetSearch,
                                  height: 45,
                                  width: double.infinity,
                                  fontSize: FontSize.s12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
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
                        return _buildEmptyState(salesProvider);
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
                                      return _buildMobileCard(data);
                                    },
                                  )
                                : _buildDailySalesTable(salesProvider),
                          ),
                          if (salesProvider.dailySalesClosePagination != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: PaginationControl(
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

  Widget _buildMobileCard(DailySalesCloseData data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.salesExecutive?.name ?? 'daily_sales_close.card_unknown'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.15,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.closingDate ?? '-',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.0,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.orders_prefix'.tr.trim(),
                  data.totalOrders?.toString() ?? '0',
                ),
              ),
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.total_sales'.tr,
                  data.totalSales ?? '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.card_user_id'.tr,
                  data.salesExecutive?.id?.toString() ?? '-',
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildItemDetail(
                  'daily_sales_close.sales_executive'.tr,
                  data.salesExecutive?.name ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.cash_sales'.tr,
                  data.totalCash ?? '0.00',
                ),
              ),
              Expanded(
                child: _buildItemDetail(
                  'daily_sales_close.online_sales'.tr,
                  data.totalOnline ?? '0.00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final salesProvider =
                      Provider.of<SalesProvider>(context, listen: false);
                  salesProvider.setSelectedDailySalesCloseData(data);
                  salesProvider.setReturnIndex(84); // Admin list index
                  Get.find<SideBarController>().index.value = 79; // Detail screen index
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('daily_sales_close.btn_view_details'.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.0,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.0,
            Colors.black87,
          ),
        ),
      ],
    );
  }
}
