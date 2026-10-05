import 'package:flutter/widgets.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';

class PurchaseOrderItem {
  int? id; // NEW! Track the existing purchase item ID
  String barcode;

  Category? categoryData;
  GetProduct? productData;
  String unit;
  String quantity;
  String purchaseRate;

  String retailPrice;
  String mrp;
  DateTime? pkgMfg;
  DateTime? expDate;

  String wholesalePrice;
  String wholesaleMinUnit;
  String rack;
  String? selectedUnit;
  String? selectedRack;
  bool taxInclude;
  bool taxIncludePurchase;
  bool alreadyReceived;
  Map<String, dynamic>? calculatedTaxData;

  bool receive;
  int? productVariantId;
  String? variantName;
  TextEditingController qtyCtrl;
  TextEditingController purchasePriceCtrl;
  TextEditingController retailPriceCtrl;
  TextEditingController mrpCtrl;
  TextEditingController wholesalePriceCtrl;

  SaleUnit? selectedPurchaseUnit;
  String? purchaseQty;
  String? purchaseConversionRate;
  Map<int, double> unitPriceOverrides;

  PurchaseOrderItem({
    this.barcode = '',
    this.categoryData,
    this.productData,
    this.unit = '',
    this.quantity = '1',
    this.purchaseRate = '',
    this.retailPrice = '',
    this.mrp = '',
    this.pkgMfg,
    this.expDate,
    this.wholesalePrice = '',
    this.wholesaleMinUnit = '',
    this.rack = '',
    this.selectedUnit,
    this.selectedRack,
    this.taxInclude = true,
    this.taxIncludePurchase = true,
    this.calculatedTaxData,
    this.receive = false,
    this.alreadyReceived = false,
    this.id,
    this.productVariantId,
    this.variantName,
    this.selectedPurchaseUnit,
    this.purchaseQty,
    this.purchaseConversionRate,
    Map<int, double>? unitPriceOverrides,
  })  : qtyCtrl = TextEditingController(text: quantity),
        purchasePriceCtrl = TextEditingController(text: purchaseRate),
        retailPriceCtrl = TextEditingController(text: retailPrice),
        mrpCtrl = TextEditingController(text: mrp),
        wholesalePriceCtrl = TextEditingController(text: wholesalePrice),
        unitPriceOverrides = unitPriceOverrides ?? <int, double>{};

  void dispose() {
    qtyCtrl.dispose();
    purchasePriceCtrl.dispose();
    retailPriceCtrl.dispose();
    mrpCtrl.dispose();
    wholesalePriceCtrl.dispose();
  }

  void syncControllers() {
    qtyCtrl.text = quantity;
    purchasePriceCtrl.text = purchaseRate;
    retailPriceCtrl.text = retailPrice;
    mrpCtrl.text = mrp;
    wholesalePriceCtrl.text = wholesalePrice;
  }
}
