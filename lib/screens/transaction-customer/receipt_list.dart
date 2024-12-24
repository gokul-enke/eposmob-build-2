import 'package:flutter/material.dart';
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
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      await invoiceProvider
          .listAllReceipts(accessToken: accessToken ?? "")
          .then((value) {
        if (value['status'] == 'success') {
          ReceiptResponse receiptResponse = ReceiptResponse.fromJson(value);
          receiptData = receiptResponse.data;
          receiptList =
              receiptResponse.data.data; // Update to point to receipts data
        } else {
          showScaffold(context: context, message: "Data Not Found");
        }
      });
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  Future<void> searchReceipts(int page) async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      await invoiceProvider
          .listAllReceipts(accessToken: accessToken ?? "")
          .then((value) {
        if (value['status'] == 'success') {
          ReceiptResponse receiptResponse = ReceiptResponse.fromJson(value);
          receiptList =
              receiptResponse.data.data; // Update to point to receipts data
        } else {
          showScaffold(context: context, message: "Data Not Found");
        }
      });
    } catch (error) {
      debugPrint(error.toString());
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
                _buildReceiptTable(),
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
        CustomRoundButton(
          title: "Create New Receipt",
          fct: () {
            sideBarController.index.value =
                25; // Navigate to create receipt screen
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

  Widget _buildReceiptTable() {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 20),
      circleRadius: 7,
      offsetValue: const Offset(1, 1),
      child: Table(
        columnWidths: const {
          0: FractionColumnWidth(0.2),
          1: FractionColumnWidth(0.1),
          2: FractionColumnWidth(0.15),
          3: FractionColumnWidth(0.2),
          4: FractionColumnWidth(0.15),
          5: FractionColumnWidth(0.1),
          6: FractionColumnWidth(0.1),
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
        _buildTableCell("Customer Name"),
        _buildTableCell("Receipt Number"),
        _buildTableCell("Amount"),
        _buildTableCell("Payment Reference"),
        _buildTableCell("Status"),
        _buildTableCell("Payment Method"),
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
    return receiptList!.map((receipt) {
      return TableRow(
        children: [
          _buildReceiptCell(receipt.customer.user.name.toString()),
          _buildReceiptCell(receipt.receiptNumber),
          _buildReceiptCell(receipt.amount),
          _buildReceiptCell(receipt.paymentReference),
          _buildReceiptCell(receipt.receiptStatus),
          _buildReceiptCell(receipt.paymentMethod),
          _buildActionCell(receipt),
        ],
      );
    }).toList();
  }

  TableCell _buildReceiptCell(String content) {
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

  TableCell _buildActionCell(Receipt receipt) {
    return TableCell(
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.visibility, color: ColorManager.kPrimaryColor),
          onPressed: () {
            String? token =
                Provider.of<AuthModel>(context, listen: false).token;
            InvoiceProvider invoiceProvider =
                Provider.of<InvoiceProvider>(context, listen: false);
            invoiceProvider.callDetailsOfReceipt(
                id: receipt.id, accessToken: token ?? "");
            sideBarController.index.value = 48;
          },
        ),
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
