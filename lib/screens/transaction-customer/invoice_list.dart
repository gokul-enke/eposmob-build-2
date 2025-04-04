import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitialized = false;
  final TextEditingController searchTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadInvoices();
    });
  }

  Future<void> loadInvoices() async {
    if (isInitialized) return;
    
    try {
      final String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
      
      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }
      
      await Provider.of<InvoiceProvider>(context, listen: false).listAllInvoices(accessToken: accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading invoices: $error")),
      );
    }
  }

  void searchInvoices() {
    debugPrint("Searching for: ${searchTextController.text}");
    InvoiceProvider provider = Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyFilters(name: searchTextController.text);
  }

  void resetSearch() {
    debugPrint("Resetting search");
    setState(() {
      searchTextController.clear();
    });
    
    Provider.of<InvoiceProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    debugPrint("Refreshing data");
    final String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;
    
    // Reset search field when refreshing
    setState(() {
      searchTextController.clear();
    });
    
    await Provider.of<InvoiceProvider>(context, listen: false).listAllInvoices(accessToken: accessToken);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: const EdgeInsets.all(10),
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
                _buildInvoiceTable(),
                const SizedBox(height: 10),
                _buildPaginationControls(),
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
          "Invoice List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        // CustomRoundButton(
        //   title: "Create New Invoice",
        //   fct: () {
        //     sideBarController.index.value = 24;
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
                searchInvoices();
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

  Widget _buildInvoiceTable() {
    return Expanded(
      child: Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
          final isLoading = invoiceProvider.isLoading;
          final invoiceList = invoiceProvider.invoiceListDetails;
          
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
                                0: FlexColumnWidth(2.0), // Name
                                1: FlexColumnWidth(1.5), // Invoice Number
                                2: FlexColumnWidth(1.0), // Type
                                3: FlexColumnWidth(1.5), // Invoice Date
                                4: FlexColumnWidth(1.5), // Due Date
                                5: FlexColumnWidth(1.0), // Amount
                                6: FlexColumnWidth(1.0), // Status
                                7: FlexColumnWidth(1.0), // Action
                              },
                              border: null,
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildTableHeader("Name"),
                                    _buildTableHeader("Invoice Number"),
                                    _buildTableHeader("Type"),
                                    _buildTableHeader("Invoice Date"),
                                    _buildTableHeader("Due Date"),
                                    _buildTableHeader("Amount"),
                                    _buildTableHeader("Status"),
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
                                child: invoiceList == null || invoiceList.isEmpty
                                  ? _buildNoInvoicesFoundUI()
                                  : SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    scrollDirection: Axis.vertical,
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2.0), // Name
                                        1: FlexColumnWidth(1.5), // Invoice Number
                                        2: FlexColumnWidth(1.0), // Type
                                        3: FlexColumnWidth(1.5), // Invoice Date
                                        4: FlexColumnWidth(1.5), // Due Date
                                        5: FlexColumnWidth(1.0), // Amount
                                        6: FlexColumnWidth(1.0), // Status
                                        7: FlexColumnWidth(1.0), // Action
                                      },
                                      border: null,
                                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                      children: _buildTableRows(invoiceList),
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
        }
      ),
    );
  }

  Widget _buildNoInvoicesFoundUI() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
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
            'No invoices found',
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

  List<TableRow> _buildTableRows(List<Invoice>? invoices) {
    return invoices?.asMap().entries.map((entry) {
          final int index = entry.key;
          final invoice = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
            ),
            children: [
              _buildTableCell(invoice.customer.user.name.toString()),
              _buildTableCell(invoice.invoiceNumber),
              _buildTableCell(invoice.type),
              _buildTableCell(invoice.invoiceDate),
              _buildTableCell(invoice.dueDate),
              _buildTableCell(invoice.amount.toString()),
              _buildTableCell(invoice.status),
              _buildActionCell(invoice.id),
            ],
          );
        }).toList() ??
        [];
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

  TableCell _buildActionCell(int transactionId) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
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
                String? token =
                    Provider.of<AuthModel>(context, listen: false).token;
                InvoiceProvider invoiceProvider =
                    Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.callDetailsOfInvoice(
                    id: transactionId, accessToken: token ?? "");
                sideBarController.index.value = 31;
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
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        debugPrint("Building pagination controls: currentPage=${invoiceProvider.currentPage}, totalPages=${invoiceProvider.totalPages}");
        return PaginationControl(
          currentPage: invoiceProvider.currentPage,
          totalPages: invoiceProvider.totalPages,
          onPageChanged: (int page) {
            debugPrint("Page changed to: $page");
            invoiceProvider.goToPage(page);
          },
        );
      }
    );
  }
}
