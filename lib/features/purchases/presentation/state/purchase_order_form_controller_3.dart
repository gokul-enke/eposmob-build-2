part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations3
    on PurchaseOrderFormController {
  Future<void> loadActiveStore() async {
    // Keep behavior same as add stock page: session first, prefs fallback.
    try {
      final storeSession = ports.stores;
      if (storeSession.activeStore != null) {
        final activeStore = storeSession.activeStore!;
        final purchaseProvider = ports.purchases;

        GetStoreModelData? fullStoreData;
        if (purchaseProvider.getStoreList != null) {
          try {
            fullStoreData = purchaseProvider.getStoreList!.firstWhere(
              (s) => s.id == activeStore.id,
            );
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            selectedStore = fullStoreData ??
                GetStoreModelData(
                  id: activeStore.id,
                  name: activeStore.name,
                );
          });
        }
        return;
      }
    } catch (_) {}

    try {
      final int? activeStoreId = await ports.session.activeStoreId();

      if (activeStoreId != null) {
        final purchaseProvider = ports.purchases;

        if (purchaseProvider.getStoreList != null &&
            purchaseProvider.getStoreList!.isNotEmpty) {
          final store = purchaseProvider.getStoreList!.firstWhere(
            (s) => s.id == activeStoreId,
            orElse: () => purchaseProvider.getStoreList!.first,
          );

          if (mounted) {
            setState(() {
              selectedStore = store;
            });
          }
        }
      }
    } catch (_) {}
  }

  void addItem() {
    if (currentItem.productData == null) {
      showErrorMessage('purchase_order.please_select_product'.tr);
      return;
    }

    setState(() {
      currentItem.taxInclude = includeTax;
      currentItem.taxIncludePurchase = includeTaxPurchase;
      currentItem.syncControllers();

      final newProductId = currentItem.productData?.productId;
      final newVariantId = currentItem.productVariantId;
      final newBarcode = currentItem.barcode;

      // Find match helper function
      int? findMatchingItemIndex({int? skipIndex}) {
        if (newProductId == null) return null;
        for (int i = 0; i < orderItems.length; i++) {
          if (skipIndex != null && i == skipIndex) continue;
          final item = orderItems[i];
          if (item.productData?.productId == newProductId &&
              item.productVariantId == newVariantId &&
              item.barcode == newBarcode &&
              purchaseOrderPurchaseUnitsMatch(
                currentItem.selectedPurchaseUnit,
                currentItem.purchaseConversionRate,
                item.selectedPurchaseUnit,
                item.purchaseConversionRate,
              )) {
            return i;
          }
        }
        return null;
      }

      if (isReceiveMode) {
        // Receive rows carry server-side purchase_item_ids. Editing must
        // replace the selected row in place so that its ID remains attached,
        // while adding a new row must never merge with another receive row.
        if (editingItemIndex != null && editingItemIndex! < orderItems.length) {
          orderItems[editingItemIndex!] = currentItem;
        } else {
          orderItems.add(currentItem);
        }
      } else if (editingItemIndex != null &&
          editingItemIndex! < orderItems.length) {
        // Edit Flow: check if the edited item now matches another row
        final matchIdx = findMatchingItemIndex(skipIndex: editingItemIndex);
        if (matchIdx != null) {
          // Merge currentItem into the existing row at matchIdx
          final existing = orderItems[matchIdx];
          final currentQty = double.tryParse(currentItem.quantity) ?? 0.0;
          final existingQty = double.tryParse(existing.quantity) ?? 0.0;

          existing.quantity = (existingQty + currentQty).toString();
          // Update other fields to edited values (prices, units, rack, etc.)
          existing.purchaseRate = currentItem.purchaseRate;
          existing.retailPrice = currentItem.retailPrice;
          existing.wholesalePrice = currentItem.wholesalePrice;
          existing.mrp = currentItem.mrp;
          existing.rack = currentItem.rack;
          existing.selectedRack = currentItem.selectedRack;
          existing.unit = currentItem.unit;
          existing.selectedUnit = currentItem.selectedUnit;
          existing.selectedPurchaseUnit = currentItem.selectedPurchaseUnit;
          existing.purchaseQty = currentItem.purchaseQty;
          existing.purchaseConversionRate = currentItem.purchaseConversionRate;
          existing.pkgMfg = currentItem.pkgMfg;
          existing.expDate = currentItem.expDate;
          existing.taxInclude = currentItem.taxInclude;
          existing.taxIncludePurchase = currentItem.taxIncludePurchase;
          existing.calculatedTaxData = currentItem.calculatedTaxData != null
              ? Map<String, dynamic>.from(currentItem.calculatedTaxData!)
              : null;

          existing.syncControllers();
          // Remove the edited row from the list
          ownedItems.add(orderItems[editingItemIndex!]);
          orderItems.removeAt(editingItemIndex!);
        } else {
          // No match, just update the edited item at index
          orderItems[editingItemIndex!] = currentItem;
        }
      } else {
        // Add Flow: check if the new item matches an existing row
        final matchIdx = findMatchingItemIndex();
        if (matchIdx != null) {
          // Duplicate found — sum quantity and purchaseQty. Do NOT overwrite
          // prices or any other fields; if the user wants to change the price
          // they must use the edit icon on the existing row.
          final existing = orderItems[matchIdx];
          final currentQty = double.tryParse(currentItem.quantity) ?? 0.0;
          final existingQty = double.tryParse(existing.quantity) ?? 0.0;
          existing.quantity = (existingQty + currentQty).toString();

          // Also sum purchaseQty so the API receives consistent values.
          final currentPurchaseQty =
              double.tryParse(currentItem.purchaseQty ?? '') ?? 0.0;
          final existingPurchaseQty =
              double.tryParse(existing.purchaseQty ?? '') ?? 0.0;
          if (currentPurchaseQty > 0 || existingPurchaseQty > 0) {
            existing.purchaseQty =
                (existingPurchaseQty + currentPurchaseQty).toString();
          }

          existing.syncControllers();
        } else {
          // No match, add new item
          orderItems.add(currentItem);
        }
      }

      clearCurrentItemForm();
      syncPaidAmount();
    });
    saveDraftToHive();
  }

  void clearCurrentItemForm() {
    ownedItems.add(currentItem);
    currentItem = PurchaseOrderItem();
    editingItemIndex = null;
    barcodeController.clear();
    unitController.clear();
    quantityController.text = '1';
    rateController.clear();
    retailPriceController.clear();
    mrpController.clear();
    wholesalePriceController.clear();
    wholesaleMinUnitController.clear();
    rackController.clear();
    categorySearchController.clear();
    productSearchController.clear();
    includeTax = true;
    includeTaxPurchase = true;
  }

  void editItem(int index) {
    if (index < 0 || index >= orderItems.length) return;
    final item = orderItems[index];

    if (isReceiveMode && item.alreadyReceived) {
      showErrorMessage('purchase_order.item_already_received_edit'.tr);
      return;
    }

    setState(() {
      editingItemIndex = index;
      ownedItems.add(currentItem);
      currentItem = PurchaseOrderItem(
        id: item.id,
        barcode: item.barcode,
        categoryData: item.categoryData,
        productData: item.productData,
        unit: item.unit,
        selectedUnit: item.selectedUnit,
        quantity: item.quantity,
        purchaseRate: item.purchaseRate,
        retailPrice: item.retailPrice,
        mrp: item.mrp,
        pkgMfg: item.pkgMfg,
        expDate: item.expDate,
        wholesalePrice: item.wholesalePrice,
        wholesaleMinUnit: item.wholesaleMinUnit,
        rack: item.rack,
        selectedRack: item.selectedRack,
        taxInclude: item.taxInclude,
        taxIncludePurchase: item.taxIncludePurchase,
        calculatedTaxData: item.calculatedTaxData != null
            ? Map<String, dynamic>.from(item.calculatedTaxData!)
            : null,
        receive: item.receive,
        alreadyReceived: item.alreadyReceived,
        productVariantId: item.productVariantId,
        variantName: item.variantName,
        selectedPurchaseUnit: item.selectedPurchaseUnit,
        purchaseQty: item.purchaseQty,
        purchaseConversionRate: item.purchaseConversionRate,
        unitPriceOverrides: Map<int, double>.from(item.unitPriceOverrides),
      )..syncControllers();

      barcodeController.text = currentItem.barcode;
      unitController.text = currentItem.unit;
      quantityController.text = currentItem.purchaseQty ?? currentItem.quantity;
      rateController.text = currentItem.purchaseRate;
      retailPriceController.text = currentItem.retailPrice;
      mrpController.text = currentItem.mrp;
      wholesalePriceController.text = currentItem.wholesalePrice;
      wholesaleMinUnitController.text = currentItem.wholesaleMinUnit;
      rackController.text = currentItem.rack;
      includeTax = currentItem.taxInclude;
      includeTaxPurchase = currentItem.taxIncludePurchase;
      showItemDetails = !(item.productData?.saleUnits != null &&
          item.productData!.saleUnits!.isNotEmpty);
    });
    saveDraftToHive();
  }

  void removeItem(int index) {
    if (orderItems.length > index) {
      setState(() {
        ownedItems.add(orderItems[index]);
        orderItems.removeAt(index);
        if (editingItemIndex == index) {
          clearCurrentItemForm();
        } else if (editingItemIndex != null && editingItemIndex! > index) {
          editingItemIndex = editingItemIndex! - 1;
        }
        syncPaidAmount();
      });
      saveDraftToHive();
    }
  }

  double effectivePurchaseRate(PurchaseOrderItem item) {
    final enteredRate = double.tryParse(item.purchaseRate) ?? 0;
    final calculatedRate = double.tryParse(
      item.calculatedTaxData?['price_including_tax_purchase']?.toString() ?? '',
    );
    return resolveEffectivePurchaseRate(
      enteredRate: enteredRate,
      taxIncludePurchase: item.taxIncludePurchase,
      calculatedPurchaseRate: calculatedRate,
    );
  }

  double purchaseLineTotal(PurchaseOrderItem item) {
    final quantity = double.tryParse(item.quantity) ?? 0;
    return quantity * effectivePurchaseRate(item);
  }

  double get totalAmount {
    double total = 0;
    for (var item in orderItems) {
      total += purchaseLineTotal(item);
    }
    return total;
  }

  double get totalReceivedAmount {
    double total = 0;
    for (var item in orderItems) {
      if (item.receive && !item.alreadyReceived) {
        total += purchaseLineTotal(item);
      }
    }
    return total;
  }

  double get applicableGrossAmount =>
      isReceiveMode ? totalReceivedAmount : totalAmount;

  double get discountAmount => parsePurchaseAmount(discountController.text);

  PurchaseOrderTotals get purchaseTotals => PurchaseOrderTotals(
        grossAmount: applicableGrossAmount,
        discountAmount: discountAmount,
      );

  PurchaseOrderTotals get discountValidationTotals => PurchaseOrderTotals(
        grossAmount: totalAmount,
        discountAmount: discountAmount,
      );

  void syncPaidAmount() {
    final nextNetPayable = purchaseTotals.netPayable;
    final previousNetPayable = lastKnownNetPayable;
    lastKnownNetPayable = nextNetPayable;

    final primaryMethod = paymentData.primaryMethod;
    if (primaryMethod == null ||
        paymentData.secondaryMethod != null ||
        previousNetPayable == null) {
      return;
    }

    final currentAmount = parsePurchaseAmount(paymentData.primaryAmount);
    final wasAutoFilled = (currentAmount - previousNetPayable).abs() <= 0.005;
    if (!wasAutoFilled) return;

    paymentData = DynamicPaymentData(
      primaryMethod: primaryMethod,
      primaryAmount: nextNetPayable.toStringAsFixed(2),
    );
  }

  Map<String, dynamic> convertPaymentDataToPurchaseApiFormat(
    DynamicPaymentData paymentData,
  ) {
    final List<String> paymentMethods = [];
    final Map<String, double> paidAmounts = {};

    if (paymentData.primaryMethod != null &&
        paymentData.primaryAmount.isNotEmpty) {
      final double amount = double.tryParse(paymentData.primaryAmount) ?? 0.0;
      if (amount > 0) {
        final methodValue = paymentData.primaryMethod!.value;
        paymentMethods.add(methodValue);
        paidAmounts[methodValue] = amount;
      }
    }

    if (paymentData.secondaryMethod != null &&
        paymentData.secondaryAmount.isNotEmpty) {
      final double amount = double.tryParse(paymentData.secondaryAmount) ?? 0.0;
      if (amount > 0) {
        final methodValue = paymentData.secondaryMethod!.value;
        paymentMethods.add(methodValue);
        paidAmounts[methodValue] = amount;
      }
    }

    return {'payment_methods': paymentMethods, 'paid_amounts': paidAmounts};
  }

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
