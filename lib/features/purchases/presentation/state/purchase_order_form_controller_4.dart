part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations4
    on PurchaseOrderFormController {
  String variantLabel(ProductVariant v) {
    final parts = <String>[];
    if (v.attributes != null) {
      v.attributes!.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          parts.add(value.toString());
        }
      });
    }
    return parts.isNotEmpty
        ? parts.join(' | ')
        : 'purchase_order.variant_fallback'.tr.replaceAll(
              '@id',
              v.id.toString(),
            );
  }

  String get currency => ports.currency();

  String? validateReceiveItemFields(PurchaseOrderItem item) {
    final itemName =
        item.productData?.productName ?? 'purchase_order.selected_item'.tr;
    if ((double.tryParse(item.retailPrice) ?? 0) <= 0) {
      return '$itemName: ${'purchase_order.error_retail_price_required'.tr}';
    }
    if ((double.tryParse(item.wholesalePrice) ?? 0) <= 0) {
      return '$itemName: ${'purchase_order.error_wholesale_price_required'.tr}';
    }
    if ((double.tryParse(item.mrp) ?? 0) <= 0) {
      return '$itemName: ${'purchase_order.error_mrp_required'.tr}';
    }
    return null;
  }

  String? validatePurchaseItemFields(PurchaseOrderItem item) {
    final itemName =
        item.productData?.productName ?? 'purchase_order.selected_item'.tr;
    if ((double.tryParse(item.quantity) ?? 0) <= 0) {
      return '$itemName: ${'purchase_order.error_quantity_zero'.tr}';
    }
    if ((double.tryParse(item.purchaseRate) ?? 0) < 0) {
      return '$itemName: ${'purchase_order.error_purchase_rate_negative'.tr}';
    }
    if (item.selectedPurchaseUnit != null &&
        (double.tryParse(item.purchaseQty ?? '') ?? 0) <= 0) {
      return '$itemName: ${'purchase_order.error_purchase_quantity_zero'.tr}';
    }

    final purchaseDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (item.expDate != null) {
      final expiryDay = DateTime(
        item.expDate!.year,
        item.expDate!.month,
        item.expDate!.day,
      );
      if (expiryDay.isBefore(purchaseDay)) {
        return '$itemName: ${'purchase_order.error_expiry_before_purchase'.tr}';
      }
    }
    if (item.pkgMfg != null &&
        item.expDate != null &&
        item.pkgMfg!.isAfter(item.expDate!)) {
      return '$itemName: ${'purchase_order.error_manufacturing_after_expiry'.tr}';
    }
    return null;
  }

  void showErrorMessage(String message) {
    if (mounted) ports.onError(message);
  }

  void showSuccessMessage(String message) {
    if (mounted) ports.onSuccess(message);
  }

  void focusQuantityAndSelectAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      quantityFocusNode.requestFocus();
      quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: quantityController.text.length,
      );
    });
  }

  String? resolveUnitKey(String? productUnitValue) {
    final normalized = productUnitValue?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    final unitList = ports.purchases.getUnitList;
    if (unitList == null || unitList.isEmpty) return normalized;

    if (unitList.containsKey(normalized)) return normalized;

    final needle = normalized.toLowerCase();
    for (final entry in unitList.entries) {
      if (entry.key.toLowerCase() == needle ||
          entry.value.toLowerCase() == needle) {
        return entry.key;
      }
    }

    return normalized;
  }

  Category? resolveCategoryForProduct(GetProduct product) {
    final categories = ports.categories.category ?? const <Category>[];

    if (product.categoryId != null) {
      for (final category in categories) {
        if (category.categoryId == product.categoryId) {
          return category;
        }
      }
    }

    final productCategoryName = product.category?.name?.trim().toLowerCase();
    if (productCategoryName != null && productCategoryName.isNotEmpty) {
      for (final category in categories) {
        final categoryName = category.categoryName?.trim().toLowerCase();
        if (categoryName == productCategoryName) {
          return category;
        }
      }
    }

    return null;
  }

  void selectPurchaseUnit(SaleUnit? unit) {
    setState(() {
      currentItem.selectedPurchaseUnit = unit;
      currentItem.purchaseConversionRate = unit?.conversionRate?.toString();
      syncQtyFromPurchaseUnit();
      if (unit != null) {
        showItemDetails = false;
      }
    });
  }

  void syncQtyFromPurchaseUnit() {
    final unit = currentItem.selectedPurchaseUnit;
    final qtyText = quantityController.text.trim();
    if (unit == null) {
      currentItem.purchaseQty = null;
      currentItem.quantity = qtyText;
      return;
    }
    currentItem.purchaseQty = qtyText;
    final purchaseQty = double.tryParse(qtyText) ?? 1.0;
    final conversionRate = double.tryParse(unit.conversionRate ?? '1') ?? 1.0;
    final baseQty = purchaseQty * conversionRate;
    final qtyStr = baseQty.toStringAsFixed(
      baseQty.truncateToDouble() == baseQty ? 0 : 3,
    );
    setState(() {
      currentItem.quantity = qtyStr;
    });
  }

  void applyProductToCurrentItem(
    GetProduct product, {
    String? initialQuantity,
  }) {
    if (!mounted) return;
    final resolvedCategory = resolveCategoryForProduct(product);
    final resolvedUnitKey = resolveUnitKey(product.unit);
    final unitList = ports.purchases.getUnitList;
    final resolvedUnitName = resolvedUnitKey != null
        ? (unitList?[resolvedUnitKey] ?? product.unit ?? '')
        : '';
    final effectiveQuantity = (initialQuantity ?? '').trim().isNotEmpty
        ? initialQuantity!.trim()
        : (currentItem.quantity.trim().isNotEmpty ? currentItem.quantity : '1');

    setState(() {
      currentItem.productData = product;
      currentItem.categoryData = resolvedCategory ?? currentItem.categoryData;
      currentItem.barcode = product.barcode ?? '';
      currentItem.selectedUnit = resolvedUnitKey;
      currentItem.unit = resolvedUnitName;
      currentItem.purchaseRate = product.purchasePrice ?? '';
      currentItem.retailPrice = product.price?.price?.toString() ?? '';
      currentItem.mrp = product.mrp?.toString() ?? '';
      currentItem.wholesalePrice = product.price?.price?.toString() ?? '';
      currentItem.quantity = effectiveQuantity;
      currentItem.productVariantId = null;
      currentItem.variantName = null;
      currentItem.selectedPurchaseUnit = null;
      currentItem.purchaseQty = null;
      currentItem.purchaseConversionRate = null;
      if (product.saleUnits != null && product.saleUnits!.isNotEmpty) {
        showItemDetails = false;
      }
    });

    barcodeController.text = currentItem.barcode;
    unitController.text = currentItem.unit;
    rateController.text = currentItem.purchaseRate;
    retailPriceController.text = currentItem.retailPrice;
    mrpController.text = currentItem.mrp;
    wholesalePriceController.text = currentItem.wholesalePrice;
    quantityController.text = currentItem.quantity;

    saveDraftToHive();
    focusQuantityAndSelectAll();
    triggerTaxRecalculation();
  }

  Future<void> showAddProductModal({String? barcode}) async {
    final result = await ports.pickProduct(barcode);

    if (result == null || result['product'] == null || !mounted) {
      return;
    }

    final product = result['product'];
    final initialQuantity = result['initialQuantity']?.toString();

    if (product is GetProduct) {
      applyProductToCurrentItem(product, initialQuantity: initialQuantity);
      return;
    }

    if (product is Map<String, dynamic>) {
      try {
        final parsedProduct = GetProduct.fromJson(product);
        applyProductToCurrentItem(
          parsedProduct,
          initialQuantity: initialQuantity,
        );
      } catch (_) {}
    }
  }

  Future<void> performBarcodeAutoFill(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return;
    }

    final localProductProvider = ports.products;
    final products = localProductProvider.filterProductByBarcode(
      barCode: normalizedBarcode,
    );

    if (products.isNotEmpty) {
      applyProductToCurrentItem(products.first);
      return;
    }

    final created = await ports.pickProduct(normalizedBarcode);
    if (!mounted) return;

    if (created != null && created['product'] != null) {
      final createdProduct = created['product'];
      final initialQuantity = created['initialQuantity']?.toString();

      if (createdProduct is GetProduct) {
        applyProductToCurrentItem(
          createdProduct,
          initialQuantity: initialQuantity,
        );
      } else if (createdProduct is Map<String, dynamic>) {
        try {
          applyProductToCurrentItem(
            GetProduct.fromJson(createdProduct),
            initialQuantity: initialQuantity,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> autoFillFromBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return;

    currentItem.barcode = normalizedBarcode;
    await performBarcodeAutoFill(normalizedBarcode);
  }
}
