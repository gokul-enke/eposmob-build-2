import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
// Use TransactionProvider instead of CustomerTransactionProvider
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'dart:ui';

// Import the new simple transaction details screen
import 'simple_transaction_details_screen.dart';

class CustomerTransactionsReportScreen extends StatefulWidget {
  const CustomerTransactionsReportScreen({super.key});

  @override
  State<CustomerTransactionsReportScreen> createState() =>
      _CustomerTransactionsReportScreenState();
}

class _CustomerTransactionsReportScreenState
    extends State<CustomerTransactionsReportScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? allTransactions = [];

  // For grouping customer transactions
  Map<String, CustomerTransactionSummary> customerSummary = {};

  @override
  void initState() {
    super.initState();
    loadInitData();
  }

  Future<void> loadInitData() async {
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      final value = await invoiceProvider.listAllTransaction(
        type: null,
        accessToken: accessToken ?? "",
      );

      if (value['status'] == 'success') {
        ListTransactionModel listTransactionModel =
            ListTransactionModel.fromJson(value);
        allTransactions = listTransactionModel.data?.transactions ?? [];
        calculateCustomerSummary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load transaction data"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('Error loading transaction data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading transaction data: $error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void calculateCustomerSummary() {
    customerSummary.clear();

    if (allTransactions == null) return;

    for (var transaction in allTransactions!) {
      String customerName = transaction.customerName ?? 'Unknown Customer';
      double amount = double.tryParse(transaction.amount ?? '0') ?? 0.0;
      String type = transaction.type ?? 'unknown';

      if (!customerSummary.containsKey(customerName)) {
        customerSummary[customerName] = CustomerTransactionSummary(
          customerName: customerName,
          totalDebit: 0.0,
          totalCredit: 0.0,
        );
      }

      // Assuming "Credit" type increases balance and "Debit" type decreases balance
      if (transaction.type?.toLowerCase() == 'credit') {
        customerSummary[customerName]!.totalCredit += amount;
      } else if (transaction.type?.toLowerCase() == 'debit') {
        customerSummary[customerName]!.totalDebit += amount;
      }
    }

    // Calculate balance for each customer
    customerSummary.forEach((name, summary) {
      summary.balance = summary.totalCredit - summary.totalDebit;
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
                const SizedBox(height: 20),
                _buildReportTable(),
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
          "Customer Transactions Report",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        CustomRoundButton(
          title: "Back",
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: () {
            sideBarController.index.value = 62; // Navigate back to Settings
          },
          height: 40,
          width: 80,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }

  Widget _buildReportTable() {
    return Expanded(
      child: initLoading
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
                        0: FlexColumnWidth(2.0), // Customer Name
                        1: FlexColumnWidth(1.5), // Total Debit
                        2: FlexColumnWidth(1.5), // Total Credit
                        3: FlexColumnWidth(1.5), // Balance
                        4: FlexColumnWidth(1.0), // Action
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildTableHeader("Customer Name"),
                            _buildTableHeader("Total Debit"),
                            _buildTableHeader("Total Credit"),
                            _buildTableHeader("Balance"),
                            _buildTableHeader("Action"),
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
                        child: customerSummary.isEmpty
                            ? _buildNoDataFoundUI()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.0), // Customer Name
                                    1: FlexColumnWidth(1.5), // Total Debit
                                    2: FlexColumnWidth(1.5), // Total Credit
                                    3: FlexColumnWidth(1.5), // Balance
                                    4: FlexColumnWidth(1.0), // Action
                                  },
                                  border: null,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: customerSummary.entries
                                      .map((entry) => _buildCustomerRow(
                                          entry.value, context))
                                      .toList(),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            Icons.account_balance,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No customer transactions available',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try refreshing the data',
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

  TableRow _buildCustomerRow(
      CustomerTransactionSummary summary, BuildContext context) {
    // Alternate row colors for better readability
    final int index =
        customerSummary.keys.toList().indexOf(summary.customerName);

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _buildTableCell(summary.customerName),
        _buildTableCell(
          summary.totalDebit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.totalCredit.toStringAsFixed(2),
        ),
        _buildTableCell(
          summary.balance.toStringAsFixed(2),
          isBalance: true,
          balance: summary.balance,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: BuildBoxShadowContainer(
              margin: const EdgeInsets.only(left: 5, right: 5),
              circleRadius: 5,
              child: IconButton(
                icon: Icon(
                  Icons.visibility,
                  size: 18,
                  color: ColorManager.kPrimaryColor.withOpacity(0.9),
                ),
                onPressed: () {
                  // Use the TransactionProvider instead of the CustomerTransactionProvider
                  Provider.of<TransactionProvider>(context, listen: false)
                      .setCustomerName(summary.customerName);
                  sideBarController.index.value =
                      66; // Navigate to SimpleTransactionDetailsScreen
                },
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String content,
      {bool isBalance = false, double? balance}) {
    Color textColor = Colors.black;
    if (isBalance && balance != null) {
      textColor = balance < 0 ? Colors.red : Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        content,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          textColor,
        ),
      ),
    );
  }
}

class CustomerTransactionSummary {
  final String customerName;
  double totalDebit;
  double totalCredit;
  double balance;

  CustomerTransactionSummary({
    required this.customerName,
    required this.totalDebit,
    required this.totalCredit,
    this.balance = 0.0,
  });
}
