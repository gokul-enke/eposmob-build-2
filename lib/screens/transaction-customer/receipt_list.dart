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
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadReceipts();
    });
  }

  Future<void> loadReceipts() async {
    if (isInitialized) return;
    
    try {
      final String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
      
      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }
      
      // Load all receipts for local pagination
      await Provider.of<InvoiceProvider>(context, listen: false).loadAllReceipts(accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      debugPrint("Error loading receipts: $error");
      showScaffold(context: context, message: "Error fetching receipts: $error");
    }
  }

  void searchReceipts() {
    final String searchText = searchTextController.text.trim();
    debugPrint("Searching for receipts with name: '$searchText'");
    
    InvoiceProvider provider = Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyReceiptFilters(name: searchText, page: 1);
  }

  void resetSearch() {
    setState(() {
      searchTextController.clear();
    });
    Provider.of<InvoiceProvider>(context, listen: false).resetReceiptFilters();
  }

  Future<void> refreshData() async {
    final String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;
    
    await Provider.of<InvoiceProvider>(context, listen: false).loadAllReceipts(accessToken);
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
                searchReceipts();
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
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        final isLoading = invoiceProvider.isLoading;
        final receiptList = invoiceProvider.getListReceipt;
        
        return isLoading 
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
                      child: receiptList == null || receiptList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 60,
                                    color: ColorManager.kPrimaryColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'No receipts available',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s18,
                                      0.27,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search criteria',
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.20,
                                      Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
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
                                      ...receiptList.asMap().entries.map((entry) {
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
      },
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        return PaginationControl(
          currentPage: invoiceProvider.receiptCurrentPage,
          totalPages: invoiceProvider.receiptTotalPages,
          onPageChanged: (int page) {
            invoiceProvider.goToReceiptPage(page);
          },
        );
      },
    );
  }
}
