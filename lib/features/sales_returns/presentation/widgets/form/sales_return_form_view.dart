import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'; // Add this import for PointerDeviceKind
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/features/sales_returns/domain/sales_return_calculation_helper.dart';
import 'package:pos_machine/features/sales_returns/domain/models/sales_return_refund_breakdown.dart';

import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/features/sales_returns/presentation/widgets/sales_return_responsive.dart';

import '../../state/sales_return_form_controller.dart';
import '../../state/sales_return_item_dialog_controller.dart';

part 'sales_return_payment_method.dart';
part 'sales_return_dialog_submit.dart';
part 'sales_return_form_view_1.dart';
part 'sales_return_form_view_2.dart';
part 'sales_return_form_view_3.dart';
part 'sales_return_form_view_4.dart';
part 'sales_return_form_view_5.dart';
part 'sales_return_form_view_6.dart';
part 'sales_return_form_view_7.dart';

class SalesReturnFormSections {
  SalesReturnFormSections(
      {required this.context,
      required this.controller,
      required this.currency,
      required this.onBack});
  Widget build() => _buildView();
  final BuildContext context;
  final SalesReturnFormController controller;
  final String currency;
  final VoidCallback onBack;
  TextEditingController get orderNumberController =>
      controller.orderNumberController;
  TextEditingController get customerNameController =>
      controller.customerNameController;
  TextEditingController get dateController => controller.dateController;
  TextEditingController get amountController => controller.amountController;
  TextEditingController get emailController => controller.emailController;
  TextEditingController get phoneController => controller.phoneController;
  TextEditingController get storeController => controller.storeController;
  GetStoreModelData? get storeSelected => controller.storeSelected;
  set storeSelected(GetStoreModelData? value) =>
      controller.storeSelected = value;
  DateTime? get selectedDate => controller.selectedDate;
  set selectedDate(DateTime? value) => controller.selectedDate = value;
  TextEditingController get quantityController => controller.quantityController;
  set quantityController(TextEditingController value) =>
      controller.quantityController = value;
  TextEditingController get unitPriceController =>
      controller.unitPriceController;
  set unitPriceController(TextEditingController value) =>
      controller.unitPriceController = value;
  TextEditingController get selectedProductIdController =>
      controller.selectedProductIdController;
  set selectedProductIdController(TextEditingController value) =>
      controller.selectedProductIdController = value;
  bool get isInitLoading => controller.isInitLoading;
  set isInitLoading(bool value) => controller.isInitLoading = value;
  String get orderNumber => controller.orderNumber;
  set orderNumber(String value) => controller.orderNumber = value;
  OrderDetailsModelData? get orderDetailsModelData =>
      controller.orderDetailsModelData;
  set orderDetailsModelData(OrderDetailsModelData? value) =>
      controller.orderDetailsModelData = value;
  List<OrderDetailsModelDataCartItem>? get cartItems => controller.cartItems;
  set cartItems(List<OrderDetailsModelDataCartItem>? value) =>
      controller.cartItems = value;
  bool get isCustomerFound => controller.isCustomerFound;
  set isCustomerFound(bool value) => controller.isCustomerFound = value;
  String? get mobileNumberText => controller.mobileNumberText;
  set mobileNumberText(String? value) => controller.mobileNumberText = value;
  int? get selectedCustomerID => controller.selectedCustomerID;
  set selectedCustomerID(int? value) => controller.selectedCustomerID = value;
  String? get selectedCustomerPhone => controller.selectedCustomerPhone;
  set selectedCustomerPhone(String? value) =>
      controller.selectedCustomerPhone = value;
  CustomerListModelData? get selectedCustomer => controller.selectedCustomer;
  set selectedCustomer(CustomerListModelData? value) =>
      controller.selectedCustomer = value;
  Map<int, bool> get hoverMap => controller.hoverMap;
  set hoverMap(Map<int, bool> value) => controller.hoverMap = value;
  String? get selectedOrderId => controller.selectedOrderId;
  set selectedOrderId(String? value) => controller.selectedOrderId = value;
  String? get selectedOrderNumber => controller.selectedOrderNumber;
  set selectedOrderNumber(String? value) =>
      controller.selectedOrderNumber = value;
  bool get isOrderSelected => controller.isOrderSelected;
  set isOrderSelected(bool value) => controller.isOrderSelected = value;
  bool get initLoading => controller.initLoading;
  set initLoading(bool value) => controller.initLoading = value;
  List<SalesReturnCart> get salesReturnItems => controller.salesReturnItems;
  set salesReturnItems(List<SalesReturnCart> value) =>
      controller.salesReturnItems = value;
  int? get activeReturnOrderId => controller.activeReturnOrderId;
  set activeReturnOrderId(int? value) => controller.activeReturnOrderId = value;
  String get selectedPaymentMethod => controller.selectedPaymentMethod;
  set selectedPaymentMethod(String value) =>
      controller.selectedPaymentMethod = value;
  TextEditingController get paidAmountController =>
      controller.paidAmountController;
  set paidAmountController(TextEditingController value) =>
      controller.paidAmountController = value;
  FocusNode get paidAmountFocusNode => controller.paidAmountFocusNode;
  set paidAmountFocusNode(FocusNode value) =>
      controller.paidAmountFocusNode = value;
  bool get hasPayment => controller.hasPayment;
  set hasPayment(bool value) => controller.hasPayment = value;
  bool get deliveryChargeRefundable => controller.deliveryChargeRefundable;
  set deliveryChargeRefundable(bool value) =>
      controller.deliveryChargeRefundable = value;
  List<String> get paymentMethods => controller.paymentMethods;
  bool get isCompletingReturn => controller.isCompletingReturn;
  set isCompletingReturn(bool value) => controller.isCompletingReturn = value;
  String? get initLoadError => controller.initLoadError;
  set initLoadError(String? value) => controller.initLoadError = value;
  Map<int, double> get initialReturnedQuantities =>
      controller.initialReturnedQuantities;
  set initialReturnedQuantities(Map<int, double> value) =>
      controller.initialReturnedQuantities = value;
  Map<int, double> get initialReturnedTotals =>
      controller.initialReturnedTotals;
  set initialReturnedTotals(Map<int, double> value) =>
      controller.initialReturnedTotals = value;
  bool get mounted => controller.mounted;
  void setState(VoidCallback action) => controller.setState(action);
  void resetSearch() => controller.resetSearch();
  void searchOrders(dynamic page) => controller.searchOrders(page);
  Future<void> refreshData() => controller.refreshData();
  Future<void> getOrderDetails(String number,
          {bool resetInitialState = true}) =>
      controller.getOrderDetails(number, resetInitialState: resetInitialState);
  int? get draftReturnOrderId => controller.draftReturnOrderId;
  bool get canCompleteReturn => controller.canCompleteReturn;
  String resolvedProductUnit(SalesReturnCart item) =>
      controller.resolvedProductUnit(item);
  SalesReturnRefundSummary refundSummaryFor(List<SalesReturnCart> items,
          {SalesReturnRefundBreakdown? serverBreakdown}) =>
      controller.refundSummaryFor(items, serverBreakdown: serverBreakdown);
}
