import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'; // Add this import for PointerDeviceKind
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../models/list_sales_order.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';

import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  GetStoreModelData? storeSelected;
  DateTime? selectedDate;
  TextEditingController quantityController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController selectedProductIdController = TextEditingController();

  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  final GlobalKey _autocompleteProductKey = GlobalKey();
  final GlobalKey _autocompletePhoneKey = GlobalKey();
  bool isCustomerFound = false;
  String? mobileNumberText = "";
  int? selectedCustomerID;
  String? selectedCustomerPhone;
  CustomerListModelData? selectedCustomer;
  Map<int, bool> hoverMap = {};
  String? selectedOrderId;
  String? selectedOrderNumber;
  bool isOrderSelected = false;
  bool initLoading = false;
  List<SalesReturnCart> _salesReturnItems = [];

  // Payment related variables
  String selectedPaymentMethod = 'CASH';
  TextEditingController paidAmountController = TextEditingController();
  bool hasPayment = true;
  final List<String> paymentMethods = ['CASH', 'CARD', 'UPI'];
  bool isCompletingReturn = false;

  @override
  void initState() {
    // Check if there's an order number passed from sales screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final passedOrderNumber = salesProvider.getOrderNumber;
      final passedOrderId = salesProvider.getOrderId;

      debugPrint('Checking for passed order number: $passedOrderNumber');

      if (passedOrderNumber.isNotEmpty) {
        debugPrint('Found order number from sales page: $passedOrderNumber');

        setState(() {
          orderNumberController.text = passedOrderNumber;
          selectedOrderId = passedOrderId;
          selectedOrderNumber = passedOrderNumber;
          isOrderSelected = true;
          initLoading = true;
        });

        try {
          // Get access token
          String? accessToken =
              Provider.of<AuthModel>(context, listen: false).token;

          // Directly fetch the specific order by order number
          await Provider.of<SalesProvider>(context, listen: false).fetchOrders(
            accessToken: accessToken ?? '',
            orderNumber: passedOrderNumber,
            page: 1,
          );

          // Load the order details
          await getOrderDetails(passedOrderNumber);

          // Clear the provider values to prevent reloading on future navigation
          salesProvider.setOrderNumber("");
          salesProvider.setOrderId("");
        } catch (e) {
          debugPrint('Error loading specific order: $e');
        } finally {
          if (mounted) {
            setState(() {
              initLoading = false;
            });
          }
        }
      } else {
        // If no order number passed, load initial data
        loadInitData();
      }
    });

    super.initState();
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
    } catch (error, stackTrace) {
      debugPrint('Error in loadInitData: $error');
      debugPrint('Stack Trace for loadInitData: $stackTrace');
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

      // Store current selection state
      bool wasOrderSelected = isOrderSelected;
      String? prevSelectedOrderId = selectedOrderId;
      String? prevSelectedOrderNumber = selectedOrderNumber;

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        orderNumber: orderNumberController.text,
        customerId: selectedCustomerID,
        date: selectedDate != null ? DateHelper.formatDate(selectedDate!) : '',
        page: page,
      );

      // Restore selection state if we came from the sales page
      if (wasOrderSelected && prevSelectedOrderId != null) {
        debugPrint('Restoring selected order: $prevSelectedOrderNumber');

        setState(() {
          isOrderSelected = true;
          selectedOrderId = prevSelectedOrderId;
          selectedOrderNumber = prevSelectedOrderNumber;
        });

        // Load the order details for the selected order
        if (prevSelectedOrderNumber != null &&
            prevSelectedOrderNumber.isNotEmpty) {
          getOrderDetails(prevSelectedOrderNumber);
        }
      } else {
        setState(() {
          initLoading = false;
          isOrderSelected = false;
          selectedOrderId = null;
          selectedOrderNumber = null;
          orderDetailsModelData = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Error in searchOrders: $error');
      debugPrint('Stack Trace for searchOrders: $stackTrace');
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
      isOrderSelected = false;
      selectedOrderId = null;
      selectedOrderNumber = null;
      orderDetailsModelData = null;
    });
    loadInitData();
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  Future<void> getOrderDetails(String ordersId) async {
    debugPrint("Starting getOrderDetails for order ID: $ordersId");
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      // Make sure we have a valid order ID
      if (ordersId.isEmpty) {
        debugPrint("Empty order ID provided to getOrderDetails");
        return;
      }

      debugPrint("Fetching sales return items for order ID: $ordersId");

      // Show loading indicator
      setState(() {
        initLoading = true;
      });

      await Provider.of<SalesProvider>(context, listen: false)
          .fetchSalesReturnItems(
              orderId: ordersId, accessToken: accessToken ?? "");

      // Update the local list with the fetched items
      _salesReturnItems =
          Provider.of<SalesProvider>(context, listen: false).salesReturnItems;

      debugPrint('Fetched ${_salesReturnItems.length} sales return items');

      // If we have items, ensure the order is marked as selected
      if (_salesReturnItems.isNotEmpty) {
        setState(() {
          isOrderSelected = true;
          selectedOrderNumber = ordersId;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Error in getOrderDetails for order ID $ordersId: $error');
      debugPrint('Stack Trace for getOrderDetails: $stackTrace');
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    final SideBarController sideBarController = Get.put(SideBarController());
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBackButton(
                        onPressed: () {
                          sideBarController.index.value = 50;
                        },
                        text: 'Sales Return List',
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            "Sales Return",
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s20, 0.30, ColorManager.textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  // Search and filters section commented out
                  // SizedBox(
                  //   height: 100,
                  //   child: ListView(
                  //     scrollDirection: Axis.horizontal,
                  //     physics: const BouncingScrollPhysics(),
                  //     children: [
                  //       Padding(
                  //         padding: const EdgeInsets.only(left: 10.0),
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Padding(
                  //               padding: const EdgeInsets.all(8.0),
                  //               child: Text(
                  //                 "Order Number",
                  //                 style: buildCustomStyle(
                  //                   FontWeightManager.regular,
                  //                   FontSize.s14,
                  //                   0.27,
                  //                   Colors.black.withOpacity(0.6),
                  //                 ),
                  //               ),
                  //             ),
                  //             buildColumnWidgetForTextFields(
                  //               height: 50,
                  //               width: 120,
                  //               onchanged: (value) {},
                  //               controller: orderNumberController,
                  //               size: size,
                  //               hintText: 'Order Number',
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //       // Date
                  //       Padding(
                  //         padding: const EdgeInsets.only(left: 10.0),
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Padding(
                  //               padding: const EdgeInsets.all(8.0),
                  //               child: Text(
                  //                 "Date",
                  //                 style: buildCustomStyle(
                  //                   FontWeightManager.regular,
                  //                   FontSize.s14,
                  //                   0.27,
                  //                   Colors.black.withOpacity(0.6),
                  //                 ),
                  //               ),
                  //             ),
                  //             BuildBoxShadowContainer(
                  //               circleRadius: 7,
                  //               height: 50,
                  //               width: 150,
                  //               child: Center(
                  //                 child: CalendarPickerTableCell(
                  //                   onDateSelected: (DateTime date) {
                  //                     selectedDate = date;
                  //                   },
                  //                 ),
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //       SizedBox(
                  //         width: 200,
                  //         child: Padding(
                  //           padding: const EdgeInsets.only(left: 10.0, top: 35),
                  //           child: ProductAutocomplete(
                  //             autocompleteProductKey: _autocompleteProductKey,
                  //             size: size,
                  //             onSelected: (GetProduct selectedProduct,
                  //                 Stock? selectedStock) {},
                  //             productList: productProvider.productList!,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // SizedBox(
                  //   height: 90,
                  //   child: ListView(
                  //     scrollDirection: Axis.horizontal,
                  //     physics: const BouncingScrollPhysics(),
                  //     children: [
                  //       Padding(
                  //         padding: const EdgeInsets.only(left: 15.0),
                  //         child: SizedBox(
                  //           height: size.height * .07,
                  //           width: 215,
                  //           child: _buildMobileNumberInput(size: size),
                  //         ),
                  //       ),
                  //       Padding(
                  //         padding: const EdgeInsets.only(left: 10.0, top: 25),
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           mainAxisAlignment: MainAxisAlignment.start,
                  //           children: [
                  //             CustomRoundButton(
                  //               title: "Search",
                  //               fct: () {
                  //                 searchOrders(1);
                  //               },
                  //               height: 45,
                  //               width: size.width * 0.09,
                  //               fontSize: FontSize.s12,
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //       Padding(
                  //         padding: const EdgeInsets.only(left: 10.0, top: 25),
                  //         child: Column(
                  //           children: [
                  //             CustomRoundButton(
                  //               title: "Reset",
                  //               boxColor: Colors.white,
                  //               textColor: ColorManager.kPrimaryColor,
                  //               fct: resetSearch,
                  //               height: 45,
                  //               width: size.width * 0.09,
                  //               fontSize: FontSize.s12,
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(
                    height: 20,
                  ),
                  // Enhanced Order Details Card
                  Consumer<SalesProvider>(
                    builder: (context, orderProvider, child) {
                      List<ListOrderModelData> orders = orderProvider.orders;

                      if (isOrderSelected && orders.isNotEmpty) {
                        try {
                          // Find the selected order
                          final order = orders.firstWhere(
                            (order) =>
                                order.orderNumber.toString() ==
                                selectedOrderNumber,
                            orElse: () => orders.firstWhere(
                              (order) => order.id.toString() == selectedOrderId,
                              orElse: () => ListOrderModelData(
                                id: int.tryParse(selectedOrderId ?? "0"),
                                orderNumber: selectedOrderNumber,
                                orderDate: DateTime.now(),
                                customerName: "Order #$selectedOrderNumber",
                              ),
                            ),
                          );

                          return BuildBoxShadowContainer(
                            circleRadius: 12,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(20),
                            color: Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'ORDER DETAILS',
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s12,
                                          0.25,
                                          ColorManager.kPrimaryColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Colors.green.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Selected',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s10,
                                              0.25,
                                              Colors.green.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Order Number',
                                        '${order.orderNumber}',
                                        Icons.receipt_long,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Date',
                                        DateHelper.formatDate(order.orderDate ?? DateTime.now()),
                                        Icons.calendar_today,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Customer',
                                        order.customerName ?? "N/A",
                                        Icons.person,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error displaying selected order: $e');
                          return BuildBoxShadowContainer(
                            circleRadius: 12,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(20),
                            color: Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'ORDER DETAILS',
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s12,
                                          0.25,
                                          ColorManager.kPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Order Number',
                                        '$selectedOrderNumber',
                                        Icons.receipt_long,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Date',
                                        DateHelper.formatDate(DateTime.now()),
                                        Icons.calendar_today,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildOrderDetailItem(
                                        'Customer',
                                        'Order #$selectedOrderNumber',
                                        Icons.person,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      } else {
                        return BuildBoxShadowContainer(
                          circleRadius: 12,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(20),
                          color: Colors.grey.shade50,
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Order Selected',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.27,
                                  Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please select an order to view details and process returns',
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s12,
                                  0.25,
                                  Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  // PaginationControl(
                  //   currentPage:
                  //       Provider.of<SalesProvider>(context, listen: true)
                  //           .currentPage,
                  //   totalPages:
                  //       Provider.of<SalesProvider>(context, listen: true)
                  //           .totalPages,
                  //   onPageChanged: (int page) {
                  //     searchOrders(page);
                  //   },
                  // ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Order Items",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, ColorManager.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  // Wrap the order details in a SizedBox with fixed height
                  SizedBox(
                    height: 300, // Set a fixed height for the table
                    child: _buildOrderDetails(),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  // Summary sections
                  _buildSummarySection(),
                  const SizedBox(
                    height: 20,
                  ),
                  // Payment Details Section
                  _buildPaymentDetailsSection(),
                  const SizedBox(
                    height: 20,
                  ),
                  _buildCompleteReturnButton(size),
                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            )),
      ),
    );
  }

  // _buildOrderCard method commented out since it's no longer used
  // Widget _buildOrderCard(
  //   BuildContext context, {
  //   required String orderId,
  //   required String orderNumber,
  //   required String date,
  //   required String customer,
  // }) {
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         selectedOrderId = orderId; // Set the selected order ID
  //         selectedOrderNumber = orderNumber;
  //         isOrderSelected = true; // Update the selection state
  //       });
  //       getOrderDetails(orderNumber);
  //       // debugPrint('Card tapped for Order ID: $orderId');
  //     },
  //     child: Card(
  //       elevation: 1,
  //       margin: const EdgeInsets.all(8),
  //       child: BuildBoxShadowContainer(
  //         circleRadius: 7,
  //         width: 250,
  //         padding: const EdgeInsets.all(16),
  //         color: Colors.white,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Text(
  //               'Order Number: $orderNumber',
  //               style: const TextStyle(fontSize: 14),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'Date: ${DateHelper.formatDate(DateTime.parse(date))}',
  //               style: const TextStyle(fontSize: 14),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'Customer: $customer',
  //               style: const TextStyle(fontSize: 14),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // _buildMobileNumberInput method commented out since search functionality is removed
  // Widget _buildMobileNumberInput({
  //   required Size size,
  // }) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.start,
  //     crossAxisAlignment: CrossAxisAlignment.center,
  //     children: [
  //       Expanded(
  //         child: BuildBoxShadowContainer(
  //           circleRadius: 7,
  //           alignment: Alignment.centerLeft,
  //           margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
  //           padding: const EdgeInsets.only(left: 15),
  //           height: size.height * .07,
  //           width: size.width / 3,
  //           child: Autocomplete<CustomerListModelData>(
  //             key: _autocompletePhoneKey, // Set the key here
  //             optionsBuilder: (mobileNumberTextController) async {
  //               // debugPrint(mobileNumberTextController.text);
  //               if (mobileNumberTextController.text.isEmpty) {
  //                 setState(() {
  //                   isCustomerFound = false; // Reset validity
  //                 });
  //                 return const Iterable<CustomerListModelData>.empty();
  //               }
  //
  //               String? accessToken =
  //                   Provider.of<AuthModel>(context, listen: false).token;
  //               // debugPrint("accessToken From AuthModel $accessToken");
  //               // debugPrint(mobileNumberTextController.text);
  //
  //               try {
  //                 final response = await CustomerProvider().findCustomerByPhone(
  //                     accessToken ?? "",
  //                     mobileNumberTextController.text,
  //                     context);
  //
  //                 if (response["status"] == "success") {
  //                   CustomerListModel customerListModel =
  //                       CustomerListModel.fromJson(response);
  //                   List<CustomerListModelData>? filteredCustomerList =
  //                       customerListModel.data;
  //
  //                   if (mobileNumberTextController.text.length == 10 &&
  //                       filteredCustomerList!.length == 1) {
  //                     setState(() {
  //                       isCustomerFound = true;
  //                     });
  //                   } else {
  //                     setState(() {
  //                       isCustomerFound = false;
  //                     });
  //                   }
  //
  //                   return filteredCustomerList!.isNotEmpty
  //                       ? filteredCustomerList
  //                       : const Iterable<CustomerListModelData>.empty();
  //                 } else {
  //                   // debugPrint('Error in response: ${response["message"]}');
  //                 }
  //               } catch (error, stackTrace) {
  //                 debugPrint('Exception caught: $error');
  //                 debugPrint(
  //                     'Stack Trace for findCustomerByPhone: $stackTrace');
  //               }
  //               setState(() {
  //                 isCustomerFound = false;
  //               });
  //               return const Iterable<
  //                   CustomerListModelData>.empty(); // Return empty if no customers found
  //             },
  //             displayStringForOption: (CustomerListModelData customer) =>
  //                 "${customer.name} ${customer.phone}",
  //             onSelected: (CustomerListModelData selection) {
  //               String? accessToken =
  //                   Provider.of<AuthModel>(context, listen: false).token;
  //               // debugPrint("accessToken From AuthModel $accessToken");
  //               Provider.of<CartProvider>(context, listen: false)
  //                   .fetchCartDataFromApi(
  //                       customerId: selection.id ?? 0,
  //                       accessToken: accessToken ?? '');
  //               setState(() {
  //                 mobileNumberText = "";
  //                 selectedCustomerID = selection.id!;
  //                 selectedCustomerPhone = selection.phone;
  //                 selectedCustomer = selection;
  //               });
  //             },
  //             fieldViewBuilder: (BuildContext context,
  //                 TextEditingController mobileNumberTextController,
  //                 FocusNode focusNode,
  //                 VoidCallback onFieldSubmitted) {
  //               return TextField(
  //                 controller: mobileNumberTextController,
  //                 focusNode: focusNode,
  //                 decoration: InputDecoration(
  //                   hintText: 'Enter mobile number',
  //                   hintStyle: buildCustomStyle(
  //                     FontWeight.w500,
  //                     12,
  //                     0.27,
  //                     Colors.grey.withOpacity(.5),
  //                   ),
  //                   border: InputBorder.none,
  //                 ),
  //                 onChanged: (value) {
  //                   setState(() {
  //                     mobileNumberText = value;
  //                     selectedCustomerID = null;
  //                     selectedCustomerPhone = null;
  //                     selectedCustomer = null;
  //                   });
  //                 },
  //                 style: buildCustomStyle(
  //                   FontWeight.w500,
  //                   12,
  //                   0.27,
  //                   Colors.black.withOpacity(.5),
  //                 ),
  //               );
  //             },
  //             optionsViewBuilder: (BuildContext context,
  //                 AutocompleteOnSelected<CustomerListModelData> onSelected,
  //                 Iterable<CustomerListModelData> options) {
  //               return Align(
  //                 alignment: Alignment.topLeft,
  //                 child: Material(
  //                   elevation: 4,
  //                   child: Container(
  //                     width: MediaQuery.of(context).size.width / 3,
  //                     color: Colors.white,
  //                     constraints: const BoxConstraints(maxHeight: 200),
  //                     child: ListView.builder(
  //                       padding: const EdgeInsets.all(8.0),
  //                       shrinkWrap: true,
  //                       physics: const BouncingScrollPhysics(),
  //                       itemCount: options.length,
  //                       itemBuilder: (BuildContext context, int index) {
  //                         final CustomerListModelData option =
  //                             options.elementAt(index);
  //                         return MouseRegion(
  //                           onEnter: (_) {
  //                             setState(() {
  //                               hoverMap[index] = true;
  //                             });
  //                           },
  //                           onExit: (_) {
  //                             setState(() {
  //                               hoverMap[index] = false;
  //                             });
  //                           },
  //                           child: GestureDetector(
  //                             onTap: () {
  //                               onSelected(option);
  //                             },
  //                             child: Container(
  //                               color: hoverMap[index] == true
  //                                   ? Colors.grey[200]
  //                                   : Colors.white,
  //                               child: ListTile(
  //                                 title: Text(
  //                                   "${option.name} ${option.phone}",
  //                                   style: buildCustomStyle(
  //                                     FontWeight.w500,
  //                                     12,
  //                                     0.27,
  //                                     Colors.black.withOpacity(.5),
  //                                   ),
  //                                 ),
  //                                 hoverColor: Colors.grey[200],
  //                               ),
  //                             ),
  //                           ),
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  void _showReturnDialog(
    BuildContext context, {
    required String productName,
    required String unitPrice,
    required String orderId,
    required int cartItemId,
    required String currency,
    required String totalPrice,
    required String quantity,
  }) {
    debugPrint('_showReturnDialog called with:');
    debugPrint('  productName: $productName');
    debugPrint('  unitPrice: $unitPrice');
    debugPrint('  orderId: $orderId');
    debugPrint('  cartItemId: $cartItemId');
    debugPrint('  currency: $currency');
    debugPrint('  totalPrice: $totalPrice');
    debugPrint('  quantity: $quantity');
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController returnTotalController = TextEditingController();
    final maxQuantity = double.parse(quantity);
    final unitPriceValue = double.parse(unitPrice);
    final maxTotal = maxQuantity * unitPriceValue;

    // Update total when quantity changes
    quantityController.addListener(() {
      if (quantityController.text.isEmpty) return;

      final enteredQuantity = int.tryParse(quantityController.text) ?? 0;

      // If entered quantity exceeds max, reset to max
      if (enteredQuantity > maxQuantity) {
        quantityController.text = maxQuantity.toString();
        quantityController.selection = TextSelection.fromPosition(
          TextPosition(offset: quantityController.text.length),
        );
      }

      final total = enteredQuantity * unitPriceValue;
      returnTotalController.text = total.toStringAsFixed(2);
    });

    // Update quantity when total changes
    returnTotalController.addListener(() {
      if (returnTotalController.text.isEmpty) return;

      final enteredTotal = double.tryParse(returnTotalController.text) ?? 0.0;

      // If entered total exceeds max, reset to max
      if (enteredTotal > maxTotal) {
        returnTotalController.text = maxTotal.toStringAsFixed(2);
        returnTotalController.selection = TextSelection.fromPosition(
          TextPosition(offset: returnTotalController.text.length),
        );
      }

      // Calculate and update quantity based on total
      final calculatedQuantity = (enteredTotal / unitPriceValue).floor();
      if (calculatedQuantity <= maxQuantity) {
        quantityController.text = calculatedQuantity.toString();
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Return $orderId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3, // Larger flex for product name
                              child: Text(
                                'Product name',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Price',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Total Price',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Order Quantity',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3, // Match the flex with header
                              child: Text(
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '$currency $unitPrice',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '$currency $totalPrice',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                quantity,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      helperText: 'Maximum quantity: $maxQuantity',
                      errorText: int.tryParse(quantityController.text) !=
                                  null &&
                              int.parse(quantityController.text) > maxQuantity
                          ? 'Cannot exceed original quantity'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final intValue = int.tryParse(newValue.text);
                        if (intValue == null || intValue <= maxQuantity) {
                          return newValue;
                        }
                        return oldValue;
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: returnTotalController,
                    decoration: InputDecoration(
                      labelText: 'Return Total',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      prefixText: '$currency ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final doubleValue = double.tryParse(newValue.text);
                        if (doubleValue == null || doubleValue <= maxTotal) {
                          return newValue;
                        }
                        return oldValue;
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          // if (reasonController.text.isEmpty) {
                          //   showScaffoldError(
                          //     context: context,
                          //     message: 'Please enter reason',
                          //   );
                          //   return;
                          // }
                          try {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;

                            await Provider.of<SalesProvider>(context,
                                    listen: false)
                                .submitSalesReturn(
                              accessToken: accessToken ?? '',
                              orderId: int.parse(orderId),
                              price: double.parse(unitPrice),
                              quantity: int.parse(quantityController.text),
                              cartItemId: cartItemId,
                              reason: reasonController.text,
                            );

                            showScaffold(
                              context: context,
                              message: 'Sales Return Submitted Successfully',
                            );

                            getOrderDetails(selectedOrderNumber.toString());

                            Navigator.pop(context);
                          } catch (error, stackTrace) {
                            debugPrint('Error submitting sales return: $error');
                            debugPrint(
                                'Stack Trace for submitSalesReturn: $stackTrace');
                            showScaffoldError(
                              context: context,
                              message: 'Failed to submit sales return',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails() {
    return Consumer<SalesProvider>(builder: (context, salesProvider, child) {
      final salesReturnItems = salesProvider.salesReturnItems;

      if (salesReturnItems.isEmpty) {
        return const Column(
          children: [
            Center(child: Text("No return items available.")),
            SizedBox(height: 50),
          ],
        );
      }

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
                  0: FlexColumnWidth(3), // Product Name
                  1: FlexColumnWidth(1), // Quantity
                  2: FlexColumnWidth(1.5), // Unit Price
                  3: FlexColumnWidth(1.5), // Total Price
                  4: FlexColumnWidth(1.5), // Returned Quantity
                  5: FlexColumnWidth(1.5), // Returned Total
                  6: FlexColumnWidth(1), // Returned
                  7: FlexColumnWidth(1.5), // Action
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildTableHeader('Product Name'),
                      _buildTableHeader('Quantity'),
                      _buildTableHeader('Unit Price'),
                      _buildTableHeader('Total Price'),
                      _buildTableHeader('Returned Qty'),
                      _buildTableHeader('Returned Total'),
                      _buildTableHeader('Status'),
                      _buildTableHeader('Action'),
                    ],
                  ),
                ],
              ),
            ),
            // Replace Expanded with Container having a fixed height
            Container(
              height: 200, // Fixed height for the table body
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
                        0: FlexColumnWidth(3), // Product Name
                        1: FlexColumnWidth(1), // Quantity
                        2: FlexColumnWidth(1.5), // Unit Price
                        3: FlexColumnWidth(1.5), // Total Price
                        4: FlexColumnWidth(1.5), // Returned Quantity
                        5: FlexColumnWidth(1.5), // Returned Total
                        6: FlexColumnWidth(1), // Returned
                        7: FlexColumnWidth(1.5), // Action
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        ...salesReturnItems.asMap().entries.map((entry) {
                          int index = entry.key;
                          SalesReturnCart item = entry.value;
                          return TableRow(
                            decoration: BoxDecoration(
                              color: index % 2 == 0
                                  ? Colors.white
                                  : Colors.grey.withOpacity(0.1),
                            ),
                            children: [
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(item.productName),
                              ),
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(item.quantity),
                              ),
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(item.unitPrice),
                              ),
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(item.totalPrice),
                              ),
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(
                                    item.returnedQuantity.toString()),
                              ),
                              SizedBox(
                                height: 55,
                                child: _buildTableCell(
                                    item.returnedTotal.toString()),
                              ),
                              SizedBox(
                                height: 55,
                                child: Center(
                                  child: Icon(
                                    item.isReturned
                                        ? Icons.pending
                                        : Icons.cancel,
                                    color: item.isReturned
                                        ? Colors.amber
                                        : Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 55,
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      _showReturnDialog(
                                        context,
                                        productName:
                                            item.productName.toString(),
                                        unitPrice: item.unitPrice.toString(),
                                        orderId: selectedOrderId.toString(),
                                        cartItemId: item.cartItemId,
                                        currency: '',
                                        totalPrice: item.totalPrice.toString(),
                                        quantity: item.quantity.toString(),
                                      );
                                    },
                                    child: const Text("Return"),
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
    });
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
          FontSize.s9,
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildCompleteReturnButton(Size size) {
    final SideBarController sideBarController = Get.put(SideBarController());

    return CustomRoundButton(
      title: "Create Sales Return",
      fct: () async {
        debugPrint('Return Order ID: $selectedOrderId');

        // Check if there are any items with return_order_id
        if (_salesReturnItems.isEmpty) {
          showScaffoldError(
            context: context,
            message: 'No return items available',
          );
          return;
        }

        // Find the first item with a valid return_order_id
        final validReturnItem = _salesReturnItems.firstWhere(
          (item) => item.returnOrderId != 0,
          orElse: () => _salesReturnItems.first,
        );

        if (validReturnItem.returnOrderId == 0) {
          showScaffoldError(
            context: context,
            message:
                'No valid return order ID found. Please submit return items first.',
          );
          return;
        }

        try {
          String? accessToken =
              Provider.of<AuthModel>(context, listen: false).token;

          // Validate payment details if payment is enabled
          if (hasPayment) {
            if (paidAmountController.text.isEmpty) {
              showScaffoldError(
                context: context,
                message: 'Please enter the return amount',
              );
              return;
            }

            double paidAmount = double.tryParse(paidAmountController.text) ?? 0.0;

            // Calculate maximum returnable amount
            double maxReturnAmount = 0.0;
            for (var item in _salesReturnItems) {
              final itemReturned = double.tryParse(item.returnedTotal.toString()) ?? 0.0;
              maxReturnAmount += itemReturned;
            }

            if (paidAmount <= 0) {
              showScaffoldError(
                context: context,
                message: 'Return amount must be greater than 0',
              );
              return;
            }

            if (paidAmount > maxReturnAmount) {
              showScaffoldError(
                context: context,
                message: 'Return amount cannot exceed ₹${maxReturnAmount.toStringAsFixed(2)}',
              );
              return;
            }
          }

          // Parse paid amount
          double paidAmount = 0.0;
          if (hasPayment && paidAmountController.text.isNotEmpty) {
            paidAmount = double.tryParse(paidAmountController.text) ?? 0.0;
          }

          setState(() {
            isCompletingReturn = true;
          });

          await Provider.of<SalesProvider>(context, listen: false)
              .completeSalesReturn(
            accessToken: accessToken ?? '',
            returnOrderId: validReturnItem.returnOrderId,
            paymentMethod: hasPayment ? selectedPaymentMethod : null,
            paidAmount: hasPayment ? paidAmount : null,
            hasPayment: hasPayment,
          );

          showScaffold(
            context: context,
            message: 'Sales Return Created Successfully',
          );

          sideBarController.index.value = 50;
        } catch (error, stackTrace) {
          debugPrint('Error creating sales return: $error');
          debugPrint('Stack Trace for completeSalesReturn: $stackTrace');
          showScaffoldError(
            context: context,
            message: 'Failed to create sales return',
          );
        } finally {
          if (mounted) {
            setState(() {
              isCompletingReturn = false;
            });
          }
        }
      },
      height: 40,
      width: size.width,
      fontSize: FontSize.s13,
      isLoading: isCompletingReturn,
    );
  }

  Widget _buildOrderDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: ColorManager.kPrimaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.25,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Consumer<SalesProvider>(builder: (context, salesProvider, child) {
      final salesReturnItems = salesProvider.salesReturnItems;
      
      if (salesReturnItems.isEmpty) {
        return const SizedBox.shrink();
      }

      // Calculate totals
      double orderTotal = 0.0;
      double returnedTotal = 0.0;
      int totalItems = salesReturnItems.length; // Count of distinct items
      int totalQuantity = 0; // Total quantity of all items
      int returnedItems = 0;
      int returnedQuantity = 0; // Total returned quantity

      for (var item in salesReturnItems) {
        final itemTotal = double.tryParse(item.totalPrice.toString()) ?? 0.0;
        final itemReturned = double.tryParse(item.returnedTotal.toString()) ?? 0.0;
        final itemQuantity = int.tryParse(item.quantity) ?? 0; // item.quantity is already a String
        
        debugPrint('Item: ${item.productName}, Quantity: ${item.quantity}, Parsed: $itemQuantity');
        
        orderTotal += itemTotal;
        returnedTotal += itemReturned;
        totalQuantity += itemQuantity;
        returnedQuantity += item.returnedQuantity;
        
        if (item.returnedQuantity > 0) {
          returnedItems += 1; // Count items that have been returned
        }
      }

      return Row(
        children: [
          // Order Summary
          Expanded(
            child: BuildBoxShadowContainer(
              circleRadius: 12,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Order Summary',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.25,
                          Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Total Items', '$totalItems'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Total Quantity', '$totalQuantity'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Order Total', '₹${orderTotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          // Return Summary
          Expanded(
            child: BuildBoxShadowContainer(
              circleRadius: 12,
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.assignment_return,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Return Summary',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.25,
                          Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Returned Items', '$returnedItems'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Returned Quantity', '$returnedQuantity'),
                  const SizedBox(height: 6),
                  _buildSummaryRow('Return Total', '₹${returnedTotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.25,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.25,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Consumer<SalesProvider>(builder: (context, salesProvider, child) {
      final salesReturnItems = salesProvider.salesReturnItems;
      
      if (salesReturnItems.isEmpty) {
        return const SizedBox.shrink();
      }

      // Calculate return total
      double returnedTotal = 0.0;
      for (var item in salesReturnItems) {
        final itemReturned = double.tryParse(item.returnedTotal.toString()) ?? 0.0;
        returnedTotal += itemReturned;
      }

      return BuildBoxShadowContainer(
        circleRadius: 12,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Payment Details',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.25,
                    Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Has Payment:',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.25,
                        Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: hasPayment,
                      onChanged: (value) {
                        setState(() {
                          hasPayment = value;
                          if (!hasPayment) {
                            paidAmountController.clear();
                          }
                        });
                      },
                      activeColor: ColorManager.kPrimaryColor,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasPayment)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Payment Mode: Items will be returned without any payment transaction. No voucher or payment records will be created.',
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.25,
                          Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (hasPayment) ...[
              Row(
                children: [
                  // Payment Method Selection
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.25,
                            Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: DropdownButtonFormField<String>(
                            value: selectedPaymentMethod,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s14,
                              0.25,
                              ColorManager.textColor,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              constraints: const BoxConstraints.tightFor(height: 48),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                                borderSide: BorderSide(color: ColorManager.kPrimaryColor),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            iconSize: 20,
                            items: paymentMethods.map((String method) {
                              return DropdownMenuItem<String>(
                                value: method,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getPaymentMethodIcon(method),
                                      size: 16,
                                      color: ColorManager.kPrimaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      method,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s14,
                                        0.25,
                                        ColorManager.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedPaymentMethod = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Return Amount
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Amount',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.25,
                            Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: TextFormField(
                            controller: paidAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '₹${returnedTotal.toStringAsFixed(2)}',
                              prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              constraints: const BoxConstraints.tightFor(height: 48),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: ColorManager.kPrimaryColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s14,
                              0.25,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Maximum returnable amount: ₹${returnedTotal.toStringAsFixed(2)}',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'CASH':
        return Icons.money;
      case 'CARD':
        return Icons.credit_card;
      case 'UPI':
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }
}
