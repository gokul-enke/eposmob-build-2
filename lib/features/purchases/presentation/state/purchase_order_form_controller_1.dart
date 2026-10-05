part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations1
    on PurchaseOrderFormController {
  bool get isReceiveMode => purchaseOrderId != null;

  bool get isHeaderLockedForReceive => isReceiveMode;

  // Keep a minimum table width so smaller devices can scroll horizontally.
  // 1620 columns + 16 row padding + 16 row horizontal margin.

  Future<void> initDraftBox() async {
    try {
      await cache.open();
      if (mounted) draftBox = cache;
    } catch (error) {
      debugPrint('Failed to initialize purchase order draft: $error');
    }
  }

  bool get canPersistDraft => purchaseOrderId == null;

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool toBool(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
      default:
        return fallback;
    }
  }

  Map<int, double> parseUnitPriceOverrides(dynamic value) {
    final result = <int, double>{};
    if (value is Map) {
      for (final entry in value.entries) {
        final id = toInt(entry.key);
        final price = double.tryParse(entry.value?.toString() ?? '');
        if (id != null && price != null && price >= 0) {
          result[id] = price;
        }
      }
    } else if (value is List) {
      for (final rawEntry in value.whereType<Map>()) {
        final id = toInt(rawEntry['sale_unit_id']);
        final price = double.tryParse(rawEntry['price']?.toString() ?? '');
        if (id != null && price != null && price >= 0) {
          result[id] = price;
        }
      }
    }
    return result;
  }

  List<Map<String, dynamic>> unitPricesPayload(PurchaseOrderItem item) {
    return item.unitPriceOverrides.entries
        .map((entry) => {'sale_unit_id': entry.key, 'price': entry.value})
        .toList();
  }

  Map<String, dynamic> purchaseOrderItemToMap(PurchaseOrderItem item) {
    return {
      'id': item.id,
      'barcode': item.barcode,
      'productId': item.productData?.productId,
      'productName': item.productData?.productName,
      'categoryId': item.categoryData?.categoryId,
      'categoryName': item.categoryData?.categoryName,
      'unit': item.unit,
      'quantity': item.quantity,
      'purchaseRate': item.purchaseRate,
      'retailPrice': item.retailPrice,
      'mrp': item.mrp,
      'pkgMfg': item.pkgMfg?.toIso8601String(),
      'expDate': item.expDate?.toIso8601String(),
      'wholesalePrice': item.wholesalePrice,
      'wholesaleMinUnit': item.wholesaleMinUnit,
      'rack': item.rack,
      'selectedUnit': item.selectedUnit,
      'selectedRack': item.selectedRack,
      'taxInclude': item.taxInclude,
      'taxIncludePurchase': item.taxIncludePurchase,
      'calculatedTaxData': item.calculatedTaxData,
      'receive': item.receive,
      'alreadyReceived': item.alreadyReceived,
      'selectedPurchaseUnit': item.selectedPurchaseUnit?.toJson(),
      'purchaseQty': item.purchaseQty,
      'purchaseConversionRate': item.purchaseConversionRate,
      'unitPriceOverrides': item.unitPriceOverrides.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'productVariantId': item.productVariantId,
      'variantName': item.variantName,
    };
  }

  PurchaseOrderItem mapToPurchaseOrderItem(Map<dynamic, dynamic> map) {
    final localProductProvider = ports.products;
    final categoryProvider = ports.categories;

    final int? productId = toInt(map['productId']);
    final String? productName = map['productName']?.toString();
    final int? categoryId = toInt(map['categoryId']);
    final String? categoryName = map['categoryName']?.toString();
    final bool taxInclude = toBool(map['taxInclude']);
    final bool taxIncludePurchase = toBool(
      map['taxIncludePurchase'],
      fallback: taxInclude,
    );

    GetProduct? productData;
    if (productId != null) {
      try {
        productData = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
        );
      } catch (_) {}
    }

    productData ??= (productId != null || (productName?.isNotEmpty ?? false))
        ? GetProduct(
            productId: productId,
            productName: productName,
            barcode: map['barcode']?.toString(),
          )
        : null;

    Category? categoryData;
    final categories = categoryProvider.category ?? [];
    if (categoryId != null && categories.isNotEmpty) {
      try {
        categoryData = categories.firstWhere((c) => c.categoryId == categoryId);
      } catch (_) {}
    }

    categoryData ??= (categoryId != null || (categoryName?.isNotEmpty ?? false))
        ? Category(categoryId: categoryId, categoryName: categoryName)
        : null;

    final item = PurchaseOrderItem(
      id: toInt(map['id']),
      barcode: map['barcode']?.toString() ?? '',
      categoryData: categoryData,
      productData: productData,
      unit: map['unit']?.toString() ?? '',
      quantity: map['quantity']?.toString() ?? '1',
      purchaseRate: map['purchaseRate']?.toString() ?? '',
      retailPrice: map['retailPrice']?.toString() ?? '',
      mrp: map['mrp']?.toString() ?? '',
      pkgMfg: map['pkgMfg'] != null
          ? DateTime.tryParse(map['pkgMfg'].toString())
          : null,
      expDate: map['expDate'] != null
          ? DateTime.tryParse(map['expDate'].toString())
          : null,
      wholesalePrice: map['wholesalePrice']?.toString() ?? '',
      wholesaleMinUnit: map['wholesaleMinUnit']?.toString() ?? '',
      rack: map['rack']?.toString() ?? '',
      selectedUnit: map['selectedUnit']?.toString(),
      selectedRack: map['selectedRack']?.toString(),
      taxInclude: taxInclude,
      taxIncludePurchase: taxIncludePurchase,
      receive: map['receive'] == true,
      alreadyReceived: map['alreadyReceived'] == true,
    );

    item.productVariantId = toInt(map['productVariantId']);
    item.variantName = map['variantName']?.toString();

    if (map['selectedPurchaseUnit'] != null) {
      try {
        item.selectedPurchaseUnit = SaleUnit.fromJson(
          Map<String, dynamic>.from(map['selectedPurchaseUnit'] as Map),
        );
      } catch (_) {}
    }
    item.purchaseQty = map['purchaseQty']?.toString();
    item.purchaseConversionRate = map['purchaseConversionRate']?.toString();
    item.unitPriceOverrides = parseUnitPriceOverrides(
      map['unitPriceOverrides'],
    );

    return item
      ..calculatedTaxData = map['calculatedTaxData'] != null
          ? Map<String, dynamic>.from(map['calculatedTaxData'] as Map)
          : null
      ..syncControllers();
  }

  Map<String, dynamic> paymentDataToMap(DynamicPaymentData data) {
    return {
      'primaryMethodId': data.primaryMethod?.id,
      'secondaryMethodId': data.secondaryMethod?.id,
      'primaryAmount': data.primaryAmount,
      'secondaryAmount': data.secondaryAmount,
    };
  }

  DynamicPaymentData mapToPaymentData(dynamic paymentMapRaw) {
    if (paymentMapRaw is! Map) return DynamicPaymentData();

    final paymentMap = paymentMapRaw.cast<dynamic, dynamic>();
    final int? primaryMethodId = toInt(paymentMap['primaryMethodId']);
    final int? secondaryMethodId = toInt(paymentMap['secondaryMethodId']);

    MasterDataValue? primaryMethod;
    MasterDataValue? secondaryMethod;

    if (primaryMethodId != null) {
      try {
        primaryMethod = paymentMethods.firstWhere(
          (method) => method.id == primaryMethodId,
        );
      } catch (_) {}
    }

    if (secondaryMethodId != null) {
      try {
        secondaryMethod = paymentMethods.firstWhere(
          (method) => method.id == secondaryMethodId,
        );
      } catch (_) {}
    }

    return DynamicPaymentData(
      primaryMethod: primaryMethod,
      secondaryMethod: secondaryMethod,
      primaryAmount: paymentMap['primaryAmount']?.toString() ?? '',
      secondaryAmount: paymentMap['secondaryAmount']?.toString() ?? '',
    );
  }

  void saveDraftToHive() {
    if (!mounted || isHydratingDraft || !canPersistDraft) return;

    draftSaveDebouncer?.cancel();
    draftSaveDebouncer =
        Timer(PurchaseOrderFormController.draftSaveDelay, () async {
      if (!mounted || draftBox == null || !draftBox!.isOpen || !canPersistDraft)
        return;

      try {
        final draftData = <String, dynamic>{
          'selectedDate': selectedDate.toIso8601String(),
          'selectedStoreId': selectedStore?.id,
          'selectedSupplierId': selectedSupplier?.id,
          'voucherNumber': voucherNumberController.text,
          'invoiceRef': invoiceRefController.text,
          'discount': discountController.text,
          'includeTax': includeTax,
          'includeTaxPurchase': includeTaxPurchase,
          'showItemDetails': showItemDetails,
          'editingItemIndex': editingItemIndex,
          'orderItems': orderItems.map(purchaseOrderItemToMap).toList(),
          'currentItem': purchaseOrderItemToMap(currentItem),
          'paymentData': paymentDataToMap(paymentData),
        };

        await draftBox!.write(draftData);
      } catch (e) {
        debugPrint('❌ Failed to save purchase order draft: $e');
      }
    });
  }
}
