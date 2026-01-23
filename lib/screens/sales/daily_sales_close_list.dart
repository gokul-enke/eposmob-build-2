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
import '../../components/build_dialog_box.dart';
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

  void _showDayCloseModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DayCloseModal(
          onSuccess: () {
            fetchData(page: 1);
          },
        );
      },
    );
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
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return DayCloseViewModal(data: data);
      },
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
                    Row(
                      children: [
                        // Day Close Button
                        ElevatedButton.icon(
                          onPressed: () => _showDayCloseModal(context),
                          icon: const Icon(Icons.access_time, size: 18, color: Colors.white),
                          label: Text(
                            "Day Close",
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.18,
                              Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.kSuccessColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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

// Day Close Modal Widget
class DayCloseModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const DayCloseModal({super.key, required this.onSuccess});

  @override
  State<DayCloseModal> createState() => _DayCloseModalState();
}

class _DayCloseModalState extends State<DayCloseModal> {
  bool isLoadingSummary = true;
  bool isSubmitting = false;
  DailySalesCloseSummary? summary;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      isLoadingSummary = true;
      errorMessage = null;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;

      final result = await salesProvider.fetchDailySalesCloseSummary(
        accessToken: authModel.token ?? '',
        storeId: storeId,
      );

      setState(() {
        summary = result;
        isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingSummary = false;
      });
    }
  }

  Future<void> _submitDayClose() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;

      final result = await salesProvider.createDailySalesClose(
        accessToken: authModel.token ?? '',
        storeId: storeId,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          showScaffold(
            context: context,
            message: result['message'] ?? 'Day close created successfully',
          );
          widget.onSuccess();
        }
      } else {
        if (mounted) {
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'Failed to create day close',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSummaryCard(String label, String value, {Color? labelColor, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.18,
                labelColor ?? Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.18,
              valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryRow(String label1, String value1, String label2, String value2, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label1,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    Colors.grey.shade700,
                  ),
                ),
                Text(
                  value1,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s11,
                    0.18,
                    valueColor ?? ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label2,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.18,
                    Colors.grey.shade700,
                  ),
                ),
                Text(
                  value2,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s11,
                    0.18,
                    valueColor ?? ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: isMobile ? size.width * 0.95 : 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day Close',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            if (isLoadingSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Consumer<AppSettingsProvider>(
                builder: (context, appSettingsProvider, child) {
                  final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Summary',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.21,
                          Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Orders and Total Sales
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'TOTAL ORDERS',
                              summary?.totalOrders?.toString() ?? '0',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'TOTAL SALES',
                              '$currency ${summary?.totalSales ?? '0.00'}',
                              labelColor: ColorManager.kPrimaryColor,
                              valueColor: ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Payment Received and Collected On Sale
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'PAYMENT RECEIVED',
                              '$currency ${summary?.paymentReceived ?? '0.00'}',
                              labelColor: ColorManager.kSuccessColor,
                              valueColor: ColorManager.kSuccessColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'COLLECTED ON SALE',
                              '$currency ${summary?.collectedOnSale ?? '0.00'}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Small summary rows
                      _buildSmallSummaryRow(
                        'CASH SALES',
                        '$currency ${summary?.cashSales ?? '0.00'}',
                        'ONLINE SALES',
                        '$currency ${summary?.onlineSales ?? '0.00'}',
                      ),
                      const SizedBox(height: 10),
                      _buildSmallSummaryRow(
                        'CREDIT AMOUNT',
                        '$currency ${summary?.creditAmount ?? '0.00'}',
                        'CREDIT COLLECTED',
                        '$currency ${summary?.creditCollected ?? '0.00'}',
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),

            // Footer buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSubmitting || isLoadingSummary || errorMessage != null
                        ? null
                        : _submitDayClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.kSuccessColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.18,
                              Colors.white,
                            ),
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
}

// Day Close View Modal Widget - for viewing existing day close records
class DayCloseViewModal extends StatelessWidget {
  final DailySalesCloseData data;

  const DayCloseViewModal({super.key, required this.data});

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.18,
              valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s13,
          0.21,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Consumer<AppSettingsProvider>(
        builder: (context, appSettingsProvider, child) {
          final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
          
          return BuildBoxShadowContainer(
            circleRadius: 12,
            color: Colors.white,
            width: isMobile ? size.width * 0.95 : 500,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Day Close Details',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.21,
                          ColorManager.kPrimaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  
                  Divider(color: Colors.grey.shade200),

                  // Sales Executive Info
                  _buildSectionTitle('Sales Executive'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Name', data.salesExecutive?.name ?? '-'),
                        _buildDetailRow('Phone', data.salesExecutive?.phone ?? '-'),
                        _buildDetailRow('Store', data.store?.name ?? '-'),
                      ],
                    ),
                  ),

                  // Period Info
                  _buildSectionTitle('Period'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Closing Period', data.closingPeriod ?? '-'),
                        _buildDetailRow('Opening', '${data.openingDate ?? '-'} ${data.openingTime ?? ''}'),
                        _buildDetailRow('Closing', '${data.closingDate ?? '-'} ${data.closingTime ?? ''}'),
                      ],
                    ),
                  ),

                  // Sales Summary
                  _buildSectionTitle('Sales Summary'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Total Orders', data.totalOrders?.toString() ?? '0', valueColor: Colors.blue.shade700),
                        _buildDetailRow('Total Sales', '$currency ${data.totalSales ?? '0.00'}', valueColor: Colors.blue.shade700),
                        _buildDetailRow('Payment Received', '$currency ${data.totalPaymentReceived ?? '0.00'}', valueColor: ColorManager.kSuccessColor),
                        _buildDetailRow('Collected on Sale', '$currency ${data.totalAmountCollectedOnSale ?? '0.00'}'),
                      ],
                    ),
                  ),

                  // Payment Breakdown
                  _buildSectionTitle('Payment Breakdown'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Cash Sales', '$currency ${data.totalCash ?? '0.00'}'),
                        _buildDetailRow('Online Sales', '$currency ${data.totalOnline ?? '0.00'}'),
                        _buildDetailRow('Credit Amount', '$currency ${data.totalCredit ?? '0.00'}', valueColor: Colors.orange.shade700),
                        _buildDetailRow('Credit Collected', '$currency ${data.totalCreditCollected ?? '0.00'}', valueColor: ColorManager.kSuccessColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
