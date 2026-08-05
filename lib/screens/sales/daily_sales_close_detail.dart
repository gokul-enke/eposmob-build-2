import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print_daily_close.dart';
import 'package:pos_machine/screens/print/daily_close_standard_printer.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/responsive.dart';

class DailySalesCloseDetailScreen extends StatefulWidget {
  const DailySalesCloseDetailScreen({super.key});

  @override
  State<DailySalesCloseDetailScreen> createState() => _DailySalesCloseDetailScreenState();
}

class _DailySalesCloseDetailScreenState extends State<DailySalesCloseDetailScreen> {
  final SideBarController sideBarController = Get.find();
  final TextEditingController _orderNumberController = TextEditingController();
  String _paymentTypeFilter = 'All';
  List<DailySalesTransaction> _filteredTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _orderNumberController.addListener(_filterTransactions);
  }

  Future<void> _fetchDetails() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final basicData = salesProvider.selectedDailySalesCloseData;
    
    if (basicData != null && basicData.id != null) {
      try {
        final detailData = await salesProvider.fetchDailySalesCloseDetail(
          accessToken: authModel.token ?? '',
          id: basicData.id!,
        );
        if (detailData != null) {
          debugPrint('transactions count: ${detailData.transactions?.length}');
          salesProvider.setSelectedDailySalesCloseData(detailData);
          if (mounted) {
            setState(() {
              _filteredTransactions = List.from(detailData.transactions ?? []);
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Error fetching day close details: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    super.dispose();
  }

  void _filterTransactions() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final data = salesProvider.selectedDailySalesCloseData;
    
    if (data == null || data.transactions == null) return;

    final orderNumberQuery = _orderNumberController.text.toLowerCase();
    
    setState(() {
      _filteredTransactions = data.transactions!.where((tx) {
        final matchesOrderNumber = orderNumberQuery.isEmpty || 
            (tx.orderNumber?.toLowerCase().contains(orderNumberQuery) ?? false);
        
        final matchesPaymentType = _paymentTypeFilter == 'All' || 
            (tx.paymentType?.toUpperCase() == _paymentTypeFilter.toUpperCase());

        return matchesOrderNumber && matchesPaymentType;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _orderNumberController.clear();
      _paymentTypeFilter = 'All';
      _filterTransactions();
    });
  }

  String _getLocalizedAction(String action) {
    if (action.toLowerCase() == 'print') {
      return 'general.print'.tr;
    } else if (action.toLowerCase() == 'export') {
      return 'daily_sales_close.export'.tr;
    }
    return action;
  }

  Future<bool?> _askIncludeTransactions({String action = 'Print'}) async {
    final localizedAction = _getLocalizedAction(action);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('daily_sales_close.confirm_action_title'.tr.replaceAll('@action', localizedAction)),
          content: Text(
            'daily_sales_close.confirm_action_body'.tr.replaceAll('@action', localizedAction),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('daily_sales_close.cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('daily_sales_close.no'.tr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('daily_sales_close.yes'.tr),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePrint(DailySalesCloseData data) async {
    final includeTransactions = await _askIncludeTransactions(action: 'Print');
    if (includeTransactions == null) {
      return;
    }

    final autoPrinted = await DailyClosePrintPage.autoPrint(
      context,
      data: data,
      includeTransactions: includeTransactions,
    );

    if (autoPrinted) {
      if (!mounted) return;
      showScaffold(
        context: context,
        message: 'daily_sales_close.msg_print_success'.tr,
      );
      return;
    }

    if (!mounted) return;
    Get.to(() => DailyClosePrintPage(data: data));
  }

  Future<void> _handleExport(DailySalesCloseData data) async {
    final includeTransactions = await _askIncludeTransactions(action: 'Export');
    if (includeTransactions == null) return;

    await DailyCloseStandardPrinter(context).generateAndShareDailyClosePDF(
      data: data,
      selectedPaperSize: 'A4',
      includeTransactions: includeTransactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final data = salesProvider.selectedDailySalesCloseData;
    Size size = MediaQuery.of(context).size;

    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data == null) {
      return Center(child: Text("daily_sales_close.no_data_selected".tr));
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: CustomBoxShadowContainer(
          circleRadius: 22,
          margin: const EdgeInsets.all(10.0),
          padding: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                Text(
                  'daily_sales_close.detail_title'.tr.replaceAll('@period', data.closingPeriod ?? ""),
                  style: ResponsiveWidget.isMobile(context)
                      ? buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.30, ColorManager.textColor)
                      : buildCustomStyle(FontWeightManager.semiBold, FontSize.s20, 0.30, ColorManager.textColor),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('daily_sales_close.closing_period_details'.tr, Icons.calendar_today),
                const SizedBox(height: 10),
                _buildClosingPeriodDetails(data),
                const SizedBox(height: 20),
                _buildSalesSummary(context, data),
                const SizedBox(height: 20),
                _buildSectionHeader('daily_sales_close.expenses_breakdown'.tr, Icons.receipt_long_outlined),
                const SizedBox(height: 10),
                _buildExpensesBreakdown(data),
                const SizedBox(height: 20),
                if (data.cashSummary != null) ...[
                  _buildSectionHeader('daily_sales_close.cash_summary'.tr, Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 10),
                  _buildCashSummary(context, data.cashSummary!),
                  const SizedBox(height: 20),
                  _buildSectionHeader('daily_sales_close.cash_denomination_breakdown'.tr, Icons.payments_outlined),
                  const SizedBox(height: 10),
                  _buildCashBreakdownSection(context, data.cashSummary!),
                  const SizedBox(height: 20),
                ],
                _buildSectionHeader('daily_sales_close.key_fields'.tr, Icons.info_outline),
                const SizedBox(height: 10),
                _buildKeyFields(data),
                const SizedBox(height: 20),
                _buildSectionHeader('daily_sales_close.closing_range_details'.tr, Icons.access_time),
                const SizedBox(height: 10),
                _buildClosingRangeDetails(data),
                const SizedBox(height: 20),
                _buildSectionHeader('daily_sales_close.transaction_details'.tr, Icons.receipt_long),
                const SizedBox(height: 10),
                _buildTransactionDetails(context, size),
                const SizedBox(height: 20),
                _buildActionButtons(size, data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            sideBarController.index.value =
                Provider.of<SalesProvider>(context, listen: false).returnIndex;
          },
          text: 'daily_sales_close.back_to_list'.tr,
        ),
        CustomBoxShadowContainer(
          width: 30,
          height: 30,
          circleRadius: 15,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              sideBarController.index.value =
                  Provider.of<SalesProvider>(context, listen: false).returnIndex;
            },
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s16,
            0.18,
            Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return CustomBoxShadowContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      border: Border.all(color: Colors.grey.shade200),
      child: child,
    );
  }

  Widget _buildClosingPeriodDetails(DailySalesCloseData data) {
    return _buildCard(
      child: Column(
        children: [
          _buildDetailRow('daily_sales_close.closing'.tr, data.closingPeriod ?? '-', isHighlight: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('daily_sales_close.sales_executive'.tr, data.salesExecutive?.name ?? '-')),
              Expanded(child: _buildDetailItem('daily_sales_close.store'.tr, data.store?.name ?? '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('daily_sales_close.phone'.tr, data.salesExecutive?.phone ?? '-')),
              const Expanded(child: SizedBox()), // Spacer
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummary(BuildContext context, DailySalesCloseData data) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        // Build payment breakdown rows dynamically
        final List<Widget> breakdownRows = [];
        final breakdown = data.paymentMethodBreakdown ?? {
          'BANK': '0.00',
          'CARD': '0.00',
          'CASH': '0.00',
          'COD': '0.00',
          'ONLINE': '0.00',
          'UPI': '0.00',
          'CHEQUE': '0.00',
          'CREDIT': '0.00',
        };

        String formatKey(String key) {
          final upper = key.toUpperCase();
          if (upper == 'COD' || upper == 'UPI') {
            return upper;
          }
          if (key.isEmpty) return '';
          return key[0].toUpperCase() + key.substring(1).toLowerCase();
        }

        final entries = breakdown.entries.toList();
        for (int i = 0; i < entries.length; i += 2) {
          final entry1 = entries[i];
          final hasSecond = i + 1 < entries.length;
          final entry2 = hasSecond ? entries[i + 1] : null;

          breakdownRows.add(
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    formatKey(entry1.key),
                    '$currency ${entry1.value ?? '0.00'}',
                  ),
                ),
                if (entry2 != null)
                  Expanded(
                    child: _buildDetailItem(
                      formatKey(entry2.key),
                      '$currency ${entry2.value ?? '0.00'}',
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
          if (i + 2 < entries.length) {
            breakdownRows.add(const SizedBox(height: 20));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('daily_sales_close.day_close_summary'.tr, Icons.summarize_outlined),
            const SizedBox(height: 10),
            _buildCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('daily_sales_close.total_orders'.tr, data.totalOrders?.toString() ?? '0', isValueBold: true)),
                      Expanded(child: _buildDetailItem('daily_sales_close.total_sales'.tr, '$currency ${data.totalSales ?? '0.00'}', valueColor: ColorManager.kSuccessColor, isValueBold: true)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('daily_sales_close.total_payment_received'.tr, '$currency ${data.totalPaymentReceived ?? '0.00'}', isValueBold: true)),
                      Expanded(child: _buildDetailItem('daily_sales_close.total_amount_collected_on_sale'.tr, '$currency ${data.totalAmountCollectedOnSale ?? '0.00'}')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('daily_sales_close.total_credit_collected_prev'.tr, '$currency ${data.totalCreditCollected ?? '0.00'}')),
                      Expanded(child: _buildDetailItem('daily_sales_close.business_date'.tr, data.businessDate ?? data.openingDate ?? '-')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('daily_sales_close.collection_summary'.tr, Icons.payments_outlined),
            const SizedBox(height: 10),
            _buildCard(
              child: Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.total_cash_sales'.tr, '$currency ${data.totalCash ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.total_online_sales'.tr, '$currency ${data.totalOnline ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.total_credit_amount'.tr, '$currency ${data.totalCredit ?? '0.00'}')),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('daily_sales_close.return_refund'.tr, Icons.assignment_return_outlined),
            const SizedBox(height: 10),
            _buildCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('daily_sales_close.total_returns_sales_return'.tr, '$currency ${data.totalReturns ?? '0.00'}', valueColor: Colors.red)),
                      Expanded(child: _buildDetailItem('daily_sales_close.total_refunds_vouchers'.tr, '$currency ${data.totalRefunds ?? '0.00'}', valueColor: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDetailItem('daily_sales_close.refund_cash'.tr, '$currency ${data.refundCash ?? '0.00'}', valueColor: Colors.red)),
                      Expanded(child: _buildDetailItem('daily_sales_close.refund_online'.tr, '$currency ${data.refundOnline ?? '0.00'}', valueColor: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('daily_sales_close.payment_method_breakdown'.tr, Icons.list_alt_outlined),
            const SizedBox(height: 10),
            _buildCard(
              child: Column(
                children: breakdownRows,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClosingRangeDetails(DailySalesCloseData data) {
    return _buildCard(
      child: Row(
        children: [
          Expanded(child: _buildDetailItem('daily_sales_close.opening_date'.tr, data.openingDate ?? '-')),
          Expanded(child: _buildDetailItem('daily_sales_close.opening_time'.tr, data.openingTime ?? '-')),
          Expanded(child: _buildDetailItem('daily_sales_close.closing_date'.tr, data.closingDate ?? '-')),
          Expanded(child: _buildDetailItem('daily_sales_close.closing_time'.tr, data.closingTime ?? '-')),
        ],
      ),
    );
  }

  Widget _buildExpensesBreakdown(DailySalesCloseData data) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
        return _buildCard(
          child: Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'daily_sales_close.cash_expenses'.tr,
                  '$currency ${data.cashExpenses ?? '0.00'}',
                  valueColor: Colors.red,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'daily_sales_close.bank_expenses'.tr,
                  '$currency ${data.bankExpenses ?? '0.00'}',
                  valueColor: Colors.red,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'daily_sales_close.total_expense'.tr,
                  '$currency ${data.totalExpenses ?? '0.00'}',
                  valueColor: Colors.red,
                  isValueBold: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashSummary(BuildContext context, CashSummary cashSummary) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
        return _buildCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.sales_count'.tr, cashSummary.totalSalesCount?.toString() ?? '0', isValueBold: true)),
                  Expanded(child: _buildDetailItem('daily_sales_close.sales_amount'.tr, '$currency ${cashSummary.totalSalesAmount ?? '0.00'}', isValueBold: true)),
                  Expanded(child: _buildDetailItem('daily_sales_close.cash_collected'.tr, '$currency ${cashSummary.cashCollected ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.online_collected'.tr, '$currency ${cashSummary.onlineCollected ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.credit_amount'.tr, '$currency ${cashSummary.creditAmount ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.previous_balance_collected'.tr, '$currency ${cashSummary.previousBalanceCollected ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.cash_refunds'.tr, '$currency ${cashSummary.cashRefunds ?? '0.00'}', valueColor: Colors.red)),
                  Expanded(child: _buildDetailItem('daily_sales_close.cash_expenses'.tr, '$currency ${cashSummary.cashExpenses ?? '0.00'}', valueColor: Colors.red)),
                  Expanded(child: _buildDetailItem('daily_sales_close.cash_drop_amount'.tr, '$currency ${cashSummary.cashDropAmount ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.opening_cash_in_hand'.tr, '$currency ${cashSummary.openingCashInHand ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.expected_closing_cash'.tr, '$currency ${cashSummary.expectedClosingCash ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('daily_sales_close.closing_cash_in_hand'.tr, '$currency ${cashSummary.closingCashInHand ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('daily_sales_close.short_cash'.tr, '$currency ${cashSummary.shortCash ?? '0.00'}', valueColor: Colors.red)),
                  Expanded(child: _buildDetailItem('daily_sales_close.excess_cash'.tr, '$currency ${cashSummary.excessCash ?? '0.00'}', valueColor: ColorManager.kSuccessColor)),
                  Expanded(child: _buildDetailItem('daily_sales_close.notes'.tr, cashSummary.notes ?? '-')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashBreakdownSection(BuildContext context, CashSummary cashSummary) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
        return Column(
          children: [
            _buildBreakdownCard(
              title: 'daily_sales_close.opening_cash_breakdown'.tr,
              subtitle: 'daily_sales_close.saved_denomination_details'.tr,
              rows: cashSummary.openingCashBreakdown,
              currency: currency,
            ),
            const SizedBox(height: 14),
            _buildBreakdownCard(
              title: 'daily_sales_close.closing_cash_breakdown'.tr,
              subtitle: 'daily_sales_close.saved_denomination_details'.tr,
              rows: cashSummary.closingCashBreakdown,
              currency: currency,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required String subtitle,
    required List<dynamic>? rows,
    required String currency,
  }) {
    final normalizedRows = rows
        ?.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList() ??
        [];

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          if (normalizedRows.isEmpty)
            Text(
              'daily_sales_close.no_denominations_available'.tr,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                columns: [
                  DataColumn(label: Text('daily_sales_close.denomination'.tr)),
                  DataColumn(label: Text('daily_sales_close.count'.tr)),
                  DataColumn(label: Text('daily_sales_close.total_col'.tr)),
                ],
                rows: normalizedRows.map((row) {
                  final denomination = row['denomination']?.toString() ?? '-';
                  final countText = row['count']?.toString() ?? '0';
                  final count = int.tryParse(countText) ?? 0;
                  final denominationValue = num.tryParse(denomination) ?? 0;
                  final total = denominationValue * count;
                  return DataRow(
                    cells: [
                      DataCell(Text(denomination)),
                      DataCell(Text(count.toString())),
                      DataCell(Text('$currency ${total.toStringAsFixed(2)}')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyFields(DailySalesCloseData data) {
    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDetailItem('daily_sales_close.shift_name'.tr, data.shiftName ?? '-')),
              Expanded(child: _buildDetailItem('daily_sales_close.business_date'.tr, data.businessDate ?? '-')),
              Expanded(child: _buildDetailItem('daily_sales_close.credit_collected'.tr, data.totalCreditCollected ?? '0.00', valueColor: ColorManager.kSuccessColor, isValueBold: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails(BuildContext context, Size size) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: CustomMinimalTextField(
                    size: size,
                    controller: _orderNumberController,
                    title: 'daily_sales_close.order_number'.tr,
                    hintText: 'daily_sales_close.enter_order_number'.tr,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CustomDropDownWithSearch<String>(
                    title: 'daily_sales_close.payment_type'.tr,
                    hintText: 'common.all'.tr,
                    value: _paymentTypeFilter,
                    items: const [
                      'All',
                      'CREDIT',
                      'RETURN',
                      'REFUND',
                      'ONLINE',
                      'UPI',
                      'CARD',
                      'CASH'
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _paymentTypeFilter = val;
                          _filterTransactions();
                        });
                      }
                    },
                    displayText: (item) => item == 'All' ? 'common.all'.tr : item,
                    height: size.height * 0.048, // Match minimal text field height
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: _resetFilters,
                    child: Text('general.reset'.tr, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
                return DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                  columns: [
                    DataColumn(label: Text('daily_sales_close.sl_no'.tr)),
                    DataColumn(label: Text('daily_sales_close.customer'.tr)),
                    DataColumn(label: Text('daily_sales_close.order_no'.tr)),
                    DataColumn(label: Text('daily_sales_close.order_amount'.tr)),
                    DataColumn(label: Text('daily_sales_close.paid_amount'.tr)),
                    DataColumn(label: Text('daily_sales_close.payment_type'.tr)),
                    DataColumn(label: Text('daily_sales_close.date'.tr)),
                    DataColumn(label: Text('daily_sales_close.time'.tr)),
                  ],
                  rows: _filteredTransactions.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final tx = entry.value;
                    return DataRow(cells: [
                      DataCell(Text(index.toString())),
                      DataCell(Text(tx.customerName ?? '-')),
                      DataCell(Text(tx.orderNumber ?? '-')),
                      DataCell(Text('$currency ${tx.orderAmount ?? 0}')),
                      DataCell(Text(
                        '$currency ${tx.paidAmount ?? 0}',
                        style: const TextStyle(color: ColorManager.kSuccessColor, fontWeight: FontWeight.bold),
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(tx.paymentType ?? '-', style: const TextStyle(fontSize: 12)),
                      )),
                      DataCell(Text(tx.date ?? '-')),
                      DataCell(Text(tx.time ?? '-')),
                    ]);
                  }).toList(),
                );
              },
            ),
          ),
          if (_filteredTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('daily_sales_close.no_transactions_found'.tr)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor, bool isValueBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontSize: 14,
            fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        if (isHighlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorManager.kSuccessColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: ColorManager.kSuccessColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(Size size, DailySalesCloseData data) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          CustomRoundButton(
            title: "general.print".tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: () {
              _handlePrint(data);
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
          CustomRoundButton(
            title: "daily_sales_close.export".tr,
            boxColor: ColorManager.kPrimaryColor,
            textColor: Colors.white,
            fct: () {
              _handleExport(data);
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }
}

