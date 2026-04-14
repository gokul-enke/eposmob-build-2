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
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize filtered transactions with all transactions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final data = salesProvider.selectedDailySalesCloseData;
      if (data != null && data.transactions != null) {
        setState(() {
          _filteredTransactions = List.from(data.transactions!);
        });
      }
    });
    
    _orderNumberController.addListener(_filterTransactions);
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

  Future<bool?> _askIncludeTransactions() async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Print Transaction List?'),
          content: const Text(
            'Do you want to include transaction details in this print?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePrint(DailySalesCloseData data) async {
    final includeTransactions = await _askIncludeTransactions();
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
        message: 'Daily Close Report printed successfully!',
      );
      return;
    }

    if (!mounted) return;
    Get.to(() => DailyClosePrintPage(data: data));
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final data = salesProvider.selectedDailySalesCloseData;
    Size size = MediaQuery.of(context).size;

    if (data == null) {
      return const Center(child: Text("No data selected"));
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
                  'Daily Sales Close - ${data.closingPeriod ?? ""}',
                  style: ResponsiveWidget.isMobile(context)
                      ? buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.30, ColorManager.textColor)
                      : buildCustomStyle(FontWeightManager.semiBold, FontSize.s20, 0.30, ColorManager.textColor),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Closing Period Details', Icons.calendar_today),
                const SizedBox(height: 10),
                _buildClosingPeriodDetails(data),
                const SizedBox(height: 20),
                _buildSectionHeader('Sales Summary', Icons.monetization_on_outlined),
                const SizedBox(height: 10),
                _buildSalesSummary(context, data),
                const SizedBox(height: 20),
                _buildSectionHeader('Closing Range Details', Icons.access_time),
                const SizedBox(height: 10),
                _buildClosingRangeDetails(data),
                const SizedBox(height: 20),
                _buildSectionHeader('Transaction Details', Icons.receipt_long),
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
          text: 'Back to List',
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
          _buildDetailRow('Closing Period', data.closingPeriod ?? '-', isHighlight: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Sales Executive', data.salesExecutive?.name ?? '-')),
              Expanded(child: _buildDetailItem('Store', data.store?.name ?? '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailItem('Phone', data.salesExecutive?.phone ?? '-')),
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
        return _buildCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildDetailItem('Total Orders', data.totalOrders?.toString() ?? '0', isValueBold: true)),
                  Expanded(child: _buildDetailItem('Total Sales', '$currency ${data.totalSales ?? '0.00'}', valueColor: ColorManager.kSuccessColor, isValueBold: true)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('Total Payment Received', '$currency ${data.totalPaymentReceived ?? '0.00'}', isValueBold: true)),
                  Expanded(child: _buildDetailItem('Total Amount Collected On Sale', '$currency ${data.totalAmountCollectedOnSale ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('Total Credit Collected (Prev Balance)', '$currency ${data.totalCreditCollected ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('Total Online Sales', '$currency ${data.totalOnline ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('Total Cash Sales', '$currency ${data.totalCash ?? '0.00'}')),
                  Expanded(child: _buildDetailItem('Total Credit Amount', '$currency ${data.totalCredit ?? '0.00'}')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailItem('Total Returns (Sales Return)', '$currency ${data.totalReturns ?? '0.00'}', valueColor: Colors.red)),
                  Expanded(child: _buildDetailItem('Total Refunds (Vouchers)', '$currency ${data.totalRefunds ?? '0.00'}', valueColor: Colors.red)),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClosingRangeDetails(DailySalesCloseData data) {
    return _buildCard(
      child: Row(
        children: [
          Expanded(child: _buildDetailItem('Opening Date', data.openingDate ?? '-')),
          Expanded(child: _buildDetailItem('Opening Time', data.openingTime ?? '-')),
          Expanded(child: _buildDetailItem('Closing Date', data.closingDate ?? '-')),
          Expanded(child: _buildDetailItem('Closing Time', data.closingTime ?? '-')),
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
                    title: 'Order Number',
                    hintText: 'Enter Order Number',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: CustomDropDownWithSearch<String>(
                    title: 'Payment Type',
                    hintText: 'All',
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
                    displayText: (item) => item,
                    height: size.height * 0.048, // Match minimal text field height
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset', style: TextStyle(color: Colors.red)),
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
                  columns: const [
                    DataColumn(label: Text('SL No')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Order No')),
                    DataColumn(label: Text('Order Amount')),
                    DataColumn(label: Text('Paid Amount')),
                    DataColumn(label: Text('Payment Type')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Time')),
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No transactions found')),
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
            title: "Print",
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: () {
              _handlePrint(data);
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

