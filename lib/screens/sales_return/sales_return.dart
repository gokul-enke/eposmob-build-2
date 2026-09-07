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
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/helpers/sales_return_calculation_helper.dart';
import 'package:pos_machine/helpers/sales_return_order_id_helper.dart';
import 'package:pos_machine/models/sales_return_refund_breakdown.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'widgets/sales_return_responsive.dart';

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
  int? _activeReturnOrderId;

  // Payment related variables
  String selectedPaymentMethod = 'CASH';
  TextEditingController paidAmountController = TextEditingController();
  FocusNode paidAmountFocusNode = FocusNode();
  bool hasPayment = false;
  bool _deliveryChargeRefundable = false;
  final List<String> paymentMethods = ['CASH', 'CARD', 'UPI'];
  bool isCompletingReturn = false;
  String? _initLoadError;

  // Track initial state to calculate session-specific returns
  Map<int, double> _initialReturnedQuantities =
      {}; // cartItemId -> initial returned quantity
  Map<int, double> _initialReturnedTotals =
      {}; // cartItemId -> initial returned total

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

          debugPrint('✅ Initial order loaded and baseline state saved');
        } catch (e) {
          debugPrint('Error loading specific order: $e');
          if (mounted) {
            _initLoadError = e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'sales_return_form.error_failed_load_order'.tr;
            showScaffoldError(context: context, message: _initLoadError!);
          }
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

    // Select-all behavior when focusing the return amount field
    paidAmountFocusNode.addListener(() {
      if (paidAmountFocusNode.hasFocus) {
        paidAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: paidAmountController.text.length,
        );
      }
    });

    // Real-time validation: rebuild on amount changes
    paidAmountController.addListener(() {
      if (mounted) setState(() {});
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

      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getInt('active_store_id') ?? 1;

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        storeId: storeId,
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
      _activeReturnOrderId = null;
    });
    loadInitData();
  }

  Future<void> refreshData() async {
    if (selectedOrderNumber != null && selectedOrderNumber!.isNotEmpty) {
      await getOrderDetails(selectedOrderNumber!, resetInitialState: false);
    }
  }

  int? get _draftReturnOrderId =>
      SalesReturnOrderIdHelper.forCompletion(_activeReturnOrderId);

  bool get _canCompleteReturn =>
      !initLoading &&
      !isCompletingReturn &&
      isOrderSelected &&
      _draftReturnOrderId != null;

  Widget _buildLoadingOverlay() {
    if (!initLoading) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.75),
        child: const Center(
          child: CircularProgressIndicator(
            color: ColorManager.kPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStepHint() {
    if (!isOrderSelected || initLoading) return const SizedBox.shrink();

    final hasDraft = _draftReturnOrderId != null;
    final step2Ready = _canCompleteReturn;

    return SalesReturnStepBar(
      steps: [
        _buildStepChip('1', 'sales_return_form.step_return_items'.tr, active: true, done: hasDraft),
        Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
        _buildStepChip(
          '2',
          'sales_return_form.step_complete_return'.tr,
          active: step2Ready,
          done: false,
        ),
      ],
    );
  }

  Widget _buildStepChip(
    String number,
    String label, {
    required bool active,
    required bool done,
  }) {
    final color = done
        ? Colors.green
        : active
            ? ColorManager.kPrimaryColor
            : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color.withOpacity(0.15),
          child: done
              ? Icon(Icons.check, size: 12, color: color)
              : Text(
                  number,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.25,
            color,
          ),
        ),
      ],
    );
  }

  double _itemsTableHeight(int itemCount) {
    if (itemCount == 0) return 140;
    return (56.0 * itemCount + 52).clamp(160.0, 380.0);
  }

  Future<void> getOrderDetails(String ordersId,
      {bool resetInitialState = true}) async {
    debugPrint(
        "Starting getOrderDetails for order ID: $ordersId (resetInitialState: $resetInitialState)");
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

      // ALSO fetch full order details to get shipping cost, price summary etc.
      try {
        final orderDetailsResponse =
            await Provider.of<SalesProvider>(context, listen: false)
                .listOrderDetails(context, ordersId, accessToken ?? "");

        if (orderDetailsResponse["status"] == "success") {
          setState(() {
            final orderDetails =
                OrderDetailsModel.fromJson(orderDetailsResponse);
            orderDetailsModelData = orderDetails.data;
          });
          debugPrint('✅ Full order details fetched for $ordersId');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch full order details: $e');
        // Non-critical, continue with just return items
      }

      // Update the local list with the fetched items
      _salesReturnItems =
          Provider.of<SalesProvider>(context, listen: false).salesReturnItems;

      debugPrint('Fetched ${_salesReturnItems.length} sales return items');

      // Only reset initial state when loading a NEW order, not after individual return submissions
      if (resetInitialState) {
        _activeReturnOrderId = null;
        Provider.of<SalesProvider>(context, listen: false)
            .clearServerRefundBreakdown();
        _initialReturnedQuantities.clear();
        _initialReturnedTotals.clear();
        for (var item in _salesReturnItems) {
          _initialReturnedQuantities[item.cartItemId] = item.returnedQuantity;
          _initialReturnedTotals[item.cartItemId] =
              double.tryParse(item.returnedTotal.toString()) ?? 0.0;
        }
        debugPrint(
            '🔄 Reset initial return state for ${_initialReturnedQuantities.length} items');
      } else {
        debugPrint('✅ Refreshed items without resetting initial state');
      }

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
      if (mounted) {
        showScaffoldError(
          context: context,
          message: error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : 'sales_return_form.error_failed_load_items'.tr,
        );
      }
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
    paidAmountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    final SideBarController sideBarController = Get.put(SideBarController());
    final isPhone = salesReturnIsPhone(context);

    return SalesReturnScrollShell(
      onRefresh: refreshData,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: isPhone ? 4 : 8,
              vertical: isPhone ? 8 : 12,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: initLoading || isCompletingReturn
                        ? () {}
                        : () {
                            sideBarController.index.value = 50;
                          },
                    text: 'sales_return_form.btn_back'.tr,
                  ),
                  const SizedBox(height: 8),
                  SalesReturnPageHeader(
                    title: 'sales_return_form.page_title'.tr,
                    subtitle: isOrderSelected
                        ? 'sales_return_form.subtitle_selected'.tr
                        : 'sales_return_form.subtitle_no_order'.tr,
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
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
                height: 8,
              ),
              _buildStepHint(),
              // Enhanced Order Details Card
              Consumer<SalesProvider>(
                builder: (context, orderProvider, child) {
                  List<ListOrderModelData> orders = orderProvider.orders;

                  if (isOrderSelected && orders.isNotEmpty) {
                    try {
                      // Find the selected order
                      final order = orders.firstWhere(
                        (order) =>
                            order.orderNumber.toString() == selectedOrderNumber,
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

                      return SalesReturnContentCard(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsetsDirectional.all(isPhone ? 14 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SalesReturnLabelPill(
                                    label: 'sales_return_form.order_details_label'.tr),
                                const Spacer(),
                                Container(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
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
                                        'sales_return_form.order_selected_badge'.tr,
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
                            SalesReturnDetailGrid(
                              children: [
                                _buildOrderDetailItem(
                                  'sales_return_form.field_order_number'.tr,
                                  '${order.orderNumber}',
                                  Icons.receipt_long,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_date'.tr,
                                  DateHelper.formatDate(
                                      order.orderDate ?? DateTime.now()),
                                  Icons.calendar_today,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_customer'.tr,
                                  order.customerName ?? 'sales_return_form.na'.tr,
                                  Icons.person,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } catch (e) {
                      debugPrint('Error displaying selected order: $e');
                      return SalesReturnContentCard(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsetsDirectional.all(isPhone ? 14 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SalesReturnLabelPill(label: 'sales_return_form.order_details_label'.tr),
                            const SizedBox(height: 16),
                            SalesReturnDetailGrid(
                              children: [
                                _buildOrderDetailItem(
                                  'sales_return_form.field_order_number'.tr,
                                  '$selectedOrderNumber',
                                  Icons.receipt_long,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_date'.tr,
                                  DateHelper.formatDate(DateTime.now()),
                                  Icons.calendar_today,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_customer'.tr,
                                  'sales_return_form.order_ref'.trParams({'number': '$selectedOrderNumber'}),
                                  Icons.person,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  } else {
                    return SalesReturnContentCard(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: EdgeInsetsDirectional.all(isPhone ? 20 : 24),
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
                            'sales_return_form.no_order_title'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.27,
                              Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'sales_return_form.no_order_subtitle'.tr,
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
              const SizedBox(height: 16),
              SalesReturnSectionTitle(title: 'sales_return_form.section_order_items'.tr),
              const SizedBox(height: 12),
              Consumer<SalesProvider>(
                builder: (context, salesProvider, _) {
                  final itemCount = salesProvider.salesReturnItems.length;
                  final isPhone = salesReturnIsPhone(context);
                  if (isPhone) {
                    return _buildOrderDetails();
                  }
                  return SizedBox(
                    height: _itemsTableHeight(itemCount),
                    child: _buildOrderDetails(),
                  );
                },
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
              SizedBox(height: isPhone ? 12 : 20),
            ],
          ),
          _buildLoadingOverlay(),
        ],
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
    required String productUnit,
    required double returnedQuantity,
  }) {
    if (cartItemId <= 0) {
      showScaffoldError(
        context: context,
        message: 'sales_return_form.error_missing_cart_item_id'.tr,
      );
      return;
    }

    debugPrint('_showReturnDialog called with:');
    debugPrint('  productName: $productName');
    debugPrint('  unitPrice: $unitPrice');
    debugPrint('  orderId: $orderId');
    debugPrint('  cartItemId: $cartItemId');
    debugPrint('  currency: $currency');
    debugPrint('  totalPrice: $totalPrice');
    debugPrint('  quantity: $quantity');
    debugPrint('  returnedQuantity: $returnedQuantity');
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController returnTotalController = TextEditingController();
    final soldQuantity = double.tryParse(quantity) ?? 0;
    final maxQuantity =
        (soldQuantity - returnedQuantity).clamp(0, soldQuantity);
    final unitPriceValue = double.parse(unitPrice);
    final maxTotal = maxQuantity * unitPriceValue;
    final hasProductUnit = productUnit.trim().isNotEmpty;
    final bool allowsDecimals = hasProductUnit
        ? allowsDecimalQuantityUnit(productUnit)
        : soldQuantity != soldQuantity.roundToDouble();

    bool _updatingFromQuantity = false;
    bool _updatingFromTotal = false;

    quantityController.addListener(() {
      if (_updatingFromTotal) return;
      if (quantityController.text.isEmpty) return;

      final enteredQuantity = double.tryParse(quantityController.text) ?? 0;

      if (enteredQuantity > maxQuantity) {
        quantityController.text = allowsDecimals
            ? maxQuantity.toStringAsFixed(3)
            : maxQuantity.toInt().toString();
        quantityController.selection = TextSelection.fromPosition(
          TextPosition(offset: quantityController.text.length),
        );
      }

      _updatingFromQuantity = true;
      final total = enteredQuantity * unitPriceValue;
      returnTotalController.text = total.toStringAsFixed(2);
      _updatingFromQuantity = false;
    });

    returnTotalController.addListener(() {
      if (_updatingFromQuantity) return;
      if (returnTotalController.text.isEmpty) return;

      final enteredTotal = double.tryParse(returnTotalController.text) ?? 0.0;

      if (enteredTotal > maxTotal) {
        returnTotalController.text = maxTotal.toStringAsFixed(2);
        returnTotalController.selection = TextSelection.fromPosition(
          TextPosition(offset: returnTotalController.text.length),
        );
      }

      _updatingFromTotal = true;
      final calculatedQuantity = enteredTotal / unitPriceValue;
      if (calculatedQuantity <= maxQuantity) {
        quantityController.text = allowsDecimals
            ? calculatedQuantity.toStringAsFixed(3)
            : calculatedQuantity.floor().toString();
      }
      _updatingFromTotal = false;
    });

    if (maxQuantity <= 0) {
      showScaffoldError(
        context: context,
        message: 'sales_return_form.error_no_qty'.tr,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: salesReturnIsPhone(context) ? 12 : 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  width: salesReturnIsPhone(context)
                      ? MediaQuery.of(context).size.width - 24
                      : MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: EdgeInsetsDirectional.all(
                      salesReturnIsPhone(context) ? 16 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'sales_return_form.dialog_title'.trParams({'id': orderId}),
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s18,
                                0.28,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SalesReturnContentCard(
                        padding: const EdgeInsetsDirectional.all(14),
                        child: salesReturnIsPhone(context)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDialogProductRow('sales_return_form.dialog_col_product'.tr, productName,
                                      bold: true),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_price'.tr, '$currency $unitPrice'),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_total'.tr, '$currency $totalPrice'),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow('sales_return_form.dialog_col_order_qty'.tr, quantity),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'sales_return_form.dialog_col_product_name'.tr,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_price'.tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_total_price'.tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_order_quantity'.tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          productName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s13,
                                            0.20,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$currency $unitPrice',
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$currency $totalPrice',
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          quantity,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
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
                          labelText: 'sales_return_form.field_quantity'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          helperText:
                              'sales_return_form.helper_max_returnable'.trParams({'max': '${allowsDecimals ? maxQuantity.toStringAsFixed(3) : maxQuantity.toInt()}'}),
                          errorText:
                              (double.tryParse(quantityController.text) ?? 0) >
                                      maxQuantity
                                  ? 'sales_return_form.error_max_qty'.tr
                                  : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          if (hasProductUnit)
                            ...quantityInputFormattersForUnit(productUnit)
                          else if (allowsDecimals)
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,3}'))
                          else
                            FilteringTextInputFormatter.digitsOnly,
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            final parsed = double.tryParse(newValue.text);
                            if (parsed == null || parsed <= maxQuantity) {
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
                          labelText: 'sales_return_form.field_return_total'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixText: '$currency ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            final doubleValue = double.tryParse(newValue.text);
                            if (doubleValue == null ||
                                doubleValue <= maxTotal) {
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
                          labelText: 'sales_return_form.field_reason'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 24),
                      SalesReturnActionRow(
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text('general.cancel'.tr),
                          ),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final parsedOrderId = int.tryParse(orderId);
                                    if (parsedOrderId == null) {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            'sales_return_form.error_invalid_order'.tr,
                                      );
                                      return;
                                    }

                                    final returnQty = double.tryParse(
                                        quantityController.text);
                                    if (returnQty == null || returnQty <= 0) {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            'sales_return_form.error_invalid_qty'.tr,
                                      );
                                      return;
                                    }
                                    if (returnQty > maxQuantity) {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            'sales_return_form.error_qty_exceeds'.tr,
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSubmitting = true);

                                    try {
                                      String? accessToken =
                                          Provider.of<AuthModel>(context,
                                                  listen: false)
                                              .token;

                                      final returnOrderId =
                                          await Provider.of<SalesProvider>(
                                                  context,
                                                  listen: false)
                                              .submitSalesReturn(
                                        accessToken: accessToken ?? '',
                                        orderId: parsedOrderId,
                                        price: double.parse(unitPrice),
                                        quantity: returnQty,
                                        cartItemId: cartItemId,
                                        reason: reasonController.text,
                                        isDeliveryRefundable:
                                            _deliveryChargeRefundable,
                                      );

                                      if (mounted) {
                                        setState(() {
                                          _activeReturnOrderId = returnOrderId;
                                        });
                                      }

                                      if (!dialogContext.mounted) return;

                                      showScaffold(
                                        context: context,
                                        message: 'sales_return_form.msg_item_returned'.tr,
                                      );

                                      await getOrderDetails(
                                          selectedOrderNumber.toString(),
                                          resetInitialState: false);

                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    } catch (error, stackTrace) {
                                      debugPrint(
                                          'Error submitting sales return: $error');
                                      debugPrint(
                                          'Stack Trace for submitSalesReturn: $stackTrace');
                                      showScaffoldError(
                                        context: context,
                                        message: error is Exception
                                            ? error
                                                .toString()
                                                .replaceFirst('Exception: ', '')
                                            : 'sales_return_form.error_submit_failed'.tr,
                                      );
                                    } finally {
                                      if (context.mounted) {
                                        setDialogState(
                                            () => isSubmitting = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorManager.kPrimaryColor,
                              disabledBackgroundColor:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'sales_return_form.btn_submit'.tr,
                                    style: const TextStyle(color: Colors.white),
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
      },
    );
  }

  Widget _buildDialogProductRow(String label, String value,
      {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              bold ? FontWeightManager.semiBold : FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    return Consumer<SalesProvider>(builder: (context, salesProvider, child) {
      final salesReturnItems = salesProvider.salesReturnItems;
      final isPhone = salesReturnIsPhone(context);

      if (salesReturnItems.isEmpty) {
        return SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  initLoading ? 'sales_return_form.empty_loading'.tr : 'sales_return_form.empty_no_items'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (isPhone) {
        return Column(
          children: salesReturnItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildMobileReturnItemCard(item, index);
          }).toList(),
        );
      }

      return SalesReturnResponsiveTable(
        minWidth: 960,
        table: SizedBox(
          height: _itemsTableHeight(salesReturnItems.length),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ColorManager.tableBGColor.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                    6: FlexColumnWidth(1),
                    7: FlexColumnWidth(1.5),
                  },
                  border: null,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        _buildTableHeader('sales_return_form.col_product_name'.tr),
                        _buildTableHeader('sales_return_form.col_quantity'.tr),
                        _buildTableHeader('sales_return_form.col_unit_price'.tr),
                        _buildTableHeader('sales_return_form.col_total_price'.tr),
                        _buildTableHeader('sales_return_form.col_returned_qty'.tr),
                        _buildTableHeader('sales_return_form.col_returned_total'.tr),
                        _buildTableHeader('sales_return_form.col_status'.tr),
                        _buildTableHeader('sales_return_form.col_action'.tr),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                      5: FlexColumnWidth(1.5),
                      6: FlexColumnWidth(1),
                      7: FlexColumnWidth(1.5),
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...salesReturnItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        SalesReturnCart item = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.06),
                          ),
                          children: _buildOrderItemTableCells(item),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _resolvedProductUnit(SalesReturnCart item) {
    if (item.productUnit.trim().isNotEmpty) {
      return item.productUnit;
    }

    final orderItems = orderDetailsModelData?.cart?.cartItems ?? const [];
    for (final orderItem in orderItems) {
      final sameCartItem = orderItem.id == item.cartItemId;
      final sameProductName = orderItem.productName?.trim().toLowerCase() ==
          item.productName.trim().toLowerCase();
      if (!sameCartItem && !sameProductName) continue;

      final unit = orderItem.productUnit?.trim().isNotEmpty == true
          ? orderItem.productUnit!.trim()
          : orderItem.saleUnitName?.trim() ?? '';
      if (unit.isNotEmpty) return unit;
    }

    return '';
  }

  Widget _buildMobileReturnItemCard(SalesReturnCart item, int index) {
    final hasValidCartItemId = item.cartItemId > 0;
    final canReturn = hasValidCartItemId &&
        !item.isReturned &&
        SalesReturnCalculationHelper.remainingReturnableQuantity(item) > 0;

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: index > 0 ? 10 : 0),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    Text(
                      item.productName.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s13,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                    if (item.formattedVariantAttributes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.formattedVariantAttributes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.16,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                item.isReturned ? Icons.check_circle : Icons.cancel,
                color: item.isReturned ? Colors.green : Colors.red,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMobileItemMetric('sales_return_form.metric_qty'.tr, item.quantity),
              _buildMobileItemMetric('sales_return_form.metric_unit'.tr, item.unitPrice),
              _buildMobileItemMetric('sales_return_form.metric_total'.tr, item.totalPrice),
              _buildMobileItemMetric(
                'sales_return_form.metric_returned'.tr,
                item.returnedQuantity == item.returnedQuantity.roundToDouble()
                    ? item.returnedQuantity.toInt().toString()
                    : item.returnedQuantity.toStringAsFixed(3),
              ),
              _buildMobileItemMetric(
                  'sales_return_form.metric_ret_total'.tr, item.returnedTotal.toString()),
            ],
          ),
          const SizedBox(height: 12),
          if (!canReturn)
            Text(
              hasValidCartItemId ? 'sales_return_form.status_returned'.tr : 'sales_return_form.status_unavailable'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                hasValidCartItemId ? Colors.green : Colors.red,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                  foregroundColor: ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showReturnDialog(
                    context,
                    productName: item.productName.toString(),
                    unitPrice: item.unitPrice.toString(),
                    orderId: selectedOrderId.toString(),
                    cartItemId: item.cartItemId,
                    currency: '',
                    totalPrice: item.totalPrice.toString(),
                    quantity: item.quantity.toString(),
                    productUnit: _resolvedProductUnit(item),
                    returnedQuantity: item.returnedQuantity,
                  );
                },
                child: Text(
                  'sales_return_form.btn_return_item'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileItemMetric(String label, String value) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.15,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItemTableCells(SalesReturnCart item) {
    return [
      SizedBox(height: 55, child: _buildTableCell(item.productName)),
      SizedBox(height: 55, child: _buildTableCell(item.quantity)),
      SizedBox(height: 55, child: _buildTableCell(item.unitPrice)),
      SizedBox(height: 55, child: _buildTableCell(item.totalPrice)),
      SizedBox(
        height: 55,
        child: _buildTableCell(
          item.returnedQuantity == item.returnedQuantity.roundToDouble()
              ? item.returnedQuantity.toInt().toString()
              : item.returnedQuantity.toStringAsFixed(3),
        ),
      ),
      SizedBox(
          height: 55, child: _buildTableCell(item.returnedTotal.toString())),
      SizedBox(
        height: 55,
        child: Center(
          child: Icon(
            item.isReturned ? Icons.check_circle : Icons.cancel,
            color: item.isReturned ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
      ),
      SizedBox(
        height: 55,
        child: Center(
          child: item.cartItemId <= 0 ||
                  item.isReturned ||
                  SalesReturnCalculationHelper.remainingReturnableQuantity(
                          item) <=
                      0
              ? Text(
                  item.cartItemId <= 0 ? 'sales_return_form.status_unavailable'.tr : 'sales_return_form.status_returned'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    item.cartItemId <= 0 ? Colors.red : Colors.green,
                  ),
                )
              : TextButton(
                  onPressed: () {
                    _showReturnDialog(
                      context,
                      productName: item.productName.toString(),
                      unitPrice: item.unitPrice.toString(),
                      orderId: selectedOrderId.toString(),
                      cartItemId: item.cartItemId,
                      currency: '',
                      totalPrice: item.totalPrice.toString(),
                      quantity: item.quantity.toString(),
                      productUnit: _resolvedProductUnit(item),
                      returnedQuantity: item.returnedQuantity,
                    );
                  },
                  child: Text('sales_return_form.btn_return'.tr),
                ),
        ),
      ),
    ];
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          vertical: 14.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          vertical: 14.0, horizontal: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  SalesReturnRefundSummary _refundSummaryFor(
    List<SalesReturnCart> items, {
    SalesReturnRefundBreakdown? serverBreakdown,
  }) {
    final shippingCost =
        (orderDetailsModelData?.deliveryCharge ?? 0).toDouble();
    final orderDiscount =
        (orderDetailsModelData?.priceSummary?.discount ?? 0).toDouble();

    if (serverBreakdown != null) {
      return serverBreakdown.toRefundSummary(
        deliveryRefundable: _deliveryChargeRefundable,
        shippingCost: shippingCost,
      );
    }

    if (_draftReturnOrderId != null) {
      final draftTotal = items.fold<double>(
        0,
        (sum, item) =>
            sum + (double.tryParse(item.returnedTotal.toString()) ?? 0),
      );
      if (draftTotal > 0) {
        return SalesReturnCalculationHelper.calculateFromDraftTotals(
          items: items,
          orderDiscount: orderDiscount,
          shippingCost: shippingCost,
          deliveryRefundable: _deliveryChargeRefundable,
        );
      }
    }

    return SalesReturnCalculationHelper.calculateRefund(
      items: items,
      initialReturnedTotals: _initialReturnedTotals,
      orderDiscount: orderDiscount,
      shippingCost: shippingCost,
      deliveryRefundable: _deliveryChargeRefundable,
    );
  }

  Widget _buildCompleteReturnButton(Size size) {
    final SideBarController sideBarController = Get.put(SideBarController());
    final canComplete = _canCompleteReturn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canComplete && isOrderSelected && !initLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'sales_return_form.hint_min_one_item'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.25,
                Colors.grey.shade600,
              ),
            ),
          ),
        Opacity(
          opacity: canComplete ? 1 : 0.45,
          child: CustomRoundButton(
            title: isCompletingReturn ? 'sales_return_form.btn_completing'.tr : 'sales_return_form.btn_complete_return'.tr,
            fct: canComplete
                ? () async {
                    debugPrint('Return Order ID: $selectedOrderId');

                    // Check if there are any items with return_order_id
                    if (_salesReturnItems.isEmpty) {
                      showScaffoldError(
                        context: context,
                        message: 'sales_return_form.error_no_return_items'.tr,
                      );
                      return;
                    }

                    final returnOrderId = _draftReturnOrderId;
                    if (returnOrderId == null) {
                      showScaffoldError(
                        context: context,
                        message:
                            'sales_return_form.error_no_return_order'.tr,
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
                            message: 'sales_return_form.error_enter_amount'.tr,
                          );
                          return;
                        }

                        final refundSummary = _refundSummaryFor(
                          _salesReturnItems,
                          serverBreakdown:
                              Provider.of<SalesProvider>(context, listen: false)
                                  .serverRefundBreakdown,
                        );
                        final maxCashRefund = refundSummary.maxCashRefundAmount;
                        final paidAmount =
                            double.tryParse(paidAmountController.text) ?? 0.0;

                        if (paidAmount <= 0) {
                          showScaffoldError(
                            context: context,
                            message: 'sales_return_form.error_amount_gt_zero'.tr,
                          );
                          return;
                        }

                        if (paidAmount > maxCashRefund) {
                          showScaffoldError(
                            context: context,
                            message:
                                'sales_return_form.error_amount_exceeds'.trParams({'max': maxCashRefund.toStringAsFixed(2)}),
                          );
                          return;
                        }
                      }

                      // Parse paid amount
                      double paidAmount = 0.0;
                      if (hasPayment && paidAmountController.text.isNotEmpty) {
                        paidAmount =
                            double.tryParse(paidAmountController.text) ?? 0.0;
                      }

                      setState(() {
                        isCompletingReturn = true;
                      });

                      await Provider.of<SalesProvider>(context, listen: false)
                          .completeSalesReturn(
                        accessToken: accessToken ?? '',
                        returnOrderId: returnOrderId,
                        paymentMethod:
                            hasPayment ? selectedPaymentMethod : null,
                        paidAmount: hasPayment ? paidAmount : null,
                        hasPayment: hasPayment,
                        isDeliveryRefundable: _deliveryChargeRefundable,
                      );

                      showScaffold(
                        context: context,
                        message: 'sales_return_form.msg_return_created'.tr,
                      );

                      sideBarController.index.value = 50;
                    } catch (error, stackTrace) {
                      debugPrint('Error creating sales return: $error');
                      debugPrint(
                          'Stack Trace for completeSalesReturn: $stackTrace');
                      showScaffoldError(
                        context: context,
                        message: error is Exception
                            ? error.toString().replaceFirst('Exception: ', '')
                            : 'sales_return_form.error_create_failed'.tr,
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          isCompletingReturn = false;
                        });
                      }
                    }
                  }
                : () {},
            height: 48,
            width: size.width,
            fontSize: FontSize.s13,
            isLoading: isCompletingReturn,
          ),
        ),
      ],
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      int totalItems = salesReturnItems.length; // Count of distinct items
      int totalQuantity = 0; // Total quantity of all items
      int returnedItems = 0;
      double returnedQuantity = 0; // Total returned quantity IN THIS SESSION

      for (var item in salesReturnItems) {
        final itemTotal = double.tryParse(item.totalPrice.toString()) ?? 0.0;
        final itemQuantity = double.tryParse(item.quantity) ?? 0;

        orderTotal += itemTotal;
        totalQuantity += itemQuantity.round();

        // Calculate ONLY the returns made in THIS session (difference from initial state)
        final initialReturnedQty =
            _initialReturnedQuantities[item.cartItemId] ?? 0;
        final initialReturnedTotal =
            _initialReturnedTotals[item.cartItemId] ?? 0.0;

        final currentReturnedQty = item.returnedQuantity;
        final currentReturnedTotal =
            double.tryParse(item.returnedTotal.toString()) ?? 0.0;

        // Session-specific returns
        final sessionReturnedQty = currentReturnedQty - initialReturnedQty;
        final sessionReturnedTotal =
            currentReturnedTotal - initialReturnedTotal;

        returnedQuantity += sessionReturnedQty;

        if (sessionReturnedQty > 0) {
          returnedItems += 1; // Count items returned in this session
        }
      }

      final refundSummary = _refundSummaryFor(
        salesReturnItems,
        serverBreakdown: salesProvider.serverRefundBreakdown,
      );
      final returnDiscount = refundSummary.proRataDiscount;
      final returnedTotal = refundSummary.netRefundAmount;
      final shippingCost =
          (orderDetailsModelData?.deliveryCharge ?? 0).toDouble();

      // Order total should also ideally come from orderDetailsModelData to include tax/shipping
      if (orderDetailsModelData?.priceSummary?.netPayable != null) {
        orderTotal =
            (orderDetailsModelData!.priceSummary!.netPayable!).toDouble();
      }

      final returnedQtyLabel =
          returnedQuantity == returnedQuantity.roundToDouble()
              ? '${returnedQuantity.toInt()}'
              : returnedQuantity.toStringAsFixed(3);

      return SalesReturnTwoColumnLayout(
        start: SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(16),
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
                    'sales_return_form.summary_order_title'.tr,
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
              _buildSummaryRow('sales_return_form.summary_total_items'.tr, '$totalItems'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_total_qty'.tr, '$totalQuantity'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_discount'.tr,
                  '${(orderDetailsModelData?.priceSummary?.discount ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_delivery'.tr,
                  '${(orderDetailsModelData?.deliveryCharge ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow(
                  'sales_return_form.summary_order_total'.tr, '${orderTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
        end: SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(16),
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
                    'sales_return_form.summary_return_title'.tr,
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
              _buildSummaryRow('sales_return_form.summary_returned_items'.tr, '$returnedItems'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_returned_qty'.tr, returnedQtyLabel),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_discount'.tr, returnDiscount.toStringAsFixed(2)),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_delivery'.tr,
                  '${(_deliveryChargeRefundable ? shippingCost : 0.0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow(
                  'sales_return_form.summary_return_total'.tr, '${returnedTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
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

      // Calculate return total (ONLY from this session) via shared helper
      final refundSummary = _refundSummaryFor(
        salesReturnItems,
        serverBreakdown: salesProvider.serverRefundBreakdown,
      );
      final suggestedRefund = refundSummary.netRefundAmount;
      final maxCashRefund = refundSummary.maxCashRefundAmount;

      // Autofill suggested refund (after pro-rata discount); cashier can increase up to max.
      if (hasPayment && paidAmountController.text.isEmpty) {
        paidAmountController.text = suggestedRefund.toStringAsFixed(2);
      }

      // Real-time validation flag
      final double enteredAmount =
          double.tryParse(paidAmountController.text) ?? 0.0;
      final bool isExceedingMax = hasPayment && enteredAmount > maxCashRefund;

      return SalesReturnContentCard(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            EdgeInsetsDirectional.all(salesReturnIsPhone(context) ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Switch.adaptive(
                  value: _deliveryChargeRefundable,
                  activeColor: ColorManager.kPrimaryColor,
                  onChanged: (value) {
                    setState(() {
                      _deliveryChargeRefundable = value;
                      if (hasPayment) {
                        paidAmountController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_return_form.payment_delivery_refundable'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'sales_return_form.payment_delivery_hint'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isPhone =
                    constraints.maxWidth < kSalesReturnPhoneBreakpoint;
                final headerRow = Row(
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
                    Expanded(
                      child: Text(
                        'sales_return_form.payment_section_title'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.25,
                          Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                );
                final paymentToggle = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'sales_return_form.payment_has_payment'.tr,
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
                );

                if (isPhone) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow,
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: paymentToggle,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: headerRow),
                    paymentToggle,
                  ],
                );
              },
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
                        'sales_return_form.payment_no_mode'.tr,
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isPhone =
                      constraints.maxWidth < kSalesReturnPhoneBreakpoint;
                  final paymentMethodField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_return_form.payment_method_label'.tr,
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
                            contentPadding:
                                const EdgeInsetsDirectional.symmetric(
                                    horizontal: 12, vertical: 12),
                            constraints:
                                const BoxConstraints.tightFor(height: 48),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide:
                                  BorderSide(color: ColorManager.kPrimaryColor),
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
                  );
                  final amountField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_return_form.payment_amount_label'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.25,
                          Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<AppSettingsProvider>(
                        builder: (context, settings, _) {
                          final currency =
                              settings.appSettings?.currency ?? 'INR';
                          return SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: paidAmountController,
                              focusNode: paidAmountFocusNode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlignVertical: TextAlignVertical.center,
                              onTap: () {
                                paidAmountController.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset:
                                      paidAmountController.text.length,
                                );
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                errorText: isExceedingMax
                                    ? 'sales_return_form.payment_amount_exceeds'.trParams({'max': maxCashRefund.toStringAsFixed(2)})
                                    : null,
                                prefixText: '$currency ',
                                constraints:
                                    const BoxConstraints.tightFor(height: 48),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: ColorManager.kPrimaryColor),
                                ),
                                contentPadding:
                                    const EdgeInsetsDirectional.symmetric(
                                        horizontal: 12, vertical: 12),
                              ),
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s14,
                                0.25,
                                ColorManager.textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );

                  if (isPhone) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        paymentMethodField,
                        const SizedBox(height: 12),
                        amountField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 2, child: paymentMethodField),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: amountField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                refundSummary.isFromServer
                    ? 'sales_return_form.payment_returned_total'.trParams({'total': refundSummary.sessionItemsTotal.toStringAsFixed(2)})
                    : 'sales_return_form.payment_items_total'.trParams({'total': refundSummary.sessionItemsTotal.toStringAsFixed(2)}),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
              if (refundSummary.isFromServer) ...[
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_server_calc'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.25,
                    ColorManager.kPrimaryColor.withOpacity(0.8),
                  ),
                ),
              ],
              if (refundSummary.proRataDiscount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_suggested'.trParams({'amount': suggestedRefund.toStringAsFixed(2)}),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_pro_rata'.trParams({'amount': refundSummary.proRataDiscount.toStringAsFixed(2)}),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'sales_return_form.payment_max_refund'.trParams({'max': maxCashRefund.toStringAsFixed(2)}),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'sales_return_form.payment_refund_note'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.25,
                  Colors.grey.shade500,
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
