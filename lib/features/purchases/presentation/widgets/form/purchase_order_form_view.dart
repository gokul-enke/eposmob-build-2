import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/features/purchases/domain/purchase_order_totals.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/purchase_order_editable_item.dart';
import '../../state/purchase_order_form_controller.dart';

part 'purchase_order_form_view_1.dart';
part 'purchase_order_form_view_2.dart';
part 'purchase_order_form_view_3.dart';
part 'purchase_order_form_view_4.dart';
part 'purchase_order_form_view_5.dart';
part 'purchase_order_form_view_6.dart';
part 'purchase_order_form_view_7.dart';
part 'purchase_order_form_view_8.dart';

class PurchaseOrderFormView {
  PurchaseOrderFormView(
      {required this.context,
      required this.controller,
      required GlobalKey<FormState> formKey,
      required this.onBack})
      : _formKey = formKey;
  final BuildContext context;
  final PurchaseOrderFormController controller;
  final GlobalKey<FormState> _formKey;
  final VoidCallback onBack;
  bool get mounted => controller.mounted;
  void setState(VoidCallback change) => controller.setState(change);
  Widget build() => _buildView();
  static const double _purchaseTableMinWidth = 1652;
  TextEditingController get supplierSearchController =>
      controller.supplierSearchController;
  TextEditingController get storeSearchController =>
      controller.storeSearchController;
  TextEditingController get voucherNumberController =>
      controller.voucherNumberController;
  TextEditingController get invoiceRefController =>
      controller.invoiceRefController;
  TextEditingController get discountController => controller.discountController;
  TextEditingController get categorySearchController =>
      controller.categorySearchController;
  TextEditingController get productSearchController =>
      controller.productSearchController;
  TextEditingController get barcodeController => controller.barcodeController;
  TextEditingController get unitController => controller.unitController;
  TextEditingController get quantityController => controller.quantityController;
  TextEditingController get rateController => controller.rateController;
  TextEditingController get retailPriceController =>
      controller.retailPriceController;
  TextEditingController get mrpController => controller.mrpController;
  TextEditingController get wholesalePriceController =>
      controller.wholesalePriceController;
  TextEditingController get wholesaleMinUnitController =>
      controller.wholesaleMinUnitController;
  TextEditingController get rackController => controller.rackController;
  TextEditingController get unitSearchController =>
      controller.unitSearchController;
  TextEditingController get purchaseUnitSearchController =>
      controller.purchaseUnitSearchController;
  TextEditingController get rackSearchController =>
      controller.rackSearchController;
  FocusNode get quantityFocusNode => controller.quantityFocusNode;
  ScrollController get _itemsTableScrollController =>
      controller.itemsTableScrollController;
  List<PurchaseOrderItem> get orderItems => controller.orderItems;
  set orderItems(List<PurchaseOrderItem> value) =>
      controller.orderItems = value;
  PurchaseOrderItem get currentItem => controller.currentItem;
  set currentItem(PurchaseOrderItem value) => controller.currentItem = value;
  bool get includeTax => controller.includeTax;
  set includeTax(bool value) => controller.includeTax = value;
  bool get includeTaxPurchase => controller.includeTaxPurchase;
  set includeTaxPurchase(bool value) => controller.includeTaxPurchase = value;
  bool get _showItemDetails => controller.showItemDetails;
  set _showItemDetails(bool value) => controller.showItemDetails = value;
  int? get _editingItemIndex => controller.editingItemIndex;
  DynamicPaymentData get paymentData => controller.paymentData;
  set paymentData(DynamicPaymentData value) => controller.paymentData = value;
  List<MasterDataValue> get _paymentMethods => controller.paymentMethods;
  bool get _isLoadingPaymentMethods => controller.isLoadingPaymentMethods;
  bool get _isSubmitting => controller.isSubmitting;
  bool get _isPaymentDisabled => controller.isPaymentDisabled;
  set _lastKnownNetPayable(double? value) =>
      controller.lastKnownNetPayable = value;
  GetStoreModelData? get selectedStore => controller.selectedStore;
  set selectedStore(GetStoreModelData? value) =>
      controller.selectedStore = value;
  GetSuppliersModelData? get selectedSupplier => controller.selectedSupplier;
  set selectedSupplier(GetSuppliersModelData? value) =>
      controller.selectedSupplier = value;
  DateTime get selectedDate => controller.selectedDate;
  set selectedDate(DateTime value) => controller.selectedDate = value;
  int? get purchaseOrderId => controller.purchaseOrderId;
  set purchaseOrderId(int? value) => controller.purchaseOrderId = value;
  bool get _isReceiveMode => controller.isReceiveMode;
  bool get _isHeaderLockedForReceive => controller.isHeaderLockedForReceive;
  void _saveDraftToHive() => controller.saveDraftToHive();
  void _addItem() => controller.addItem();
  void _editItem(int index) => controller.editItem(index);
  void _removeItem(int index) => controller.removeItem(index);
  double _effectivePurchaseRate(PurchaseOrderItem item) =>
      controller.effectivePurchaseRate(item);
  double _purchaseLineTotal(PurchaseOrderItem item) =>
      controller.purchaseLineTotal(item);
  PurchaseOrderTotals get _purchaseTotals => controller.purchaseTotals;
  PurchaseOrderTotals get _discountValidationTotals =>
      controller.discountValidationTotals;
  void _syncPaidAmount() => controller.syncPaidAmount();
  String _variantLabel(ProductVariant v) => controller.variantLabel(v);
  String get _currency => controller.currency;
  void _selectPurchaseUnit(SaleUnit? unit) =>
      controller.selectPurchaseUnit(unit);
  void _syncQtyFromPurchaseUnit() => controller.syncQtyFromPurchaseUnit();
  void _applyProductToCurrentItem(
    GetProduct product, {
    String? initialQuantity,
  }) =>
      controller.applyProductToCurrentItem(product,
          initialQuantity: initialQuantity);
  Future<void> _showAddProductModal({String? barcode}) =>
      controller.showAddProductModal(barcode: barcode);
  Future<void> _autoFillFromBarcode(String barcode) =>
      controller.autoFillFromBarcode(barcode);
  Future<void> _submitPurchaseOrder() => controller.submitPurchaseOrder();
  void _triggerTaxRecalculation() => controller.triggerTaxRecalculation();
  void _setSellingTaxInclusion(bool value) =>
      controller.setSellingTaxInclusion(value);
  void _setPurchaseTaxInclusion(bool value) =>
      controller.setPurchaseTaxInclusion(value);
  bool? _getSelectAllReceiveState() => controller.getSelectAllReceiveState();
  void _toggleSelectAllReceive(bool? value) =>
      controller.toggleSelectAllReceive(value);
  double _getEffectiveRetailPrice(PurchaseOrderItem item) =>
      controller.getEffectiveRetailPrice(item);
  double _getEffectiveWholesalePrice(PurchaseOrderItem item) =>
      controller.getEffectiveWholesalePrice(item);
  double _getSupplierBalance() => controller.getSupplierBalance();
  Future<void> _addSupplier() => controller.addSupplier();
}
