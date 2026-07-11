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
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../components/build_dialog_box.dart';
import '../../models/daily_sales_close.dart';
import 'package:pos_machine/screens/print/print_daily_close.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_detail.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/screens/sales/open_shift_modal.dart';

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
  DayClosePendingStatus? pendingStatus;

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
      final date = dateController.text.isEmpty ? null : dateController.text;

      // DEBUG: Print parameters
      debugPrint('=== DEBUG: fetchData Parameters ===');
      debugPrint('Page: $page');
      debugPrint('Date: $date');
      debugPrint('User ID: $userId');
      debugPrint('Store ID: $storeId');

      await salesProvider.fetchDailySalesClose(
        accessToken: authModel.token ?? '',
        startDate: date,
        endDate: date,
        page: page,
        userId: userId,
        storeId: storeId,
      );

      final pending = await salesProvider.fetchDayClosePendingStatus(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        userId: authModel.userId ?? 0,
      );
      if (mounted) {
        setState(() {
          pendingStatus = pending;
        });
      }

      debugPrint('=== PENDING STATUS DEBUG ===');
      debugPrint('canOpenShift: ${pendingStatus?.canOpenShift}');
      debugPrint('pendingDayClose: ${pendingStatus?.pendingDayClose}');
      debugPrint('message: ${pendingStatus?.message}');
      debugPrint('openingTransactionId: ${pendingStatus?.openingTransactionId}');

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
      selectedDate = null;
      dateController.text = '';
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
    salesProvider.setReturnIndex(78); // User list index
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
                _isMobile(context)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    // Open Shift Button
                                    ElevatedButton.icon(
                                      onPressed: pendingStatus?.canOpenShift == true
                                          ? () => _showOpenShiftModal(context)
                                          : null,
                                      icon: const Icon(Icons.lock_open,
                                          size: 18, color: Colors.white),
                                      label: Text(
                                        "Open Shift",
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.18,
                                          Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2196F3),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    // Day Close Button
                                    ElevatedButton.icon(
                                      onPressed: () => _showDayCloseModal(context),
                                      icon: const Icon(Icons.access_time,
                                          size: 18, color: Colors.white),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
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
                        ],
                      )
                    : Row(
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
                              // Open Shift Button
                              ElevatedButton.icon(
                                onPressed: pendingStatus?.canOpenShift == true
                                    ? () => _showOpenShiftModal(context)
                                    : null,
                                icon: const Icon(Icons.lock_open,
                                    size: 18, color: Colors.white),
                                label: Text(
                                  "Open Shift",
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.18,
                                    Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Day Close Button
                              ElevatedButton.icon(
                                onPressed: () => _showDayCloseModal(context),
                                icon: const Icon(Icons.access_time,
                                    size: 18, color: Colors.white),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
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
                                        hintText: 'Select Date',
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
                                    itemCount: salesProvider
                                        .dailySalesCloseList.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _DayCloseMobileCard(
                                          data: salesProvider.dailySalesCloseList[index],
                                          onTap: () {
                                            _showViewDetailModal(
                                              context,
                                              salesProvider.dailySalesCloseList[index],
                                            );
                                          },
                                        ),
                                      );
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
  final OpenDraftModel? openDraft;
  final String? pendingBusinessDate;
  final int? pendingOpeningTransactionId;
  final int? pendingClosingTransactionId;

  const DayCloseModal({
    super.key,
    required this.onSuccess,
    this.openDraft,
    this.pendingBusinessDate,
    this.pendingOpeningTransactionId,
    this.pendingClosingTransactionId,
  });

  @override
  State<DayCloseModal> createState() => _DayCloseModalState();
}

class _DayCloseModalState extends State<DayCloseModal> {
  bool isLoadingSummary = true;
  bool isSubmitting = false;
  DailySalesCloseSummary? summary;
  String? errorMessage;
  final TextEditingController _businessDateController =
      TextEditingController();
  final TextEditingController _shiftNameController = TextEditingController();
  final TextEditingController _openingTimeController = TextEditingController();
  final TextEditingController _closingTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _cashRefundsController = TextEditingController();
  final TextEditingController _cashExpensesController = TextEditingController();
  final TextEditingController _cashDropAmountController =
      TextEditingController();
  final TextEditingController _openingCashInHandController =
      TextEditingController();
  final TextEditingController _closingCashInHandController =
      TextEditingController();
  final List<TextEditingController> _openingDenominationControllers = [];
  final List<TextEditingController> _openingCountControllers = [];
  final List<TextEditingController> _closingDenominationControllers = [];
  final List<TextEditingController> _closingCountControllers = [];
  final ScrollController _scrollController = ScrollController();

  List<MasterDataValue> _cashDenominations = [];
  bool _isLoadingDenominations = true;
  bool _openingPrefilled = false;
  bool _openingTimeReadOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
    _fetchDenominations();
    _ensureBreakdownRows();
    if (widget.openDraft != null) {
      _prefillFromOpenDraft(widget.openDraft!);
    }
  }

  Future<void> _fetchDenominations() async {
    try {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
      final result = await masterDataProvider.fetchCashDenominations();
      if (mounted) {
        setState(() {
          _cashDenominations = result ?? [];
          _isLoadingDenominations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDenominations = false;
        });
      }
    }
  }

  void _ensureBreakdownRows() {
    if (_openingDenominationControllers.isEmpty) {
      _addOpeningBreakdownRow();
    }
    if (_closingDenominationControllers.isEmpty) {
      _addClosingBreakdownRow();
    }
  }

  void _prefillFromOpenDraft(OpenDraftModel draft) {
    _shiftNameController.text = draft.shiftName ?? '';
    if (draft.openingTime != null &&
        draft.openingTime!.isNotEmpty) {
      _openingTimeController.text = draft.openingTime!;
    }
    final cashSummary = draft.cashSummary;
    if (cashSummary == null) return;

    _openingCashInHandController.text = cashSummary.openingCashInHand ?? '';

    if (cashSummary.openingCashBreakdown != null &&
        cashSummary.openingCashBreakdown!.isNotEmpty) {
      _openingDenominationControllers.clear();
      _openingCountControllers.clear();
      for (final item in cashSummary.openingCashBreakdown!) {
        _addOpeningBreakdownRow(
          denomination: item['denomination']?.toString() ?? '',
          count: item['count']?.toString() ?? '',
        );
      }
    }
    setState(() {
      _openingPrefilled = true;
    });
  }

  void _addOpeningBreakdownRow({String denomination = '', String count = ''}) {
    _openingDenominationControllers
        .add(TextEditingController(text: denomination));
    _openingCountControllers.add(TextEditingController(text: count));
  }

  void _addClosingBreakdownRow({String denomination = '', String count = ''}) {
    _closingDenominationControllers
        .add(TextEditingController(text: denomination));
    _closingCountControllers.add(TextEditingController(text: count));
  }

  void _recalculateClosingCash() {
    double total = 0.0;
    for (var i = 0; i < _closingDenominationControllers.length; i++) {
      final denomText = _closingDenominationControllers[i].text.trim();
      final countText = _closingCountControllers[i].text.trim();
      final denomVal = double.tryParse(denomText) ?? 0.0;
      final countVal = double.tryParse(countText) ?? 0.0;
      total += denomVal * countVal;
    }
    final totalStr = total == 0.0 ? '' : total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    if (_closingCashInHandController.text != totalStr) {
      _closingCashInHandController.text = totalStr;
    }
  }

  List<Map<String, dynamic>> _buildBreakdownPayload(
    List<TextEditingController> denominationControllers,
    List<TextEditingController> countControllers,
  ) {
    final breakdown = <Map<String, dynamic>>[];
    for (var index = 0; index < denominationControllers.length; index++) {
      final denomination = denominationControllers[index].text.trim();
      final countText = countControllers[index].text.trim();
      if (denomination.isEmpty && countText.isEmpty) {
        continue;
      }
      breakdown.add({
        'denomination': denomination,
        'count': int.tryParse(countText) ?? 0,
      });
    }
    return breakdown;
  }

  @override
  void dispose() {
    _businessDateController.dispose();
    _shiftNameController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _notesController.dispose();
    _cashRefundsController.dispose();
    _cashExpensesController.dispose();
    _cashDropAmountController.dispose();
    _openingCashInHandController.dispose();
    _closingCashInHandController.dispose();
    _scrollController.dispose();
    for (final controller in _openingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in _openingCountControllers) {
      controller.dispose();
    }
    for (final controller in _closingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in _closingCountControllers) {
      controller.dispose();
    }
    super.dispose();
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
        businessDate: widget.pendingBusinessDate,
      );

      if (!mounted) return;

      setState(() {
        summary = result;
        _businessDateController.text =
            widget.pendingBusinessDate ?? result?.businessDate ?? '';
        if (!_openingPrefilled) {
          _shiftNameController.text = result?.shiftName ?? '';
        }
        
        // Opening Time: always fill from summary if still empty
        // (widget.openingTime from pending-status can be null)
        if (_openingTimeController.text.isEmpty) {
          _openingTimeController.text = result?.openingTime ?? '';
          _openingTimeReadOnly = (result?.openingTime != null &&
              result!.openingTime!.isNotEmpty);
        }
        _closingTimeController.text = result?.closingTime ?? '';
        _notesController.text = result?.notes ?? '';
        _cashRefundsController.text = result?.cashRefunds?.toString() ?? '';
        _cashExpensesController.text = result?.cashExpenses?.toString() ?? '';
        _cashDropAmountController.text = result?.cashDropAmount?.toString() ?? '';
        if (!_openingPrefilled) {
          _openingCashInHandController.text =
              result?.openingCashInHand?.toString() ?? '';
          // Populate opening breakdown from summary if available
          if (result?.openingCashBreakdown != null &&
              result!.openingCashBreakdown!.isNotEmpty) {
            _openingDenominationControllers.clear();
            _openingCountControllers.clear();
            for (final item in result.openingCashBreakdown!) {
              _addOpeningBreakdownRow(
                denomination: item['denomination']?.toString() ?? '',
                count: item['count']?.toString() ?? '',
              );
            }
          }
        }
        _closingCashInHandController.text =
            result?.closingCashInHand?.toString() ?? '';
        isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;

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
      final appSettings =
          Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;
      debugPrint('=== DAY CLOSE OPENING CHECK DEBUG START ===');
      debugPrint('storeId: $storeId');
      debugPrint('raw summary.openingTime: ${summary?.openingTime}');
      debugPrint('raw summary.closingTime: ${summary?.closingTime}');
      debugPrint('controller openingTime text: "${_openingTimeController.text}"');
      debugPrint('controller closingTime text: "${_closingTimeController.text}"');
      debugPrint('controller businessDate text: "${_businessDateController.text}"');
      debugPrint('controller shiftName text: "${_shiftNameController.text}"');
      debugPrint('controller notes text: "${_notesController.text}"');
      debugPrint('appSettings is null: ${appSettings == null}');
      debugPrint('appSettings.workingTime: "${appSettings?.workingTime}"');

      final workingTimeText = appSettings?.workingTime ?? '';
      debugPrint('workingTimeText length: ${workingTimeText.length}');
      final workingStartTime = _extractWorkingStartTime(workingTimeText);
      debugPrint('parsed workingStartTime: "$workingStartTime"');

      final openingTimeText = _openingTimeController.text.trim().isEmpty
          ? summary?.openingTime
          : _openingTimeController.text.trim();
      debugPrint('final openingTimeText for validation: "$openingTimeText"');

      if (workingStartTime != null && openingTimeText != null) {
        final selectedOpeningTime = _parseTimeOfDay(openingTimeText);
        debugPrint('parsed selectedOpeningTime: $selectedOpeningTime');
        if (selectedOpeningTime != null) {
          final isBefore = _isTimeBefore(selectedOpeningTime, workingStartTime);
          debugPrint('comparison result selected < workingStart: $isBefore');
          if (isBefore) {
            debugPrint('BLOCKED: opening time is before working start time');
            if (mounted) {
              showScaffoldError(
                context: context,
                message:
                    'Opening time cannot be before working time start ($workingStartTime).',
              );
            }
            debugPrint('=== DAY CLOSE OPENING CHECK DEBUG END (BLOCKED) ===');
            return;
          }
        } else {
          debugPrint('WARNING: selectedOpeningTime parsed as null');
        }
      } else {
        debugPrint(
          'SKIP CHECK: workingStartTime or openingTimeText is null/empty',
        );
      }

      debugPrint('=== DEBUG: createDailySalesClose CALLER CONTEXT ===');
      debugPrint('store_id: $storeId');
      debugPrint('Summary opening_time: ${summary?.openingTime}');
      debugPrint('Summary closing_time: ${summary?.closingTime}');
      debugPrint('Summary opening_date: ${summary?.openingDate}');
      debugPrint('Summary closing_date: ${summary?.closingDate}');
      debugPrint('selected shift_name: ${_shiftNameController.text.trim()}');
      debugPrint('selected business_date: ${_businessDateController.text.trim()}');
      debugPrint('selected opening_time: ${_openingTimeController.text.trim()}');
      debugPrint('selected closing_time: ${_closingTimeController.text.trim()}');
      debugPrint('selected cash_refunds: ${_cashRefundsController.text.trim()}');
      debugPrint('selected cash_expenses: ${_cashExpensesController.text.trim()}');
      debugPrint('selected cash_drop_amount: ${_cashDropAmountController.text.trim()}');
      debugPrint('selected opening_cash_in_hand: ${_openingCashInHandController.text.trim()}');
      debugPrint('selected closing_cash_in_hand: ${_closingCashInHandController.text.trim()}');
      debugPrint('opening breakdown rows: ${_openingDenominationControllers.length}');
      for (var i = 0; i < _openingDenominationControllers.length; i++) {
        debugPrint(
          'opening row $i => denom="${_openingDenominationControllers[i].text}" count="${_openingCountControllers[i].text}"',
        );
      }
      debugPrint('closing breakdown rows: ${_closingDenominationControllers.length}');
      for (var i = 0; i < _closingDenominationControllers.length; i++) {
        debugPrint(
          'closing row $i => denom="${_closingDenominationControllers[i].text}" count="${_closingCountControllers[i].text}"',
        );
      }

      final result = await salesProvider.createDailySalesClose(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        shiftName: _shiftNameController.text.trim().isEmpty
            ? summary?.shiftName
            : _shiftNameController.text.trim(),
        businessDate: _businessDateController.text.trim().isEmpty
            ? summary?.businessDate
            : _businessDateController.text.trim(),
        openingDate: summary?.openingDate,
        openingTime: _openingTimeController.text.trim().isEmpty
            ? summary?.openingTime
            : _openingTimeController.text.trim(),
        closingDate: summary?.closingDate,
        closingTime: _closingTimeController.text.trim().isEmpty
            ? summary?.closingTime
            : _closingTimeController.text.trim(),
        cashRefunds: num.tryParse(_cashRefundsController.text.trim()) ??
            summary?.cashRefunds,
        cashExpenses: num.tryParse(_cashExpensesController.text.trim()) ??
            summary?.cashExpenses,
        cashDropAmount: num.tryParse(_cashDropAmountController.text.trim()) ??
            summary?.cashDropAmount,
        openingCashInHand:
            num.tryParse(_openingCashInHandController.text.trim()) ??
                summary?.openingCashInHand,
        openingCashBreakdown: _buildBreakdownPayload(
          _openingDenominationControllers,
          _openingCountControllers,
        ),
        closingCashInHand:
            num.tryParse(_closingCashInHandController.text.trim()) ??
                summary?.closingCashInHand,
        closingCashBreakdown: _buildBreakdownPayload(
          _closingDenominationControllers,
          _closingCountControllers,
        ),
        notes: _notesController.text.trim().isEmpty
            ? summary?.notes
            : _notesController.text.trim(),
        openingTransactionId: widget.pendingOpeningTransactionId,
        closingTransactionId: widget.pendingClosingTransactionId,
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
        debugPrint('DAY CLOSE RESULT FAILURE: ${result['message']}');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'Failed to create day close',
          );
        }
      }
    } catch (e) {
      debugPrint('=== DAY CLOSE SUBMIT EXCEPTION ===');
      debugPrint('error: $e');
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
      debugPrint('=== DAY CLOSE OPENING CHECK DEBUG END ===');
    }
  }

  Widget _buildSummaryCard(String label, String value,
      {Color? color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  Colors.grey.shade500,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s16,
              0.18,
              color ?? ColorManager.kTitleTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryRow(
      String label1, String value1, String label2, String value2,
      {Color? color1, Color? color2}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            children: [
              _buildSmallSummaryItem(label1, value1, color: color1),
              const SizedBox(height: 10),
              _buildSmallSummaryItem(label2, value2, color: color2),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
                child: _buildSmallSummaryItem(label1, value1, color: color1)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSmallSummaryItem(label2, value2, color: color2)),
          ],
        );
      },
    );
  }

  Widget _buildSmallSummaryItem(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              color ?? ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.18,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              ColorManager.kTitleTextColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              enabled ? ColorManager.textColor : ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: CalendarPickerTableCell(
            initialDate: _parseDate(controller.text) ?? DateTime.now(),
            onDateSelected: (picked) {
              setState(() {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnRow({
    required bool isNarrow,
    required Widget left,
    required Widget right,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String? _extractWorkingStartTime(String workingTime) {
    final match = RegExp(r'(\d{2}:\d{2})(?::\d{2})?\s*-\s*\d{2}:\d{2}')
        .firstMatch(workingTime);
    return match?.group(1);
  }

  TimeOfDay? _parseTimeOfDay(String timeValue) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timeValue);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeBefore(TimeOfDay a, String b) {
    final parsedB = _parseTimeOfDay(b);
    if (parsedB == null) return false;
    return a.hour < parsedB.hour ||
        (a.hour == parsedB.hour && a.minute < parsedB.minute);
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: readOnly
              ? TextFormField(
                  controller: controller,
                  enabled: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                )
              : TimePickerTableCell(
                  initialTime: _parseTimeOfDay(controller.text),
                  onTimeSelected: (picked) {
                    setState(() {
                      controller.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                    });
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required TextEditingController controller,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12, top: 6, right: 10),
          height: maxLines > 1 ? 92 : 42,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required List<TextEditingController> denominationControllers,
    required List<TextEditingController> countControllers,
    required bool isNarrow,
    required VoidCallback onAddRow,
    bool isReadOnly = false,
    ValueChanged<String?>? onDenominationChanged,
    ValueChanged<String>? onCountChanged,
    VoidCallback? onRowRemoved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                Colors.grey.shade800,
              ),
            ),
            if (!isReadOnly)
              TextButton(
                onPressed: onAddRow,
                child: const Text('Add Row'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(denominationControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDenominationRow(
                        denominationController: denominationControllers[index],
                        countController: countControllers[index],
                        isNarrow: true,
                        allDenominationControllers: denominationControllers,
                        index: index,
                        isReadOnly: isReadOnly,
                        onDenominationChanged: onDenominationChanged,
                        onCountChanged: onCountChanged,
                      ),
                      const SizedBox(height: 4),
                      if (!isReadOnly)
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Remove row',
                              onPressed: denominationControllers.length == 1
                                  ? null
                                  : () {
                                      setState(() {
                                        denominationControllers[index].dispose();
                                        countControllers[index].dispose();
                                        denominationControllers.removeAt(index);
                                        countControllers.removeAt(index);
                                      });
                                      if (onRowRemoved != null) {
                                        onRowRemoved();
                                      }
                                    },
                              icon: const Icon(Icons.remove_circle_outline,
                                  size: 18, color: Colors.red),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDenominationRow(
                          denominationController: denominationControllers[index],
                          countController: countControllers[index],
                          isNarrow: false,
                          allDenominationControllers: denominationControllers,
                          index: index,
                          isReadOnly: isReadOnly,
                          onDenominationChanged: onDenominationChanged,
                          onCountChanged: onCountChanged,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isReadOnly)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove row',
                            onPressed: denominationControllers.length == 1
                              ? null
                              : () {
                                  setState(() {
                                    denominationControllers[index].dispose();
                                    countControllers[index].dispose();
                                    denominationControllers.removeAt(index);
                                    countControllers.removeAt(index);
                                  });
                                  if (onRowRemoved != null) {
                                    onRowRemoved();
                                  }
                                },
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.red),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildDenominationRow({
    required TextEditingController denominationController,
    required TextEditingController countController,
    required bool isNarrow,
    required List<TextEditingController> allDenominationControllers,
    required int index,
    bool isReadOnly = false,
    ValueChanged<String?>? onDenominationChanged,
    ValueChanged<String>? onCountChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNarrow
            ? Column(
                children: [
                  _buildDenominationDropdown(
                    controller: denominationController,
                    allDenominationControllers: allDenominationControllers,
                    index: index,
                    isReadOnly: isReadOnly,
                    onChanged: onDenominationChanged,
                  ),
                  const SizedBox(height: 6),
                  _buildCompactField(
                    label: 'Count',
                    controller: countController,
                    keyboardType: TextInputType.number,
                    enabled: !isReadOnly,
                    onChanged: onCountChanged,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildDenominationDropdown(
                      controller: denominationController,
                      allDenominationControllers: allDenominationControllers,
                      index: index,
                      isReadOnly: isReadOnly,
                      onChanged: onDenominationChanged,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildCompactField(
                      label: 'Count',
                      controller: countController,
                      keyboardType: TextInputType.number,
                      enabled: !isReadOnly,
                      onChanged: onCountChanged,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildDenominationDropdown({
    required TextEditingController controller,
    required List<TextEditingController> allDenominationControllers,
    required int index,
    bool isReadOnly = false,
    ValueChanged<String?>? onChanged,
  }) {
    final currentValue = controller.text.trim().isEmpty
        ? null
        : controller.text.trim();
    final hasMatch =
        _cashDenominations.any((d) => d.value == currentValue);
    final selectedValue = hasMatch ? currentValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Denomination',
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          width: double.infinity,
          child: _isLoadingDenominations
              ? const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: selectedValue,
                    disabledHint: selectedValue != null
                        ? Text(
                            _cashDenominations
                                .firstWhere((d) => d.value == selectedValue,
                                    orElse: () => MasterDataValue(id: 0, value: selectedValue, description: selectedValue))
                                .description,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s10,
                              0.20,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          )
                        : null,
                    hint: Text(
                      'Select',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.20,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    items: _cashDenominations
                        .where((d) {
                          // Get all currently selected denominations 
                          // except the current row's own selection
                          final selectedOthers = allDenominationControllers
                              .asMap()
                              .entries
                              .where((e) => e.key != index)
                              .map((e) => e.value.text.trim())
                              .toSet();
                          // Allow this denomination if not selected 
                          // in any other row, or if it's empty
                          return !selectedOthers.contains(d.value ?? '');
                        })
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d.value,
                            child: Text(
                              d.description.isNotEmpty
                                  ? d.description
                                  : d.value,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.20,
                                isReadOnly
                                    ? ColorManager.textColor.withOpacity(.5)
                                    : ColorManager.textColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (value) {
                            setState(() {
                              controller.text = value ?? '';
                            });
                            if (onChanged != null) {
                              onChanged(value);
                            }
                          },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: ColorManager.kPrimaryColor,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.20,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.20,
              enabled ? ColorManager.textColor : ColorManager.textColor.withOpacity(.5),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BuildBoxShadowContainer(
        circleRadius: 20,
        color: Colors.white,
        width: isMobile ? size.width * 0.98 : 760,
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            final maxHeight = size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day Close',
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.21,
                                ColorManager.kTitleTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Summary of today\'s activities',
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.18,
                                Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                    Icon(Icons.error_outline,
                                        color: Colors.red.shade400, size: 48),
                                    const SizedBox(height: 16),
                                    Text(
                                      errorMessage!,
                                      style:
                                          TextStyle(color: Colors.red.shade600),
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
                                final currency =
                                    appSettingsProvider.appSettings?.currency ??
                                        'INR';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User Name & Store Info Section
                                    Text(
                                      'Session Information',
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.21,
                                        Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildInfoRow(
                                              Icons.person_outline,
                                              'User',
                                              summary?.userName ?? '-'),
                                          const SizedBox(height: 10),
                                          _buildInfoRow(
                                              Icons.calendar_today_outlined,
                                              'Opening',
                                              '${summary?.openingDate ?? '-'} at ${summary?.openingTime ?? '-'}'),
                                          const SizedBox(height: 10),
                                          _buildInfoRow(
                                              Icons.event_available_outlined,
                                              'Closing',
                                              '${summary?.closingDate ?? '-'} at ${summary?.closingTime ?? '-'}'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTwoColumnRow(
                                      isNarrow: isNarrow,
                                      left: _buildDateField(
                                        label: 'Business Date',
                                        controller: _businessDateController,
                                      ),
                                      right: _buildAmountField(
                                        label: 'Shift Name',
                                        controller: _shiftNameController,
                                        enabled: !_openingPrefilled,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTwoColumnRow(
                                      isNarrow: isNarrow,
                                      left: _buildTimePickerField(
                                        label: 'Opening Time',
                                        controller: _openingTimeController,
                                        readOnly: _openingPrefilled || _openingTimeReadOnly,
                                      ),
                                      right: _buildTimePickerField(
                                        label: 'Closing Time',
                                        controller: _closingTimeController,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    Text(
                                      'Transaction Overview',
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.21,
                                        Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Total Orders and Total Sales
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: isNarrow
                                              ? double.infinity
                                              : (constraints.maxWidth - 12) / 2,
                                          child: _buildSummaryCard(
                                            'TOTAL ORDERS',
                                            summary?.totalOrders?.toString() ??
                                                '0',
                                            icon: Icons.shopping_bag_outlined,
                                          ),
                                        ),
                                        SizedBox(
                                          width: isNarrow
                                              ? double.infinity
                                              : (constraints.maxWidth - 12) / 2,
                                          child: _buildSummaryCard(
                                            'TOTAL SALES',
                                            '$currency ${summary?.totalSales ?? '0.00'}',
                                            color: ColorManager.kPrimaryColor,
                                            icon: Icons
                                                .account_balance_wallet_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Payment Received and Collected On Sale
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: isNarrow
                                              ? double.infinity
                                              : (constraints.maxWidth - 12) / 2,
                                          child: _buildSummaryCard(
                                            'PAYMENT RECEIVED',
                                            '$currency ${summary?.paymentReceived ?? '0.00'}',
                                            icon: Icons.check_circle_outline,
                                          ),
                                        ),
                                        SizedBox(
                                          width: isNarrow
                                              ? double.infinity
                                              : (constraints.maxWidth - 12) / 2,
                                          child: _buildSummaryCard(
                                            'COLLECTED ON SALE',
                                            '$currency ${summary?.collectedOnSale ?? '0.00'}',
                                            icon: Icons.monetization_on_outlined,
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
                                    const SizedBox(height: 16),

                                    Text(
                                      'Cash In Hand',
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.21,
                                        Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAmountField(
                                      label: 'Opening Cash In Hand',
                                      controller: _openingCashInHandController,
                                      enabled: !_openingPrefilled,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAmountField(
                                      label: 'Closing Cash In Hand',
                                      controller: _closingCashInHandController,
                                    ),
                                    const SizedBox(height: 16),

                                    // Returns & Refunds Section
                                    Text(
                                      'Returns & Refunds',
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.21,
                                        Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSmallSummaryRow(
                                      'TOTAL RETURNS',
                                      '$currency ${summary?.totalReturns ?? '0.00'}',
                                      'TOTAL REFUNDS',
                                      '$currency ${summary?.totalRefunds ?? '0.00'}',
                                      color1: Colors.red.shade600,
                                      color2: Colors.red.shade600,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildBreakdownSection(
                                      title: 'Opening Cash Breakdown',
                                      denominationControllers:
                                          _openingDenominationControllers,
                                      countControllers:
                                          _openingCountControllers,
                                      isNarrow: isNarrow,
                                      isReadOnly: _openingPrefilled,
                                      onAddRow: () {
                                        setState(() {
                                          _addOpeningBreakdownRow();
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              _scrollController.position.maxScrollExtent,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildBreakdownSection(
                                      title: 'Closing Cash Breakdown',
                                      onDenominationChanged: (_) => _recalculateClosingCash(),
                                      onCountChanged: (_) => _recalculateClosingCash(),
                                      onRowRemoved: () => _recalculateClosingCash(),
                                      denominationControllers:
                                          _closingDenominationControllers,
                                      countControllers:
                                          _closingCountControllers,
                                      isNarrow: isNarrow,
                                      onAddRow: () {
                                        setState(() {
                                          _addClosingBreakdownRow();
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              _scrollController.position.maxScrollExtent,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTwoColumnRow(
                                      isNarrow: isNarrow,
                                      left: _buildAmountField(
                                        label: 'Cash Refunds',
                                        controller: _cashRefundsController,
                                      ),
                                      right: _buildAmountField(
                                        label: 'Cash Expenses',
                                        controller: _cashExpensesController,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAmountField(
                                      label: 'Cash Drop Amount',
                                      controller: _cashDropAmountController,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextAreaField(
                                      label: 'Notes',
                                      controller: _notesController,
                                      maxLines: 3,
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer buttons
                  if (isNarrow)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.grey.shade100,
                            ),
                            child: Text(
                              'Cancel',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s13,
                                0.18,
                                Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorManager.kSuccessColor
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isSubmitting ||
                                      isLoadingSummary ||
                                      errorMessage != null
                                  ? null
                                  : _submitDayClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorManager.kSuccessColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Close Day',
                                      style: buildCustomStyle(
                                        FontWeightManager.bold,
                                        FontSize.s13,
                                        0.18,
                                        Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.grey.shade100,
                            ),
                            child: Text(
                              'Cancel',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s13,
                                0.18,
                                Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorManager.kSuccessColor
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isSubmitting ||
                                      isLoadingSummary ||
                                      errorMessage != null
                                  ? null
                                  : _submitDayClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorManager.kSuccessColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Close Day',
                                      style: buildCustomStyle(
                                        FontWeightManager.bold,
                                        FontSize.s13,
                                        0.18,
                                        Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DayCloseMobileCard extends StatelessWidget {
  final DailySalesCloseData data;
  final VoidCallback onTap;
  
  const _DayCloseMobileCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<AppSettingsProvider>(
      context, listen: false)
      .appSettings?.currency ?? 'SAR';
      
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        circleRadius: 10,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: closing period + total sales
              Row(
                mainAxisAlignment: 
                  MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data.closingPeriod ?? '-',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s13, 0.19,
                      ColorManager.textColor),
                  ),
                  Text(
                    '$currency ${data.totalSales ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s13, 0.19,
                      ColorManager.kPrimaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Sales executive
              Text(
                data.salesExecutive?.name ?? '-',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12, 0.18,
                  Colors.black87),
              ),
              const SizedBox(height: 4),
              // Store
              Text(
                data.store?.name ?? '-',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12, 0.18,
                  Colors.black54),
              ),
              const SizedBox(height: 6),
              // Orders + Cash row
              Row(
                children: [
                  Text(
                    'Orders: ${data.totalOrders ?? 0}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11, 0.16,
                      Colors.black87),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Cash: $currency ${data.totalCash ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11, 0.16,
                      Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Online + Credit row
              Row(
                children: [
                  Text(
                    'Online: $currency ${data.totalOnline ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11, 0.16,
                      Colors.black87),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Credit: $currency ${data.totalCredit ?? "0"}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11, 0.16,
                      Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),
              // Business date
              Text(
                'Business Date: ${data.businessDate ?? "-"}',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11, 0.16,
                  Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
