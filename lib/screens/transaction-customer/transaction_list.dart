import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class CustomerTransactionListScreen extends StatefulWidget {
  const CustomerTransactionListScreen({super.key});

  @override
  State<CustomerTransactionListScreen> createState() =>
      _CustomerTransactionListScreenState();
}

class _CustomerTransactionListScreenState
    extends State<CustomerTransactionListScreen> {
  final TextEditingController amountRefController = TextEditingController();
  final SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? listTransaction = [];
  String searchAmount = '';
  DateTime? selectedDate;

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
        listTransaction = listTransactionModel.data?.transactions ?? [];
      } else {
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  Future<void> searchTransactions(int page) async {
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
        listTransaction = listTransactionModel.data?.transactions ?? [];
      } else {
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      amountRefController.clear();
      searchAmount = '';
      selectedDate = null;
    });
  }

  Future<void> refreshData() async {
    resetSearch();
    loadInitData();
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
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    InvoiceProvider invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final bool isSmallScreen = size.width < 600;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Transaction Management",
                      style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                          0.30, ColorManager.textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: isSmallScreen
                                ? size.width * 0.8
                                : size.width * 0.15,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Amount ",
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                buildColumnWidgetForTextFields(
                                  height: 45,
                                  width: isSmallScreen
                                      ? size.width * 0.8
                                      : size.width * 0.15,
                                  onchanged: (value) {
                                    setState(() {
                                      searchAmount = value!;
                                    });
                                  },
                                  controller: amountRefController,
                                  size: size,
                                  hintText: 'Amount',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: isSmallScreen
                                ? size.width * 0.8
                                : size.width * 0.15,
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
                                  width: isSmallScreen
                                      ? size.width * 0.8
                                      : size.width * 0.15,
                                  child: Center(
                                    child: CalendarPickerTableCell(
                                      onDateSelected: (DateTime date) {
                                        selectedDate = date;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomRoundButton(
                            title: "Search",
                            fct: searchTransactions,
                            height: 45,
                            width: isSmallScreen
                                ? size.width * 0.4
                                : size.width * 0.09,
                            fontSize: FontSize.s12,
                          ),
                          CustomRoundButton(
                            title: "Reset",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: resetSearch,
                            height: 45,
                            width: isSmallScreen
                                ? size.width * 0.4
                                : size.width * 0.09,
                            fontSize: FontSize.s12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: initLoading
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
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
                                          0: FlexColumnWidth(0.5), // No
                                          1: FlexColumnWidth(2.0), // Name
                                          2: FlexColumnWidth(1.0), // Type
                                          3: FlexColumnWidth(1.5), // Amount
                                          4: FlexColumnWidth(1.0), // Status
                                          5: FlexColumnWidth(1.0), // Action
                                        },
                                        border: null,
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            children: [
                                              _buildTableHeader('No'),
                                              _buildTableHeader('Name'),
                                              _buildTableHeader('Type'),
                                              _buildTableHeader('Amount'),
                                              _buildTableHeader('Status'),
                                              _buildTableHeader('Action'),
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
                                              ScrollConfiguration.of(context)
                                                  .copyWith(
                                            dragDevices: {
                                              PointerDeviceKind.mouse,
                                              PointerDeviceKind.touch,
                                              PointerDeviceKind.stylus,
                                              PointerDeviceKind.trackpad,
                                            },
                                          ),
                                          child: SingleChildScrollView(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            scrollDirection: Axis.vertical,
                                            child: Table(
                                              columnWidths: const {
                                                0: FlexColumnWidth(0.5), // No
                                                1: FlexColumnWidth(2.0), // Name
                                                2: FlexColumnWidth(1.0), // Type
                                                3: FlexColumnWidth(1.5), // Amount
                                                4: FlexColumnWidth(1.0), // Status
                                                5: FlexColumnWidth(1.0), // Action
                                              },
                                              border: null,
                                              defaultVerticalAlignment:
                                                  TableCellVerticalAlignment.middle,
                                              children: [
                                                // Table Rows
                                                ...listTransaction!
                                                    .where((transaction) {
                                                  return transaction.amount!
                                                      .contains(searchAmount);
                                                })
                                                    .toList()
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                  final int index = entry.key;
                                                  final transaction = entry.value;
                                                  return TableRow(
                                                    decoration: BoxDecoration(
                                                      color: index % 2 == 0
                                                          ? Colors.white
                                                          : Colors.grey
                                                              .withOpacity(0.1),
                                                    ),
                                                    children: [
                                                      _buildTableCell(
                                                          '${index + 1}'),
                                                      _buildTableCell("Name"),
                                                      _buildTableCell(
                                                          "${transaction.type}"),
                                                      _buildTableCell(
                                                          "${transaction.currency} ${transaction.amount}"),
                                                      _buildTableCell(
                                                          "${transaction.status}"),
                                                      Center(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  8.0),
                                                          child:
                                                              BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                        .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.visibility,
                                                                size: 18,
                                                                color: ColorManager
                                                                    .kPrimaryColor
                                                                    .withOpacity(
                                                                        0.9),
                                                              ),
                                                              onPressed: () {
                                                                invoiceProvider
                                                                    .callDetailsOfTransaction(
                                                                  id: transaction
                                                                          .id ??
                                                                      0,
                                                                  accessToken:
                                                                      token ?? "",
                                                                );
                                                                sideBarController
                                                                    .index
                                                                    .value = 30;
                                                              },
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 36,
                                                                minHeight: 36,
                                                              ),
                                                              padding:
                                                                  EdgeInsets.zero,
                                                            ),
                                                          ),
                                                        ),
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
                              ),
                      ),
                      const SizedBox(height: 10),
                      PaginationControl(
                        currentPage: invoiceProvider.currentPage,
                        totalPages: invoiceProvider.totalPages,
                        onPageChanged: (int page) {
                          searchTransactions(page);
                        },
                      ),
                    ],
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
