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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    InvoiceProvider invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);

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
                _buildSearchSection(size),
                _buildTransactionTable(invoiceProvider, token),
                const SizedBox(height: 20),
                _buildPaginationControls(invoiceProvider),
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
          "Transaction Management",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
      ],
    );
  }

  Widget _buildSearchSection(Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _buildAmountField(size),
            const SizedBox(width: 10),
            _buildDatePicker(size),
            const SizedBox(width: 10),
            _buildSearchButton(size),
            const SizedBox(width: 10),
            _buildResetButton(size),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountField(Size size) {
    return Column(
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
          width: 120,
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
    );
  }

  Widget _buildDatePicker(Size size) {
    return Column(
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
          width: 150,
          child: Center(
            child: CalendarPickerTableCell(
              onDateSelected: (DateTime date) {
                selectedDate = date;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 35),
      child: CustomRoundButton(
        title: "Search",
        fct: searchTransactions,
        height: 45,
        width: size.width * 0.09,
        fontSize: FontSize.s12,
      ),
    );
  }

  Widget _buildResetButton(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 35),
      child: CustomRoundButton(
        title: "Reset",
        boxColor: Colors.white,
        textColor: ColorManager.kPrimaryColor,
        fct: resetSearch,
        height: 45,
        width: size.width * 0.09,
        fontSize: FontSize.s12,
      ),
    );
  }

  Widget _buildTransactionTable(
      InvoiceProvider invoiceProvider, String? token) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 20),
      circleRadius: 7,
      child: Table(
        columnWidths: const {
          0: FractionColumnWidth(0.06),
          1: FractionColumnWidth(0.06),
          2: FractionColumnWidth(0.06),
          3: FractionColumnWidth(0.06),
          4: FractionColumnWidth(0.06),
          5: FractionColumnWidth(0.05),
        },
        border: const TableBorder.symmetric(
          outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
          inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildTableHeader(),
          ..._buildTableRows(invoiceProvider, token),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _buildTableCell("Name"),
        _buildTableCell("Type"),
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

  List<TableRow> _buildTableRows(
      InvoiceProvider invoiceProvider, String? token) {
    return listTransaction!.where((transaction) {
      return transaction.amount!.contains(searchAmount);
    }).map((transaction) {
      return TableRow(
        children: [
          _buildTransactionCell("Name"),
          _buildTransactionCell("${transaction.type}"),
          _buildTransactionCell(
              "${transaction.currency} ${transaction.amount}"),
          _buildTransactionCell("${transaction.status}"),
          _buildActionCell(transaction, token, invoiceProvider),
        ],
      );
    }).toList();
  }

  TableCell _buildTransactionCell(String content) {
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

  TableCell _buildActionCell(ListTransaction transaction, String? token,
      InvoiceProvider invoiceProvider) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Row(
            children: [
              BuildBoxShadowContainer(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                circleRadius: 5,
                child: IconButton(
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                  ),
                  onPressed: () {
                    invoiceProvider.callDetailsOfTransaction(
                      id: transaction.id ?? 0,
                      accessToken: token ?? "",
                    );
                    sideBarController.index.value = 30;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(InvoiceProvider invoiceProvider) {
    return PaginationControl(
      currentPage: invoiceProvider.currentPage,
      totalPages: invoiceProvider.totalPages,
      onPageChanged: (int page) {
        searchTransactions(page);
      },
    );
  }
}
