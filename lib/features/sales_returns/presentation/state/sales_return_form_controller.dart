import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/order_details.dart';

import '../../domain/models/list_sales_return_items.dart';
import '../../domain/models/sales_return_refund_breakdown.dart';
import '../../domain/sales_return_calculation_helper.dart';
import '../../domain/sales_return_order_id_helper.dart';
import 'sales_return_form_ports.dart';

part 'sales_return_form_operations.dart';
part 'sales_return_form_commands.dart';

class SalesReturnFormController extends ChangeNotifier {
  SalesReturnFormController(this.ports) {
    paidAmountFocusNode.addListener(() {
      if (paidAmountFocusNode.hasFocus)
        paidAmountController.selection = TextSelection(
            baseOffset: 0, extentOffset: paidAmountController.text.length);
    });
    paidAmountController.addListener(() => setState(() {}));
  }
  final SalesReturnFormPorts ports;
  bool _disposed = false;
  int detailsRequest = 0;
  int ordersRequest = 0;
  bool get mounted => !_disposed;
  void setState(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

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
  List<SalesReturnCart> salesReturnItems = [];
  int? activeReturnOrderId;

  String selectedPaymentMethod = 'CASH';
  TextEditingController paidAmountController = TextEditingController();
  FocusNode paidAmountFocusNode = FocusNode();
  bool hasPayment = false;
  bool deliveryChargeRefundable = false;
  final List<String> paymentMethods = ['CASH', 'CARD', 'UPI'];
  bool isCompletingReturn = false;
  String? initLoadError;

  Map<int, double> initialReturnedQuantities =
      {}; // cartItemId -> initial returned quantity
  Map<int, double> initialReturnedTotals =
      {}; // cartItemId -> initial returned total

  List<ListOrderModelData> get orders => ports.orders();
  int get currentPage => ports.currentPage();
  int get totalPages => ports.totalPages();
  SalesReturnRefundBreakdown? serverRefundBreakdown;
  SalesReturnOrderInfo? currentReturnOrder;
  void clearServerRefundBreakdown() {
    serverRefundBreakdown = null;
    setState(() {});
  }

  int? get draftReturnOrderId =>
      SalesReturnOrderIdHelper.forCompletion(activeReturnOrderId);
  bool get canCompleteReturn =>
      !initLoading &&
      !isCompletingReturn &&
      isOrderSelected &&
      draftReturnOrderId != null;
  Future<void> fetchOrders(
          {required String accessToken,
          int? storeId,
          String? orderNumber,
          int? customerId,
          String? date,
          int? page}) =>
      ports.fetchOrders(
          accessToken: accessToken,
          storeId: storeId,
          orderNumber: orderNumber,
          customerId: customerId,
          date: date,
          page: page);
  Future<void> loadReturnItems(String number) async {
    final request = detailsRequest;
    final response = await ports.items(number);
    if (!mounted || request != detailsRequest) return;
    salesReturnItems = response.data;
    currentReturnOrder = response.order;
  }

  Future<int> submitSalesReturn(
      {required String accessToken,
      required int orderId,
      required double price,
      required num quantity,
      required int cartItemId,
      required String reason,
      bool isDeliveryRefundable = false}) async {
    final request = detailsRequest;
    final result = await ports.submit(
        accessToken: accessToken,
        orderId: orderId,
        price: price,
        quantity: quantity,
        cartItemId: cartItemId,
        reason: reason,
        isDeliveryRefundable: isDeliveryRefundable);
    if (mounted && request == detailsRequest) {
      activeReturnOrderId = result.id;
      if (result.breakdown != null) serverRefundBreakdown = result.breakdown;
      setState(() {});
    }
    return result.id;
  }

  Future<void> completeSalesReturn(
      {required String accessToken,
      required int returnOrderId,
      String? paymentMethod,
      double? paidAmount,
      bool? hasPayment,
      bool isDeliveryRefundable = false}) async {
    final request = detailsRequest;
    final result = await ports.complete(
        accessToken: accessToken,
        returnOrderId: returnOrderId,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        hasPayment: hasPayment,
        isDeliveryRefundable: isDeliveryRefundable);
    if (mounted && request == detailsRequest && result != null) {
      serverRefundBreakdown = result;
    }
  }

  Future<void> initialize() async {
    if (!mounted) return;
    final request = ++ordersRequest;
    final selection = detailsRequest;
    final passedNumber = ports.passedNumber();
    final passedId = ports.passedId();
    if (passedNumber.isEmpty) {
      await loadInitData();
      return;
    }
    setState(() {
      orderNumberController.text = passedNumber;
      selectedOrderNumber = passedNumber;
      selectedOrderId = passedId;
      isOrderSelected = true;
      initLoading = true;
    });
    try {
      await fetchOrders(accessToken: ports.token(), orderNumber: passedNumber);
      if (!mounted || request != ordersRequest || selection != detailsRequest)
        return;
      await getOrderDetails(passedNumber);
      if (!mounted || request != ordersRequest) return;
      ports.clearNavigation();
    } catch (error) {
      if (mounted && request == ordersRequest) {
        initLoadError = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'sales_return_form.error_failed_load_order'.tr;
        ports.error(initLoadError!);
      }
    } finally {
      if (mounted && request == ordersRequest) {
        setState(() => initLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    detailsRequest++;
    ordersRequest++;
    for (final field in [
      orderNumberController,
      customerNameController,
      dateController,
      amountController,
      emailController,
      phoneController,
      storeController,
      quantityController,
      unitPriceController,
      selectedProductIdController,
      paidAmountController
    ]) {
      field.dispose();
    }
    paidAmountFocusNode.dispose();
    super.dispose();
  }
}
