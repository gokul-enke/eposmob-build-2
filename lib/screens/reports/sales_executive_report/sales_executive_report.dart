import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class SalesExecutiveReportScreen extends StatefulWidget {
  const SalesExecutiveReportScreen({super.key});

  @override
  State<SalesExecutiveReportScreen> createState() =>
      _SalesExecutiveReportScreenState();
}

class _SalesExecutiveReportScreenState
    extends State<SalesExecutiveReportScreen> {
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();

  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      SalesExecutiveProvider salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);

      // Fetch sales executives first
      await salesExecutiveProvider.fetchSalesExecutives(context);

      // Then fetch sales executive report data
      await fetchSalesExecutiveReport();
    } catch (error) {
      debugPrint('Error loading sales executive data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  Future<void> fetchSalesExecutiveReport() async {
    try {
      SalesExecutiveProvider salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);

      String? fromDate;
      String? toDate;

      // Convert DD/MM/YYYY to YYYY-MM-DD format for API if dates are provided
      if (fromDateController.text.isNotEmpty) {
        List<String> fromDateParts = fromDateController.text.split('/');
        if (fromDateParts.length == 3) {
          // Ensure proper padding for month and day
          String day = fromDateParts[0].padLeft(2, '0');
          String month = fromDateParts[1].padLeft(2, '0');
          String year = fromDateParts[2];
          fromDate = '$year-$month-$day';
        }
      }

      if (toDateController.text.isNotEmpty) {
        List<String> toDateParts = toDateController.text.split('/');
        if (toDateParts.length == 3) {
          // Ensure proper padding for month and day
          String day = toDateParts[0].padLeft(2, '0');
          String month = toDateParts[1].padLeft(2, '0');
          String year = toDateParts[2];
          toDate = '$year-$month-$day';
        }
      }

      debugPrint(
          '📊 Fetching report with dates - From: $fromDate, To: $toDate');

      final response = await salesExecutiveProvider.getSalesExecutiveReport(
        context: context,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (response != null && response['status'] == 'error') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to fetch report data'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('❌ Error fetching sales executive report: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching report: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void searchSalesExecutives() {
    // Fetch report data with current date filters
    fetchSalesExecutiveReport();
  }

  void resetSearch() {
    setState(() {
      fromDateController.clear();
      toDateController.clear();
    });

    // Clear report data and fetch fresh data
    SalesExecutiveProvider salesExecutiveProvider =
        Provider.of<SalesExecutiveProvider>(context, listen: false);
    salesExecutiveProvider.clearReportData();

    fetchSalesExecutiveReport();
  }

  // Date selection method
  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorManager.kPrimaryColor, // Header background color
              onPrimary: Colors.white, // Header text color
              surface: Colors.white, // Calendar background
              onSurface: Colors.black, // Calendar text color
            ),
            dialogBackgroundColor: Colors.white, // Dialog background
            cardColor: Colors.white, // Card background
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format date as DD/MM/YYYY for display
      final formattedDate =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      if (isFromDate) {
        fromDateController.text = formattedDate;
      } else {
        toDateController.text = formattedDate;
      }
      // Trigger search immediately after date selection
      searchSalesExecutives();
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SalesExecutiveProvider salesExecutiveProvider =
        Provider.of<SalesExecutiveProvider>(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => loadInitData(),
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
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                const SizedBox(height: 20),
                _buildExecutiveTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "My Sales Report",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // Filter Row with 4 fields (From Date, To Date, Empty Space, Reset Button)
        SizedBox(
          height: 90,
          child: Row(
            children: [
              // From Date Filter
              Expanded(
                flex: 1,
                child: _buildFromDateFilter(),
              ),
              const SizedBox(width: 15),
              // To Date Filter
              Expanded(
                flex: 1,
                child: _buildToDateFilter(),
              ),
              const SizedBox(width: 15),
              // Empty Space (maintaining 4-field layout)
              Expanded(
                flex: 1,
                child: Container(), // Empty space to maintain 4-field layout
              ),
              const SizedBox(width: 15),
              // Reset Button (always in 4th position)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42),
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
        ),
      ],
    );
  }

  Widget _buildFromDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "From Date",
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                0.27, Colors.black.withOpacity(0.6)),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: fromDateController,
            onTap: () => _selectDate(context, isFromDate: true),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "DD/MM/YYYY",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "To Date",
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                0.27, Colors.black.withOpacity(0.6)),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: toDateController,
            onTap: () => _selectDate(context, isFromDate: false),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "DD/MM/YYYY",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveTable() {
    return Expanded(
      child: Consumer<SalesExecutiveProvider>(
          builder: (context, salesExecutiveProvider, child) {
        final isLoading = salesExecutiveProvider.isLoading ||
            salesExecutiveProvider.isReportLoading;
        final reportList = salesExecutiveProvider.salesExecutiveReportList;
        final reportError = salesExecutiveProvider.reportError;

        return Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : BuildBoxShadowContainer(
                      margin: const EdgeInsets.only(top: 5),
                      circleRadius: 7,
                      offsetValue: const Offset(2, 2),
                      blurRadius: 8.0,
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Fixed table header
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
                                0: FlexColumnWidth(2.0), // Executive Name
                                1: FlexColumnWidth(1.5), // Phone
                                2: FlexColumnWidth(1.5), // Total Orders
                                3: FlexColumnWidth(1.5), // Total Sales
                                4: FlexColumnWidth(1.5), // UPI Sales
                                5: FlexColumnWidth(1.5), // Cash Sales
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildTableHeader("Executive Name"),
                                    _buildTableHeader("Phone"),
                                    _buildTableHeader("Total Orders"),
                                    _buildTableHeader("Total Sales"),
                                    _buildTableHeader("UPI Sales"),
                                    _buildTableHeader("Cash Sales"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Scrollable table body
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: ScrollConfiguration(
                                behavior:
                                    ScrollConfiguration.of(context).copyWith(
                                  dragDevices: {
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.stylus,
                                    PointerDeviceKind.trackpad,
                                  },
                                ),
                                child: reportError != null
                                    ? _buildErrorUI(reportError)
                                    : reportList.isEmpty
                                        ? _buildNoDataFoundUI()
                                        : SingleChildScrollView(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            scrollDirection: Axis.vertical,
                                            child: Table(
                                              columnWidths: const {
                                                0: FlexColumnWidth(
                                                    2.0), // Executive Name
                                                1: FlexColumnWidth(
                                                    1.5), // Phone
                                                2: FlexColumnWidth(
                                                    1.5), // Total Orders
                                                3: FlexColumnWidth(
                                                    1.5), // Total Sales
                                                4: FlexColumnWidth(
                                                    1.5), // UPI Sales
                                                5: FlexColumnWidth(
                                                    1.5), // Cash Sales
                                              },
                                              border: null,
                                              defaultVerticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              children:
                                                  reportList.map((report) {
                                                return TableRow(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                  ),
                                                  children: [
                                                    _buildTableCell(
                                                        report.name ?? "N/A"),
                                                    _buildTableCell(
                                                        report.phone ?? "N/A"),
                                                    _buildTableCell(report
                                                            .orderCount
                                                            ?.toString() ??
                                                        "0"),
                                                    _buildTableCell(
                                                        "₹${report.formattedTotalSales}"),
                                                    _buildTableCell(
                                                        "₹${report.formattedUpiSales}"),
                                                    _buildTableCell(
                                                        "₹${report.formattedCashSales}"),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildNoDataFoundUI() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No report data found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date filters or check back later',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String error) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'Error Loading Report',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => fetchSalesExecutiveReport(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
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

  TableCell _buildTableCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s9,
            0.13,
            Colors.black,
          ),
        ),
      ),
    );
  }
}
