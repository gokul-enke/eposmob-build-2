import 'dart:ui';

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
import 'package:url_launcher/url_launcher.dart';

import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/list_sales_order.dart';
import '../../providers/auth_model.dart';
import '../../resources/app_url.dart';
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
  Key calendarPickerKey = UniqueKey();

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

  Future<void> downloadFile(String invoiceHash) async {
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
      final url = '${APPUrl.baseURL}/invoice-download/$invoiceHash';
      debugPrint('Attempting to download from: $url');

      // Get the application directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a file path for the PDF
      final filePath = '${directory.path}/invoice_$invoiceHash.pdf';

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
    debugPrint('Requested Page: $page');
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
      debugPrint('Calling fetchOrders with page: $page');

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

      debugPrint('=== SEARCH ORDERS COMPLETED ===');
      debugPrint('Current Page: ${orderProvider.currentPage}');
      debugPrint('Total Pages: ${orderProvider.totalPages}');
      debugPrint('Orders Count: ${orderProvider.orders.length}');
    } catch (error, stackTrace) {
      debugPrint('Search error: $error');
      debugPrint('Stack trace: $stackTrace');
      showScaffoldError(
        context: context,
        message: 'No Orders Found',
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
      calendarPickerKey = UniqueKey();
    });
    searchOrders(1); // Trigger fresh search after reset
  }

  Future<void> refreshData() async {
    resetSearch();
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
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9, // Increased from s9
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ListOrderModelData order, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility,
              size: 18, color: ColorManager.kPrimaryColor),
          onPressed: () {
            Provider.of<SalesProvider>(context, listen: false)
                .setOrderNumber(order.orderNumber ?? "0");
            Get.find<SideBarController>().index.value = 11;
          },
        ),
        // if (order.status == "new")
        //   IconButton(
        //     icon: Icon(Icons.edit, size: 18, color: Colors.orange),
        //     onPressed: () {
        //       Provider.of<CartProvider>(context, listen: false)
        //           .setCartIDForOrder(int.parse(order.cartId.toString()));
        //       Provider.of<SalesProvider>(context, listen: false)
        //           .setOrderNumber(order.orderNumber.toString());
        //       Provider.of<SalesProvider>(context, listen: false)
        //           .setOrderId(order.id.toString());
        //       Get.find<SideBarController>().index.value = 51;
        //     },
        //   ),
        IconButton(
          icon: const Icon(Icons.print, size: 18, color: Colors.blue),
          onPressed: () async {
            try {
              String ordersId = order.orderNumber.toString();
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;

              final OrderDetailsresponse = await SalesProvider()
                  .listOrderDetails(context, ordersId, accessToken ?? "");

              if (OrderDetailsresponse["status"] == "success") {
                OrderDetailsModel orderDetails =
                    OrderDetailsModel.fromJson(OrderDetailsresponse);

                String? formattedTotal =
                    orderDetails.data?.cart?.priceSummary?.netTotal.toString();
                String? savedTotal = orderDetails
                    .data?.cart?.priceSummary?.savedTotal
                    .toString();

                String storeName = orderDetails.data!.cart!.storeName ?? "";
                String orderDate = orderDetails.data!.orderDate ?? "";
                
                // Extract customer details
                String? customerName = orderDetails.data?.customerDetails?.name;
                String? customerPhone = orderDetails.data?.customerDetails?.phone;
                String? customerEmail = orderDetails.data?.customerDetails?.email;
                String? customerAddress = orderDetails.data?.customerDetails?.address?.join(', ');

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrintPage(
                      storeName: storeName,
                      cartItems: orderDetails.data?.cart?.cartItems ?? [],
                      formattedTotal: formattedTotal!,
                      savedTotal: savedTotal!,
                      orderDate: orderDate,
                      orderNumber: orderDetails.data!.orderNumber.toString(),
                      customerName: customerName,
                      customerPhone: customerPhone,
                      customerEmail: customerEmail,
                      customerAddress: customerAddress,
                    ),
                  ),
                );
              }
            } catch (error) {
              debugPrint(error.toString());
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.share, size: 18, color: Colors.blue),
          onPressed: () async {
            try {
              String? invoiceHash =
                  order.invoiceHash; // Use the new invoiceHash field
              if (invoiceHash == null) {
                if (context.mounted) {
                  showScaffoldError(
                    context: context,
                    message: 'Invoice not available for sharing.',
                  );
                }
                return;
              }
              String invoiceUrl =
                  "${APPUrl.baseURL}/invoice-download/$invoiceHash";
              String message =
                  "Here is the link for your invoice :- $invoiceUrl";

              // Encode the message for WhatsApp
              String encodedMessage = Uri.encodeComponent(message);
              String whatsappUrl = "https://wa.me/?text=$encodedMessage";

              // Launch WhatsApp
              if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                await launchUrl(Uri.parse(whatsappUrl),
                    mode: LaunchMode.externalApplication);
              } else {
                // Fallback: show error message
                if (context.mounted) {
                  showScaffoldError(
                    context: context,
                    message:
                        'Could not open WhatsApp. Please make sure WhatsApp is installed.',
                  );
                }
              }
            } catch (error) {
              debugPrint('Error sharing invoice: $error');
              if (context.mounted) {
                showScaffoldError(
                  context: context,
                  message: 'Error sharing invoice. Please try again.',
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(SalesProvider provider) {
    final hasFilters = orderNumberController.text.isNotEmpty ||
        customerNameController.text.isNotEmpty ||
        amountController.text.isNotEmpty ||
        emailController.text.isNotEmpty ||
        phoneController.text.isNotEmpty ||
        storeController.text.isNotEmpty ||
        selectedDate != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            provider.orders.isEmpty
                ? "No orders available"
                : "No orders match your filters",
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters)
            TextButton(
              onPressed: resetSearch,
              child: const Text("Reset filters"),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTable(SalesProvider provider) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
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
                0: FixedColumnWidth(1), // SI No
                1: FlexColumnWidth(2), // Order #
                2: FlexColumnWidth(2), // Date
                3: FlexColumnWidth(1.5), // Items
                4: FlexColumnWidth(3), // Customer
                5: FlexColumnWidth(2), // Amount
                6: FlexColumnWidth(1.8), // Status
                7: FixedColumnWidth(150), // Actions
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('SI No'),
                    _buildTableHeader('Order #'),
                    _buildTableHeader('Date'),
                    _buildTableHeader('Items'),
                    _buildTableHeader('Customer'),
                    _buildTableHeader('Amount'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Actions'),
                  ],
                ),
              ],
            ),
          ),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(1), // SI No
                      1: FlexColumnWidth(2), // Order #
                      2: FlexColumnWidth(2), // Date
                      3: FlexColumnWidth(1.5), // Items
                      4: FlexColumnWidth(3), // Customer
                      5: FlexColumnWidth(2), // Amount
                      6: FlexColumnWidth(1.8), // Status
                      7: FixedColumnWidth(150), // Actions
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...provider.orders.asMap().entries.map((entry) {
                        int index = entry.key;
                        ListOrderModelData order = entry.value;
                        PriceSummary priceSummary =
                            order.priceSummary ?? PriceSummary();

                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            SizedBox(
                              height: 55, // Set your desired row height here
                              child: _buildTableCell("${index + 1}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell("#${order.orderNumber}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  DateHelper.formatYearMonthDay(
                                      order.orderDate!)),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  "${order.cartItems?.length ?? 0}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  "${order.customerName ?? "NA"}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  "Rs ${AmountHelper.formatAmount(priceSummary.grandTotal ?? 0.0)}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: _buildStatusChip(
                                      order.status ?? "pending")),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: _buildActionButtons(order, context)),
                            ),
                          ],
                        );
                        ;
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      "Orders List",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Search and Filter Section (keep your existing search UI)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
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
                                      onchanged: (value) {
                                        if (value!.isEmpty ||
                                            value.length > 2) {
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
                              const SizedBox(width: 10),
                              Expanded(
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
                                      onchanged: (value) {
                                        if (value!.isEmpty ||
                                            value.length > 2) {
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
                              const SizedBox(width: 10),
                              Expanded(
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
                                      onchanged: (value) {
                                        if (value!.isEmpty ||
                                            value.length > 2) {
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
                              const SizedBox(width: 10),
                              Expanded(
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
                                      child: Center(
                                        child: CalendarPickerTableCell(
                                          key: calendarPickerKey,
                                          onDateSelected: (DateTime date) {
                                            setState(() {
                                              selectedDate = date;
                                            });
                                            searchOrders(1);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: [
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
                                      onchanged: (value) {
                                        if (value!.isEmpty ||
                                            value.length > 2) {
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
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 0),
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        child: DropdownButtonFormField<
                                            GetStoreModelData>(
                                          decoration: const InputDecoration(
                                              border: InputBorder.none),
                                          value: storeSelected,
                                          hint: Text(
                                            'Select Store',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ),
                                          items: [
                                            DropdownMenuItem<GetStoreModelData>(
                                              value: null,
                                              child: Text(
                                                'All Stores',
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            ),
                                            ...storeList!
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
                                                ),
                                              );
                                            }).toList()
                                          ],
                                          onChanged: (GetStoreModelData?
                                              storeModelData) {
                                            setState(() {
                                              storeSelected = storeModelData;
                                              if (storeModelData != null) {
                                                storeController.text =
                                                    storeModelData.id
                                                        .toString();
                                              } else {
                                                storeController.clear();
                                              }
                                            });
                                            searchOrders(1);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                const SizedBox(height: 20),
                Expanded(
                  child: Consumer<SalesProvider>(
                    builder: (context, orderProvider, child) {
                      if (initLoading) {
                        // Changed from checking orderProvider.isLoading
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (orderProvider.orders.isEmpty) {
                        return _buildEmptyState(orderProvider);
                      }

                      return Column(
                        children: [
                          Expanded(child: _buildOrderTable(orderProvider)),
                          PaginationControl(
                            currentPage: orderProvider.currentPage,
                            totalPages: orderProvider.totalPages,
                            onPageChanged: (int page) {
                              debugPrint('=== PAGINATION CLICKED ===');
                              debugPrint('User clicked page: $page');
                              debugPrint(
                                  'Current provider page: ${orderProvider.currentPage}');
                              debugPrint(
                                  'Total pages: ${orderProvider.totalPages}');
                              searchOrders(page);
                            },
                          ),
                        ],
                      );
                    },
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
