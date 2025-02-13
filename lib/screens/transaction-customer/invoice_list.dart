import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  bool initLoading = false;
  final TextEditingController searchTextController = TextEditingController();
  List<Invoice>? invoiceListDetails = [];
  ListInvoiceModel? invoiceData;

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

      // Check if accessToken is null
      if (accessToken == null) {
        throw Exception("Access token is null");
      }

      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      final response =
          await invoiceProvider.listAllInvoices(accessToken: accessToken);

      // Check if response is null or has unexpected format
      if (response == null) {
        throw Exception("Response is null");
      }

      if (response['status'] == 'success') {
        ListInvoiceModel listInvoiceModel = ListInvoiceModel.fromJson(response);
        setState(() {
          invoiceData = listInvoiceModel;
          invoiceListDetails = listInvoiceModel.data.invoices;
        });
      } else {
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error, stackTrace) {
      // debugPrintdebugPrint("Error loading invoices: $error");
      // debugPrintdebugPrint("Stack Trace: $stackTrace");
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  Future<void> searchInvoices(int page) async {
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      // Check if accessToken is null
      if (accessToken == null) {
        throw Exception("Access token is null");
      }

      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      final response =
          await invoiceProvider.listAllInvoices(accessToken: accessToken);

      // Check if response is null or has unexpected format
      if (response == null) {
        throw Exception("Response is null");
      }

      if (response['status'] == 'success') {
        ListInvoiceModel listInvoiceModel = ListInvoiceModel.fromJson(response);
        setState(() {
          invoiceListDetails = listInvoiceModel.data.invoices;
        });
      } else {
        showScaffold(context: context, message: "Data Not Found");
      }
    } catch (error, stackTrace) {
      // debugPrintdebugPrint("Error loading invoices: $error");
      // debugPrintdebugPrint("Stack Trace: $stackTrace");
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      searchTextController.clear();
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
            child: ListView(
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                _buildInvoiceTable(),
                const SizedBox(height: 20),
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
        CustomRoundButton(
          title: "Create New Invoice",
          fct: () {
            sideBarController.index.value = 24;
          },
          fontSize: 12,
          height: 45,
          width: 200,
        ),
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
                // Implement search functionality here
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
              fct: () {
                // Implement reset functionality here
              },
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

  Widget _buildInvoiceTable() {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 20),
      circleRadius: 7,
      offsetValue: const Offset(1, 1),
      child: Table(
        columnWidths: const {
          0: FractionColumnWidth(0.06),
          1: FractionColumnWidth(0.06),
          2: FractionColumnWidth(0.06),
          3: FractionColumnWidth(0.06),
          4: FractionColumnWidth(0.06),
          5: FractionColumnWidth(0.05),
          6: FractionColumnWidth(0.05),
          7: FractionColumnWidth(0.05),
        },
        border: const TableBorder.symmetric(
          outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
          inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildTableHeader(),
          ..._buildTableRows(),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _buildTableCell("Name"),
        _buildTableCell("Invoice Number"),
        _buildTableCell("Type"),
        _buildTableCell("Invoice Date"),
        _buildTableCell("Due Date"),
        _buildTableCell("Amount"),
        _buildTableCell("Status"),
        _buildTableCell("Action"),
      ],
    );
  }

  TableCell _buildTableCell(String title) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  List<TableRow> _buildTableRows() {
    return invoiceListDetails?.map((invoice) {
          return TableRow(
            children: [
              _buildInvoiceCell(invoice.customer.user.name.toString()),
              _buildInvoiceCell(invoice.invoiceNumber),
              _buildInvoiceCell(invoice.type),
              _buildInvoiceCell(invoice.invoiceDate),
              _buildInvoiceCell(invoice.dueDate),
              _buildInvoiceCell(invoice.amount.toString()),
              _buildInvoiceCell(invoice.status),
              _buildActionCell(invoice.id),
            ],
          );
        }).toList() ??
        [];
  }

  TableCell _buildInvoiceCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            content,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s9,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  TableCell _buildActionCell(int transactionId) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Row(
            children: [
              BuildBoxShadowContainer(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return PaginationControl(
      currentPage: invoiceData?.data.currentPage ?? 1,
      totalPages: invoiceData?.data.lastPage ?? 1,
      onPageChanged: (int page) {
        searchInvoices(page);
      },
    );
  }
}
