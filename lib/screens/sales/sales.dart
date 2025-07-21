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
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // URL of the PDF file
      final url = 'https://hypersouq.enke.in/download-invoice/$orderNumber';
      debugPrint('Attempting to download from: $url');

      // Get the application directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a file path for the PDF
      final filePath = '${directory.path}/invoice_$orderNumber.pdf';

      // Configure Dio with options
      final dio = Dio();
      dio.options.validateStatus =
          (status) => status! < 500; // Don't throw on 4xx errors

      // Use Dio to download the file
      final response = await dio.download(url, filePath,
          onReceiveProgress: (received, total) {
        if (total != -1) {
          debugPrint(
              'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      });

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        showScaffold(
          context: context,
          message: 'Invoice downloaded successfully to ${directory.path}',
        );
        debugPrint('File downloaded successfully to $filePath');
      } else if (response.statusCode == 404) {
        showScaffoldError(
          context: context,
          message:
              'Invoice not found. The order may not have a generated invoice.',
        );
        debugPrint('Invoice not found: ${response.statusCode}');
      } else {
        showScaffoldError(
          context: context,
          message: 'Failed to download invoice: Error ${response.statusCode}',
        );
        debugPrint('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // More detailed error message based on error type
      String errorMessage = 'Error downloading file';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage =
              'Connection timeout. Please check your internet connection.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage =
              'Connection error. Please check your internet connection.';
        } else if (e.response?.statusCode == 500) {
          errorMessage =
              'Server error. The invoice generation service may be unavailable.';
        } else {
          errorMessage = 'Download error: ${e.message}';
        }
      } else {
        errorMessage = 'Error downloading file: ${e.toString()}';
      }

      showScaffoldError(
        context: context,
        message: errorMessage,
      );
      debugPrint('Error downloading file: $e');
    }
  }

  void loadInitData() async {
    debugPrint('=== LOAD INIT DATA START ===');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      debugPrint(
          'Access Token Available: ${accessToken != null ? "Yes" : "No"}');
      debugPrint('Access Token Length: ${accessToken?.length ?? 0}');

      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      debugPrint('Calling fetchOrders with storeId: 1');
      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        storeId: 1,
      );
      debugPrint('fetchOrders completed successfully');
    } catch (error, stackTrace) {
      debugPrint('=== LOAD INIT DATA ERROR ===');
      debugPrint('Error Type: ${error.runtimeType}');
      debugPrint('Error Message: $error');
      debugPrint('Stack Trace: $stackTrace');
    } finally {
      setState(() {
        initLoading = false;
      });
      debugPrint('=== LOAD INIT DATA END ===');
    }
  }

  void searchOrders(page) async {
    debugPrint('=== SEARCH ORDERS START ===');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      // Prepare filters
      final filters = {
        if (orderNumberController.text.isNotEmpty)
          'orderNumber': orderNumberController.text.trim(),
        if (customerNameController.text.isNotEmpty)
          'filterName': customerNameController.text.trim(),
        if (amountController.text.isNotEmpty)
          'filterPrice': amountController.text.trim(),
        if (emailController.text.isNotEmpty)
          'filterEmail': emailController.text.trim(),
        if (phoneController.text.isNotEmpty)
          'filterPhone': phoneController.text.trim(),
        if (selectedDate != null)
          'date': DateFormat('yyyy-MM-dd').format(selectedDate!),
        if (storeController.text.isNotEmpty)
          'filterStore': storeController.text.trim(),
        'page': page.toString(),
      };

      debugPrint('Search filters: $filters');

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        orderNumber: filters['orderNumber'],
        filterName: filters['filterName'],
        filterPrice: filters['filterPrice'],
        filterEmail: filters['filterEmail'],
        filterPhone: filters['filterPhone'],
        date: filters['date'],
        filterStore: filters['filterStore'],
        page: int.tryParse(filters['page'] ?? '1') ?? 1,
      );
    } catch (error, stackTrace) {
      debugPrint('Search error: $error');
      debugPrint('Stack trace: $stackTrace');
      showScaffoldError(
        context: context,
        message: 'Failed to search orders: ${error.toString()}',
      );
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
      storeSelected = null;
      selectedDate = null;
    });
    searchOrders(1); // Trigger fresh search after reset
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
                  // Replace only the search and filter section in your build method (keep everything else the same)
                 Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align everything to the left
        children: [
          // First Row - Search Fields
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start, // Left-align items
            children: [
              // Order Number
              SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Order #",
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
                      width: 350,
                      onchanged: (value) {
                        if (value!.isEmpty || value.length > 2) {
                          searchOrders(1);
                        }
                      },
                      controller: orderNumberController,
                      size: size,
                      hintText: 'Order Number',
                    ),
                  ],
                ),
              ),

              // Customer Name
              SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Customer",
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
                      width: 350,
                      onchanged: (value) {
                        if (value!.isEmpty || value.length > 2) {
                          searchOrders(1);
                        }
                      },
                      controller: customerNameController,
                      size: size,
                      hintText: 'Customer Name',
                    ),
                  ],
                ),
              ),
            

              // Phone
               SizedBox(
                width: 350,
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
                      width: 350,
                      onchanged: (value) {
                        if (value!.isEmpty || value.length > 2) {
                          searchOrders(1);
                        }
                      },
                      controller: phoneController,
                      size: size,
                      hintText: 'Phone',
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Second Row - Filters and Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start, // Left-align items
            children: [
                SizedBox(
                width: 200,
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
                      width: 200,
                      child: Center(
                        child: CalendarPickerTableCell(
                          onDateSelected: (DateTime date) {
                            setState(() {
                              selectedDate = date;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Price
              SizedBox(
                width: 225,
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
                      width: 250,
                      onchanged: (value) {
                        if (value!.isEmpty || value.length > 2) {
                          searchOrders(1);
                        }
                      },
                      controller: amountController,
                      size: size,
                      hintText: 'Price',
                    ),
                  ],
                ),
              ),
              
       

              // Store
              SizedBox(
                width: 200,
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
                      width: 200,
                      child: BuildBoxShadowContainer(
                        circleRadius: 7,
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                        padding: const EdgeInsets.only(left: 15),
                        child: DropdownButtonFormField<GetStoreModelData>(
                          decoration: const InputDecoration(border: InputBorder.none),
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
                          items: storeList!.map((GetStoreModelData store) {
                            return DropdownMenuItem<GetStoreModelData>(
                              value: store,
                              child: Text(
                                store.name ?? '',
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (GetStoreModelData? storeModelData) {
                            if (storeModelData != null) {
                              setState(() {
                                storeSelected = storeModelData;
                                storeController.text = storeModelData.id.toString();
                              });
                              searchOrders(1);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Button
              Padding(
                padding: const EdgeInsets.only(top: 35.0),
                child: CustomRoundButton(
                  title: "Search",
                  fct: () { searchOrders(1); },
                  height: 45,
                  width: 200,
                  fontSize: FontSize.s12,
                ),
              ),

              // Reset Button
              Padding(
                padding: const EdgeInsets.only(top: 35.0),
                child: CustomRoundButton(
                  title: "Reset",
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: resetSearch,
                  height: 45,
                  width: 200,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ],
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

                          // DEBUG: Print UI rendering details
                          debugPrint('=== SALES UI RENDER DEBUG ===');
                          debugPrint('Orders List Length: ${orders.length}');
                          debugPrint(
                              'Orders Provider State: ${orderProvider.runtimeType}');
                          debugPrint(
                              'Current Page: ${orderProvider.currentPage}');
                          debugPrint(
                              'Total Pages: ${orderProvider.totalPages}');

                          if (orders.isEmpty) {
                            debugPrint('=== NO ORDERS TO DISPLAY ===');
                            debugPrint(
                                'Orders list is empty - no data to render');
                          } else {
                            debugPrint('=== ORDERS TO RENDER ===');
                            for (int i = 0; i < orders.length && i < 5; i++) {
                              var order = orders[i];
                              debugPrint(
                                  'UI Order $i: ${order.orderNumber} - ${order.grantTotal}');
                            }
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: size.width * 0.80,
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(3),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(2),
                                  4: FlexColumnWidth(3),
                                  5: FlexColumnWidth(3),
                                  6: FlexColumnWidth(2),
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
                                                "Item Count",
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

                                                    orderProvider
                                                        .setOrderNumber(
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
                                                                .setOrderNumber(order
                                                                    .orderNumber
                                                                    .toString());
                                                            sideBarController
                                                                .index
                                                                .value = 11;
                                                          },
                                                        )),
                                                    (order.status == "new")
                                                        ? BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            color: ColorManager
                                                                .kPrimaryColor
                                                                .withOpacity(
                                                                    0.9),
                                                            circleRadius: 5,
                                                            child: IconButton(
                                                              icon: const Icon(
                                                                Icons.edit,
                                                                size: 18,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                Provider.of<CartProvider>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .setCartIDForOrder(
                                                                        int.parse(order
                                                                            .cartId
                                                                            .toString()));
                                                                orderProvider
                                                                    .setOrderNumber(order
                                                                        .orderNumber
                                                                        .toString());
                                                                orderProvider
                                                                    .setOrderId(
                                                                        order.id
                                                                            .toString());
                                                                sideBarController
                                                                    .index
                                                                    .value = 51;
                                                              },
                                                            ))
                                                        : Container(),
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

                                                                  String?
                                                                      formattedTotal =
                                                                      orderDetails
                                                                          .data
                                                                          ?.cart
                                                                          ?.priceSummary
                                                                          ?.netTotal
                                                                          .toString();
                                                                  String?
                                                                      savedTotal =
                                                                      orderDetails
                                                                          .data
                                                                          ?.cart
                                                                          ?.priceSummary
                                                                          ?.savedTotal
                                                                          .toString();

                                                                  debugPrint(
                                                                      "savedTotal: $savedTotal");
                                                                  String
                                                                      storeName =
                                                                      orderDetails
                                                                              .data!
                                                                              .cart!
                                                                              .storeName ??
                                                                          "";
                                                                  String
                                                                      orderDate =
                                                                      orderDetails
                                                                              .data!
                                                                              .orderDate ??
                                                                          "";

                                                                  Navigator
                                                                      .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              PrintPage(
                                                                        storeName:
                                                                            storeName,
                                                                        cartItems:
                                                                            orderDetails.data?.cart?.cartItems ??
                                                                                [],
                                                                        formattedTotal:
                                                                            formattedTotal!,
                                                                        savedTotal:
                                                                            savedTotal!,
                                                                        orderDate:
                                                                            orderDate,
                                                                        orderNumber: orderDetails
                                                                            .data!
                                                                            .orderNumber
                                                                            .toString(),
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                              } catch (error) {
                                                                debugPrint(error
                                                                    .toString());
                                                              }
                                                            })),
                                                    // BuildBoxShadowContainer(
                                                    //     margin: const EdgeInsets
                                                    //         .only(
                                                    //         left: 5, right: 5),
                                                    //     color: ColorManager
                                                    //         .kPrimaryColor
                                                    //         .withOpacity(0.9),
                                                    //     circleRadius: 5,
                                                    //     child: IconButton(
                                                    //       icon: const Icon(
                                                    //         Icons.download,
                                                    //         size: 18,
                                                    //         color: Colors.white,
                                                    //       ),
                                                    //       onPressed: () async {
                                                    //         await downloadFile(
                                                    //             order.orderNumber ??
                                                    //                 "0");
                                                    //       },
                                                    //     )),
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
