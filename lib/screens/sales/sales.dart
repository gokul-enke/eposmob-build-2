import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/list_sales_order.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';

import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  GetStoreModelData? storeSelected;
  DateTime? selectedDate;

  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  List<OrderDetailsModelDataCartItem>? cartItems = [];

  bool initLoading = false;
  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  Future<void> downloadFile(String orderNumber) async {
    try {
      // URL of the PDF file
      final url = 'https://epos.enke.ae/download-invoice/$orderNumber';

      // Get the application directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a file path for the PDF
      final filePath = '${directory.path}/invoice.pdf';

      // Use Dio to download the file
      final response = await Dio().download(url, filePath);

      if (response.statusCode == 200) {
        showScaffold(
          context: context,
          message: 'File downloaded successfully',
        );
        debugPrint('File downloaded successfully to $filePath');
        // You can use a package like open_file to open the PDF if needed
      } else {
        showScaffoldError(
          context: context,
          message: 'Failed to download file',
        );
        debugPrint('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error downloading file',
      );
      debugPrint('Error downloading file: $e');
    }
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        storeId: 1,
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchOrders(page) async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        // storeId: 1,
        orderNumber: orderNumberController.text,
        filterName: customerNameController.text,
        filterPrice: amountController.text,
        filterEmail: emailController.text,
        filterPhone: phoneController.text,
        date: selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
            : '',
        filterStore: storeController.text,
        page: page,
      );
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
      orderNumberController.clear();
      customerNameController.clear();
      amountController.clear();
      emailController.clear();
      phoneController.clear();
      storeController.clear();
      selectedDate = null;
      dateController.clear();
    });
    loadInitData();
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
            margin:
                const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
                color: Colors.white),
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Orders List",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, ColorManager.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Number",
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
                                onchanged: (value) {},
                                controller: orderNumberController,
                                size: size,
                                hintText: 'Number',
                              ),
                            ],
                          ),
                        ),

                        // Name
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Customer ",
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
                                onchanged: (value) {},
                                controller: customerNameController,
                                size: size,
                                hintText: 'Customer Name',
                              ),
                            ],
                          ),
                        ),

                        // Date
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
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
                          ),
                        ),

                        // Price
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Price",
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
                                onchanged: (value) {},
                                controller: amountController,
                                size: size,
                                hintText: 'Price',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Email
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Email",
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
                                onchanged: (value) {},
                                controller: emailController,
                                size: size,
                                hintText: 'Email',
                              ),
                            ],
                          ),
                        ),

                        // Phone
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Phone",
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
                                onchanged: (value) {},
                                controller: phoneController,
                                size: size,
                                hintText: 'Phone',
                              ),
                            ],
                          ),
                        ),

                        // Store
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Store",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 45,
                                width: 150,
                                child: BuildBoxShadowContainer(
                                  circleRadius: 7,
                                  alignment: Alignment.centerLeft,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 0),
                                  padding: const EdgeInsets.only(left: 15),
                                  height: size.height * .07,
                                  width: size.width / 4.5,
                                  child: DropdownButtonFormField<
                                      GetStoreModelData>(
                                    decoration: const InputDecoration(
                                      border: InputBorder
                                          .none, // Remove the underline
                                    ),
                                    value: storeSelected,
                                    hint: Text(
                                      'Select Store',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.27,
                                        ColorManager.textColor.withOpacity(.5),
                                      ),
                                    ),
                                    items: storeList!
                                        .map((GetStoreModelData store) {
                                      return DropdownMenuItem<
                                              GetStoreModelData>(
                                          value: store,
                                          child: Text(
                                            store.name ?? '',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ));
                                    }).toList(),
                                    onChanged:
                                        (GetStoreModelData? storeModelData) {
                                      if (storeModelData != null) {
                                        // Update the selected category in the provider
                                        setState(() {
                                          storeSelected = storeModelData;
                                          storeController.text =
                                              "${storeModelData.id ?? 1}";
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 35),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              CustomRoundButton(
                                title: "Search",
                                fct: () {
                                  searchOrders(1);
                                },
                                height: 45,
                                width: size.width * 0.09,
                                fontSize: FontSize.s12,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 35),
                          child: Column(
                            children: [
                              CustomRoundButton(
                                title: "Reset",
                                boxColor: Colors.white,
                                textColor: ColorManager.kPrimaryColor,
                                fct: resetSearch,
                                height: 45,
                                width: size.width * 0.09,
                                fontSize: FontSize.s12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  BuildBoxShadowContainer(
                      circleRadius: 7,
                      offsetValue: const Offset(1, 1),
                      child: Consumer<SalesProvider>(
                        builder: (context, orderProvider, child) {
                          List<ListOrderModelData> orders =
                              orderProvider.orders;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: size.width * 0.80,
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(3),
                                  2: FlexColumnWidth(3),
                                  3: FlexColumnWidth(1),
                                  4: FlexColumnWidth(3),
                                  5: FlexColumnWidth(3),
                                  6: FlexColumnWidth(4),
                                },
                                border: const TableBorder.symmetric(
                                    outside: BorderSide(
                                        color: ColorManager.tableBOrderColor,
                                        width: 0.1),
                                    inside: BorderSide(
                                        color: ColorManager.tableBOrderColor,
                                        width: 0.5)),
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  TableRow(
                                      decoration: BoxDecoration(
                                          color: ColorManager.tableBGColor
                                              .withOpacity(0.4)),
                                      children: [
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "No",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Order #",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Date",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Quantity",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        // TableCell(
                                        //     verticalAlignment:
                                        //         TableCellVerticalAlignment.middle,
                                        //     child: Padding(
                                        //       padding: const EdgeInsets.all(15.0),
                                        //       child: Center(
                                        //           child: Text(
                                        //         "Offer",
                                        //         // "Offers Applied",
                                        //         style: buildCustomStyle(
                                        //           FontWeightManager.medium,
                                        //           FontSize.s12,
                                        //           0.18,
                                        //           ColorManager.kPrimaryColor,
                                        //         ),
                                        //       )),
                                        //     )),
                                        // TableCell(
                                        //     verticalAlignment:
                                        //         TableCellVerticalAlignment.middle,
                                        //     child: Padding(
                                        //       padding: const EdgeInsets.all(15.0),
                                        //       child: Center(
                                        //           child: Text(
                                        //         "Store Name",
                                        //         style: buildCustomStyle(
                                        //           FontWeightManager.medium,
                                        //           FontSize.s12,
                                        //           0.18,
                                        //           ColorManager.kPrimaryColor,
                                        //         ),
                                        //       )),
                                        //     )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Payment summary",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Customer Details",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                  child: Text(
                                                "Action",
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.18,
                                                  ColorManager.kPrimaryColor,
                                                ),
                                              )),
                                            )),
                                      ]),

                                  // Map your order data to table rows here
                                  ...orders.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    ListOrderModelData order = entry.value;
                                    PriceSummary priceSummary =
                                        order.priceSummary ?? PriceSummary();

                                    return TableRow(
                                      children: [
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Center(
                                                child: Text(
                                                  "${index + 1}",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s9,
                                                    0.13,
                                                    Colors.black,
                                                  ),
                                                ),
                                              ),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(30.0),
                                              child: Center(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    sideBarController
                                                        .index.value = 11;

                                                    orderProvider.setOrderId(
                                                        order.orderNumber ??
                                                            "0");
                                                  },
                                                  child: Text(
                                                    "#${order.orderNumber}",
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s9,
                                                      0.13,
                                                      ColorManager.kPrimaryColor
                                                          .withOpacity(0.9),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Center(
                                                child: Text(
                                                  DateHelper.formatYearMonthDay(
                                                      order.orderDate!),
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s9,
                                                    0.13,
                                                    Colors.black,
                                                  ),
                                                ),
                                              ),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Center(
                                                child: Text(
                                                  "${order.cartItems!.length}",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s9,
                                                    0.13,
                                                    Colors.black,
                                                  ),
                                                ),
                                              ),
                                            )),
                                        // TableCell(
                                        //     verticalAlignment:
                                        //         TableCellVerticalAlignment.middle,
                                        //     child: Padding(
                                        //       padding: const EdgeInsets.all(20.0),
                                        //       child: Center(
                                        //         child: Text(
                                        //           "0% ",
                                        //           // "0% offer applied",
                                        //           style: buildCustomStyle(
                                        //             FontWeightManager.medium,
                                        //             FontSize.s9,
                                        //             0.13,
                                        //             ColorManager.kPrimaryColor,
                                        //           ),
                                        //         ),
                                        //       ),
                                        //     )),
                                        // TableCell(
                                        //     verticalAlignment:
                                        //         TableCellVerticalAlignment.middle,
                                        //     child: Padding(
                                        //       padding: const EdgeInsets.all(20.0),
                                        //       child: Center(

                                        //           // child: Text(
                                        //           //   Provider.of<PurchaseProvider>(
                                        //           //           context,
                                        //           //           listen: false)
                                        //           //       .getStoreNameFromId(
                                        //           //           order.storeId ?? 0),
                                        //           //   style: buildCustomStyle(
                                        //           //     FontWeightManager.medium,
                                        //           //     FontSize.s9,
                                        //           //     0.13,
                                        //           //     ColorManager.kPrimaryColor,
                                        //           //   ),
                                        //           // ),
                                        //           ),
                                        //     )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Center(
                                                child: Text(
                                                  "Rs ${AmountHelper.formatAmount(priceSummary.grandTotal ?? 0.0)}",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s9,
                                                    0.13,
                                                    Colors.black,
                                                  ),
                                                ),
                                              ),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(20.0),
                                              child: Center(
                                                child: Text(
                                                  "${order.customerName ?? "NA"}\n +91 ${order.customerDetails!.phone}",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s9,
                                                    0.13,
                                                    Colors.black,
                                                  ),
                                                ),
                                              ),
                                            )),
                                        TableCell(
                                            verticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(15.0),
                                              child: Center(
                                                child: Row(
                                                  children: [
                                                    BuildBoxShadowContainer(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
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
                                                          onPressed: () async {
                                                            orderProvider
                                                                .setOrderId(order
                                                                    .orderNumber
                                                                    .toString());
                                                            sideBarController
                                                                .index
                                                                .value = 11;
                                                          },
                                                        )),
                                                    BuildBoxShadowContainer(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
                                                        color: ColorManager
                                                            .kPrimaryColor
                                                            .withOpacity(0.9),
                                                        circleRadius: 5,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.edit,
                                                            size: 18,
                                                            color: Colors.white,
                                                          ),
                                                          onPressed: () async {
                                                            Provider.of<CartProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .setCartIDForOrder(
                                                                    int.parse(order
                                                                        .cartId
                                                                        .toString()));
                                                            orderProvider
                                                                .setOrderId(order
                                                                    .orderNumber
                                                                    .toString());
                                                            sideBarController
                                                                .index
                                                                .value = 51;
                                                          },
                                                        )),
                                                    BuildBoxShadowContainer(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
                                                        color: ColorManager
                                                            .kPrimaryColor
                                                            .withOpacity(0.9),
                                                        circleRadius: 5,
                                                        child: IconButton(
                                                            icon: const Icon(
                                                              Icons.print,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              try {
                                                                String ordersId = order
                                                                    .orderNumber
                                                                    .toString();
                                                                String?
                                                                    accessToken =
                                                                    Provider.of<AuthModel>(
                                                                            context,
                                                                            listen:
                                                                                false)
                                                                        .token;

                                                                final OrderDetailsresponse =
                                                                    await SalesProvider().listOrderDetails(
                                                                        context,
                                                                        ordersId,
                                                                        accessToken ??
                                                                            "");

                                                                if (OrderDetailsresponse[
                                                                        "status"] ==
                                                                    "success") {
                                                                  OrderDetailsModel
                                                                      orderDetails =
                                                                      OrderDetailsModel
                                                                          .fromJson(
                                                                              OrderDetailsresponse);
                                                                  setState(() {
                                                                    orderDetails
                                                                        .data;
                                                                    cartItems =
                                                                        orderDetailsModelData
                                                                            ?.cart
                                                                            ?.cartItems;

                                                                    orderNumber =
                                                                        orderDetailsModelData?.orderNumber ??
                                                                            "";
                                                                  });
                                                                }
                                                              } catch (error) {
                                                                debugPrint(error
                                                                    .toString());
                                                              }

                                                              String
                                                                  formattedTotal =
                                                                  AmountHelper
                                                                      .formatAmount(
                                                                orderDetailsModelData
                                                                    ?.cart
                                                                    ?.priceSummary
                                                                    ?.netTotal,
                                                              );
                                                              String storeName =
                                                                  orderDetailsModelData!
                                                                          .cart!
                                                                          .storeName ??
                                                                      "";
                                                              String orderDate =
                                                                  orderDetailsModelData!
                                                                          .orderDate ??
                                                                      "";

                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          PrintPage(
                                                                    storeName:
                                                                        storeName,
                                                                    cartItems:
                                                                        cartItems!,
                                                                    formattedTotal:
                                                                        formattedTotal,
                                                                    orderDate: DateHelper
                                                                        .formatISODate(
                                                                            orderDate),
                                                                    orderNumber:
                                                                        orderNumber,
                                                                  ),
                                                                ),
                                                              );
                                                            })),
                                                    BuildBoxShadowContainer(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
                                                        color: ColorManager
                                                            .kPrimaryColor
                                                            .withOpacity(0.9),
                                                        circleRadius: 5,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.download,
                                                            size: 18,
                                                            color: Colors.white,
                                                          ),
                                                          onPressed: () async {
                                                            await downloadFile(
                                                                order.orderNumber ??
                                                                    "0");
                                                          },
                                                        )),
                                                  ],
                                                ),
                                              ),
                                            )),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
                  PaginationControl(
                    currentPage:
                        Provider.of<SalesProvider>(context, listen: true)
                            .currentPage,
                    totalPages:
                        Provider.of<SalesProvider>(context, listen: true)
                            .totalPages,
                    onPageChanged: (int page) {
                      searchOrders(page);
                    },
                  )
                ],
              ),
            )),
      ),
    );
  }
}
