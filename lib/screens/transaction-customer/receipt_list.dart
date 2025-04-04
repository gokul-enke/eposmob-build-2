import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  bool initLoading = false;
  List<Receipt>? receiptList = [];
  ReceiptData? receiptData;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    debugPrint("📌 loadInitData started");
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("📌 Access token length: ${accessToken?.length ?? 0}");

      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      debugPrint("📌 Calling invoiceProvider.listAllReceipts");
      final value = await invoiceProvider.listAllReceipts(
          accessToken: accessToken ?? "", page: 1);

      debugPrint(
          "📌 API response received: ${value != null ? 'not null' : 'null'}");

      if (value != null && value['status'] == 'success') {
        debugPrint("📌 Response status: success");
        ReceiptResponse receiptResponse = ReceiptResponse.fromJson(value);
        setState(() {
          receiptData = receiptResponse.data;
          receiptList = receiptResponse.data.data;
          debugPrint("📌 Loaded ${receiptList?.length ?? 0} receipts");
        });
      } else {
        debugPrint("📌 Response status: not success, value: $value");
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error) {
      debugPrint("❌ Receipt listing error: ${error.toString()}");
      showScaffold(context: context, message: "Error fetching receipts");
    } finally {
      setState(() {
        initLoading = false;
      });
      debugPrint("📌 loadInitData finished");
    }
  }

  Future<void> searchReceipts(int page) async {
    debugPrint("📌 searchReceipts started with page: $page");
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      debugPrint("📌 Calling invoiceProvider.listAllReceipts");
      final value = await invoiceProvider.listAllReceipts(
          accessToken: accessToken ?? "", page: page);

      debugPrint(
          "📌 API response received: ${value != null ? 'not null' : 'null'}");

      if (value != null && value['status'] == 'success') {
        debugPrint("📌 Response status: success");
        ReceiptResponse receiptResponse = ReceiptResponse.fromJson(value);
        setState(() {
          receiptData = receiptResponse.data;
          receiptList = receiptResponse.data.data;
          debugPrint("📌 Loaded ${receiptList?.length ?? 0} receipts");
        });
      } else {
        debugPrint("📌 Response status: not success, value: $value");
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error) {
      debugPrint("❌ Receipt listing error: ${error.toString()}");
      showScaffold(context: context, message: "Error fetching receipts");
    } finally {
      setState(() {
        initLoading = false;
      });
      debugPrint("📌 searchReceipts finished");
    }
  }

  void resetSearch() {
    setState(() {
      searchTextController.clear();
      loadInitData();
    });
  }

  Future<void> refreshData() async {
    resetSearch();
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
            child: ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                const SizedBox(height: 15),
                Container(
                  height: size.height * 0.6,
                  child: _buildReceiptTable(),
                ),
                const SizedBox(height: 15),
                _buildPaginationControls(),
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
        Text(
          "Receipt List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        // CustomRoundButton(
        //   title: "Create New Receipt",
        //   fct: () {
        //     sideBarController.index.value =
        //         25; // Navigate to create receipt screen
        //   },
        //   fontSize: 12,
        //   height: 45,
        //   width: 200,
        // ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          _buildSearchTextField(),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 30),
            child: CustomRoundButton(
              title: "Search",
              fct: () {
                searchReceipts(1); // Start search from page 1
              },
              height: 45,
              width: size.width * 0.09,
              fontSize: FontSize.s12,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 30),
            child: CustomRoundButton(
              title: "Reset",
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: resetSearch,
              height: 45,
              width: size.width * 0.09,
              fontSize: FontSize.s12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTextField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Name",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(
            height: 45,
            width: 120,
            child: TextFormField(
              controller: searchTextController,
              onChanged: (value) {
                setState(() {
                  // Update state if needed
                });
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Name",
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildReceiptTable() {
    return initLoading
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
                      1: FlexColumnWidth(1.0), // Receipt Number
                      2: FlexColumnWidth(1.5), // Amount
                      3: FlexColumnWidth(2.0), // Payment Reference
                      4: FlexColumnWidth(1.5), // Status
                      5: FlexColumnWidth(1.0), // Payment Method
                      6: FlexColumnWidth(1.0), // Action
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        children: [
                          _buildTableHeader("Customer Name"),
                          _buildTableHeader("Receipt Number"),
                          _buildTableHeader("Amount"),
                          _buildTableHeader("Payment Reference"),
                          _buildTableHeader("Status"),
                          _buildTableHeader("Payment Method"),
                          _buildTableHeader("Action"),
                        ],
                      ),
                    ],
                  ),
                ),
                // Scrollable table body
                Expanded(
                  child: receiptList == null || receiptList!.isEmpty
                      ? const Center(child: Text("No receipts available"))
                      : MouseRegion(
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
                                  0: FlexColumnWidth(2.0), // Customer Name
                                  1: FlexColumnWidth(1.0), // Receipt Number
                                  2: FlexColumnWidth(1.5), // Amount
                                  3: FlexColumnWidth(2.0), // Payment Reference
                                  4: FlexColumnWidth(1.5), // Status
                                  5: FlexColumnWidth(1.0), // Payment Method
                                  6: FlexColumnWidth(1.0), // Action
                                },
                                border: null,
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  ...receiptList!.asMap().entries.map((entry) {
                                    final int index = entry.key;
                                    final receipt = entry.value;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.withOpacity(0.1),
                                      ),
                                      children: [
                                        _buildTableCell(receipt.customer.user.name.toString()),
                                        _buildTableCell(receipt.receiptNumber),
                                        _buildTableCell(receipt.amount),
                                        _buildTableCell(receipt.paymentReference),
                                        _buildTableCell(receipt.receiptStatus),
                                        _buildTableCell(receipt.paymentMethod),
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
                                                  String? token = Provider.of<AuthModel>(context, listen: false).token;
                                                  InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                                                  invoiceProvider.callDetailsOfReceipt(
                                                      id: receipt.id, accessToken: token ?? "");
                                                  sideBarController.index.value = 48;
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

  Widget _buildPaginationControls() {
    return PaginationControl(
      currentPage: receiptData?.currentPage ?? 1,
      totalPages: receiptData?.lastPage ?? 1,
      onPageChanged: (int page) {
        searchReceipts(page);
      },
    );
  }
}
