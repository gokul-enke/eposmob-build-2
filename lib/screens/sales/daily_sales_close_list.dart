import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../models/daily_sales_close.dart';

class DailySalesCloseListScreen extends StatefulWidget {
  const DailySalesCloseListScreen({super.key});

  @override
  State<DailySalesCloseListScreen> createState() =>
      _DailySalesCloseListScreenState();
}

class _DailySalesCloseListScreenState extends State<DailySalesCloseListScreen> {
  final TextEditingController dateController = TextEditingController();
  DateTime? selectedDate;
  Key calendarPickerKey = UniqueKey();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default date to today
    selectedDate = DateTime.now();
    dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
    // Ensure filters are shown by default on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isMobile = _isMobile(context);
      Provider.of<SalesProvider>(context, listen: false)
          .setFiltersVisibility(!isMobile);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchData();
    });
  }

  @override
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  Future<void> fetchData({int page = 1}) async {
    debugPrint('=== DEBUG: fetchData START ===');
    debugPrint('Fetching daily sales close data...');

    setState(() {
      isLoading = true;
    });
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final userId = authModel.userId ?? 0;
      final storeId = storeSession.activeStore?.storeId ?? 0;
      final date = dateController.text;

      // DEBUG: Print parameters
      debugPrint('=== DEBUG: fetchData Parameters ===');
      debugPrint('Page: $page');
      debugPrint('Date: $date');
      debugPrint('User ID: $userId');
      debugPrint('Store ID: $storeId');

      await salesProvider.fetchDailySalesClose(
        accessToken: authModel.token ?? '',
        date: date,
        page: page,
        userId: userId,
        storeId: storeId,
      );

      debugPrint('=== DEBUG: fetchData SUCCESS ===');
    } catch (e) {
      debugPrint('=== DEBUG: fetchData ERROR ===');
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
      selectedDate = DateTime.now();
      dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
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
            // View details - navigate to detail view
            // TODO: Implement navigation to daily sales close detail view
          },
        ),
      ],
    );
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
                0: FlexColumnWidth(2), // Sales Executive
                1: FlexColumnWidth(2), // Phone
                2: FlexColumnWidth(2), // Store
                3: FlexColumnWidth(2), // Closing Period
                4: FlexColumnWidth(1.5), // Total Orders
                5: FlexColumnWidth(2), // Total Sales
                6: FlexColumnWidth(2), // Online Sales
                7: FlexColumnWidth(2), // Cash Sales
                8: FlexColumnWidth(2), // Credit Amount
                9: FixedColumnWidth(100), // Action
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('Sales Executive'),
                    _buildTableHeader('Phone'),
                    _buildTableHeader('Store'),
                    _buildTableHeader('Closing Period'),
                    _buildTableHeader('Total Orders'),
                    _buildTableHeader('Total Sales'),
                    _buildTableHeader('Online Sales'),
                    _buildTableHeader('Cash Sales'),
                    _buildTableHeader('Credit Amount'),
                    _buildTableHeader('Action'),
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
                      0: FlexColumnWidth(2), // Sales Executive
                      1: FlexColumnWidth(2), // Phone
                      2: FlexColumnWidth(2), // Store
                      3: FlexColumnWidth(2), // Closing Period
                      4: FlexColumnWidth(1.5), // Total Orders
                      5: FlexColumnWidth(2), // Total Sales
                      6: FlexColumnWidth(2), // Online Sales
                      7: FlexColumnWidth(2), // Cash Sales
                      8: FlexColumnWidth(2), // Credit Amount
                      9: FixedColumnWidth(100), // Action
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...provider.dailySalesCloseList.asMap().entries.map((entry) {
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
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Daily Sales Closes Found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or date range',
            style: TextStyle(
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
    SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;

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
                      "Daily Sales Closes",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
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
                                  decoration: BoxDecoration(
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
                                      "Date",
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
                                        onDateSelected: (DateTime date) {
                                          setState(() {
                                            selectedDate = date;
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

                            // Reset button
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 35.0),
                                child: CustomRoundButton(
                                  title: "Reset",
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
                                    itemCount:
                                        salesProvider.dailySalesCloseList.length,
                                    itemBuilder: (context, index) {
                                      // TODO: Create mobile card widget if needed
                                      return const SizedBox.shrink();
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
}
