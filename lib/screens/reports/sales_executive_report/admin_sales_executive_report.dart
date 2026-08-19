import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/sales_executive_report.dart';

import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

/// Admin-facing screen that shows sales reports for all sales executives.
class AdminSalesExecutiveReportScreen extends StatefulWidget {
  const AdminSalesExecutiveReportScreen({super.key});

  @override
  State<AdminSalesExecutiveReportScreen> createState() =>
      _AdminSalesExecutiveReportScreenState();
}

class _AdminSalesExecutiveReportScreenState
    extends State<AdminSalesExecutiveReportScreen> {
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  final TextEditingController nameFilterController = TextEditingController();

  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  bool _showFilters = true;

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 768;

  @override
  void dispose() {
    fromDateController.dispose();
    toDateController.dispose();
    nameFilterController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final role =
          Provider.of<RoleProvider>(context, listen: false).currentUserRole;
      if (role == 'sales_executive') {
        sideBarController.index.value = 58;
        return;
      }
      setState(() => _showFilters = !_isMobile(context));
      loadInitData();
    });
  }

  void loadInitData() async {
    try {
      if (mounted) {
        setState(() {
          initLoading = true;
        });
      }
      await fetchAdminSalesReport();
    } catch (error) {
      debugPrint('Error loading admin sales executive data: $error');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: '${'exec_report.error_loading_data'.tr}: $error',
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

  Future<void> fetchAdminSalesReport() async {
    if (!mounted) return;
    if (!_isDateRangeValid()) return;

    try {
      SalesExecutiveProvider provider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);

      String? fromDate;
      String? toDate;

      // Dates are directly available in YYYY-MM-DD HH:MM:SS format
      if (fromDateController.text.isNotEmpty) {
        fromDate = fromDateController.text;
      }

      if (toDateController.text.isNotEmpty) {
        toDate = toDateController.text;
      }

      final response = await provider.getAdminSalesExecutiveReport(
        context: context,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (!mounted) return;

      if (response != null && response['status'] == 'error') {
        showScaffoldError(
          context: context,
          message: response['message'] ?? 'exec_report.error_fetch_failed'.tr,
        );
      }
    } catch (error) {
      debugPrint('❌ Error fetching admin sales executive report: $error');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: '${'exec_report.error_fetching'.tr}: $error',
        );
      }
    }
  }

  bool _isDateRangeValid() {
    final from = DateTime.tryParse(fromDateController.text.trim());
    final to = DateTime.tryParse(toDateController.text.trim());
    if (from == null || to == null || !from.isAfter(to)) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('exec_report.error_date_range'.tr),
        backgroundColor: Colors.orange,
      ));
    return false;
  }

  void searchReport() => fetchAdminSalesReport();

  void resetSearch() {
    setState(() {
      fromDateController.clear();
      toDateController.clear();
      nameFilterController.clear();
    });
    Provider.of<SalesExecutiveProvider>(context, listen: false)
        .clearAdminReportData();
    fetchAdminSalesReport();
  }

  Future<void> _selectDateTime(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        final formattedDateTime =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
        setState(() {
          if (isFromDate) {
            fromDateController.text = formattedDateTime;
          } else {
            toDateController.text = formattedDateTime;
          }
        });
        searchReport();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => loadInitData(),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
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
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                if (_showFilters) _buildSearchBar(size),
                if (_showFilters) const SizedBox(height: 20),
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
        Expanded(
          child: Text(
            'exec_report.title'.tr,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                0.30, ColorManager.textColor),
          ),
        ),
        if (_isMobile(context))
          TextButton.icon(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              size: 18,
              color: ColorManager.kPrimaryColor,
            ),
            label: Text(
              _showFilters ? 'exec_report.btn_hide'.tr : 'exec_report.btn_filters'.tr,
              style: const TextStyle(
                  color: ColorManager.kPrimaryColor, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    if (_isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildFromDateFilter()),
              const SizedBox(width: 8),
              Expanded(child: _buildToDateFilter()),
            ],
          ),
          const SizedBox(height: 8),
          _buildNameFilter(),
          const SizedBox(height: 8),
          CustomRoundButton(
            title: 'general.reset'.tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: resetSearch,
            height: 45,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildFromDateFilter(),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildToDateFilter(),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildNameFilter(),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42),
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
            'exec_report.filter_from_date'.tr,
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
            onTap: () => _selectDateTime(context, isFromDate: true),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "YYYY-MM-DD HH:MM:SS",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.calendar_today,
                    size: 16, color: ColorManager.kPrimaryColor),
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
            'exec_report.filter_to_date'.tr,
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
            onTap: () => _selectDateTime(context, isFromDate: false),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "YYYY-MM-DD HH:MM:SS",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.calendar_today,
                    size: 16, color: ColorManager.kPrimaryColor),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'exec_report.filter_search_executive'.tr,
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
            controller: nameFilterController,
            onChanged: (_) => setState(() {}),
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: 'exec_report.filter_name_hint'.tr,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.search,
                    size: 16, color: ColorManager.kPrimaryColor),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileExecutiveCard(SalesExecutiveReportData report) {
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SelectableText(
                    report.name ?? 'exec_report.na'.tr,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s14, 0.20, ColorManager.textColor),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.visibility,
                      size: 18, color: ColorManager.kPrimaryColor),
                  onPressed: () => _showExecutiveDetails(report),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            SelectableText(
              report.phone ?? 'exec_report.na'.tr,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s12, 0.18, Colors.grey),
            ),
            const Divider(height: 16),
            Row(
              children: [
                _buildMobileCardStat(
                    'exec_report.card_orders'.tr, (report.orderCount ?? 0).toString()),
                _buildMobileCardStat(
                    'exec_report.card_total_sales'.tr, '$currency ${report.formattedTotalSales}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat(
                    'exec_report.card_cash_sales'.tr, '$currency ${report.formattedCashSales}'),
                _buildMobileCardStat(
                    'exec_report.card_online_sales'.tr, '$currency ${report.formattedOnlineSales}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMobileCardStat(
                    'exec_report.card_credit_sales'.tr, '$currency ${report.formattedCreditSales}'),
                _buildMobileCardStat(
                    'exec_report.card_collected'.tr, '$currency ${report.formattedCollectedSales}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s10, 0.15, Colors.grey)),
          Text(value,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.18, Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildExecutiveTable() {
    return Expanded(
      child:
          Consumer<SalesExecutiveProvider>(builder: (context, provider, child) {
        final isLoading = provider.isLoading || provider.isAdminReportLoading;
        final allReports = provider.adminSalesExecutiveReportList;
        final reportError = provider.adminReportError;

        // Client-side name filter
        final nameQuery = nameFilterController.text.trim().toLowerCase();
        final reportList = nameQuery.isEmpty
            ? allReports
            : allReports
                .where((r) => (r.name ?? '').toLowerCase().contains(nameQuery))
                .toList();

        if (isLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (_isMobile(context)) {
          return Column(
            children: [
              Expanded(
                child: reportError != null
                    ? _buildErrorUI(reportError)
                    : reportList.isEmpty
                        ? _buildNoDataFoundUI()
                        : ListView.builder(
                            itemCount: reportList.length,
                            itemBuilder: (ctx, i) =>
                                _buildMobileExecutiveCard(reportList[i]),
                          ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: BuildBoxShadowContainer(
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
                          0: FlexColumnWidth(2.0),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1.5),
                          5: FlexColumnWidth(1.5),
                          6: FlexColumnWidth(1.5),
                          7: FlexColumnWidth(1.5),
                          8: FlexColumnWidth(1.2),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildTableHeader('exec_report.header_exec_name'.tr),
                              _buildTableHeader('exec_report.header_phone'.tr),
                              _buildTableHeader('exec_report.header_total_orders'.tr),
                              _buildTableHeader('exec_report.card_total_sales'.tr),
                              _buildTableHeader('exec_report.card_online_sales'.tr),
                              _buildTableHeader('exec_report.card_cash_sales'.tr),
                              _buildTableHeader('exec_report.card_credit_sales'.tr),
                              _buildTableHeader('exec_report.card_collected_sales'.tr),
                              _buildTableHeader('exec_report.header_actions'.tr),
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
                          behavior: ScrollConfiguration.of(context).copyWith(
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
                                      physics: const BouncingScrollPhysics(),
                                      scrollDirection: Axis.vertical,
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(2.0),
                                          1: FlexColumnWidth(1.5),
                                          2: FlexColumnWidth(1.5),
                                          3: FlexColumnWidth(1.5),
                                          4: FlexColumnWidth(1.5),
                                          5: FlexColumnWidth(1.5),
                                          6: FlexColumnWidth(1.5),
                                          7: FlexColumnWidth(1.5),
                                          8: FlexColumnWidth(1.2),
                                        },
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: reportList.map((report) {
                                          return TableRow(
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                            ),
                                            children: [
                                              TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: SelectableText(
                                                    report.name ?? 'exec_report.na'.tr,
                                                    textAlign: TextAlign.center,
                                                    style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black),
                                                  ),
                                                ),
                                              ),
                                              TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: SelectableText(
                                                    report.phone ?? 'exec_report.na'.tr,
                                                    textAlign: TextAlign.center,
                                                    style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black),
                                                  ),
                                                ),
                                              ),
                                              _buildTableCell(report.orderCount
                                                      ?.toString() ??
                                                  "0"),
                                              _buildTableCell(
                                                  "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${report.formattedTotalSales}"),
                                              _buildTableCell(
                                                  "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${report.formattedOnlineSales}"),
                                              _buildTableCell(
                                                  "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${report.formattedCashSales}"),
                                              _buildTableCell(
                                                  "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${report.formattedCreditSales}"),
                                              _buildTableCell(
                                                  "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${report.formattedCollectedSales}"),
                                              _buildActionsCell(report),
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
          Icon(Icons.bar_chart_outlined,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.7)),
          const SizedBox(height: 15),
          Text(
            'exec_report.no_data'.tr,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s18,
                0.27, ColorManager.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'exec_report.no_data_hint'.tr,
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s14, 0.20, Colors.grey),
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
          Icon(Icons.error_outline,
              size: 60, color: Colors.red.withOpacity(0.7)),
          const SizedBox(height: 15),
          Text(
            'exec_report.error_title'.tr,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s18,
                0.27, ColorManager.textColor),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s14, 0.20, Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => fetchAdminSalesReport(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('exec_report.btn_retry'.tr),
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
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18,
            ColorManager.kPrimaryColor),
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
              FontWeightManager.medium, FontSize.s9, 0.13, Colors.black),
        ),
      ),
    );
  }

  TableCell _buildActionsCell(SalesExecutiveReportData report) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BuildBoxShadowContainer(
            margin: const EdgeInsets.only(left: 5, right: 5),
            circleRadius: 5,
            child: IconButton(
              icon: Icon(Icons.visibility,
                  size: 18, color: ColorManager.kPrimaryColor.withOpacity(0.9)),
              onPressed: () => _showExecutiveDetails(report),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  void _showExecutiveDetails(SalesExecutiveReportData report) {
    String dateRange;
    if (fromDateController.text.isNotEmpty &&
        toDateController.text.isNotEmpty) {
      dateRange = '${fromDateController.text} - ${toDateController.text}';
    } else if (fromDateController.text.isNotEmpty) {
      dateRange = fromDateController.text;
    } else if (toDateController.text.isNotEmpty) {
      dateRange = toDateController.text;
    } else {
      dateRange = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'exec_report.detail_title'.tr,
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, Colors.black),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(8)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                'exec_report.btn_back'.tr,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s14,
                                    0.20,
                                    Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildSection(
                          title: 'exec_report.section_exec_info'.tr,
                          children: [
                            _buildInfoRow(
                              _buildInfoItem('exec_report.info_name'.tr, report.name ?? 'exec_report.na'.tr),
                              _buildInfoItem('exec_report.info_phone'.tr, report.phone ?? 'exec_report.na'.tr),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              _buildInfoItem('exec_report.info_date_range'.tr, dateRange),
                              _buildInfoItem('exec_report.info_total_orders'.tr,
                                  (report.orderCount ?? 0).toString()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'exec_report.section_financial'.tr,
                          children: [
                            _buildFinancialItem('exec_report.card_total_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedTotalSales}'),
                            _buildFinancialItem('exec_report.card_online_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedOnlineSales}'),
                            _buildFinancialItem('exec_report.card_cash_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCashSales}'),
                            _buildFinancialItem('exec_report.card_credit_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCreditSales}'),
                            _buildFinancialItem('exec_report.card_collected_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCollectedSales}'),
                            _buildFinancialItem('exec_report.card_upi_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedUpiSales}'),
                            _buildFinancialItem('exec_report.card_card_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCardSales}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
                  0.24, Colors.black)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(Widget item1, Widget item2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: item1),
        const SizedBox(width: 16),
        Expanded(child: item2),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: buildCustomStyle(
                FontWeightManager.medium, FontSize.s12, 0.18, Colors.black87)),
        const SizedBox(height: 4),
        Text(value,
            style: buildCustomStyle(
                FontWeightManager.semiBold, FontSize.s14, 0.20, Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildFinancialItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                    0.18, Colors.black87)),
          ),
          const SizedBox(width: 16),
          Text(value,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.20, Colors.black)),
        ],
      ),
    );
  }
}
