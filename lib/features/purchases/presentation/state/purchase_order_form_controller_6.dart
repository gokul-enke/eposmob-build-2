part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations6
    on PurchaseOrderFormController {
  Future<void> calculateTaxForCurrentItem({
    required PurchaseOrderItem item,
    bool isRetail = true,
    bool isPurchase = false,
  }) async {
    final String calculationType =
        isPurchase ? 'Purchase' : (isRetail ? 'Retail' : 'Wholesale');

    if (item.productData == null ||
        item.categoryData == null ||
        item.productData!.productId == null ||
        item.categoryData!.categoryId == null) {
      debugPrint(
        '⚠️ [PurchaseTax] Cannot calculate: product/category missing | type=$calculationType',
      );
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isPurchase) {
            item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
            item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
          } else if (isRetail) {
            item.calculatedTaxData!['retailTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_retail'] = 0.0;
            item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
          } else {
            item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
            item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
          }
        });
      }
      return;
    }

    final double priceToCalculate = isPurchase
        ? (double.tryParse(item.purchaseRate) ?? 0.0)
        : (isRetail
            ? (double.tryParse(item.retailPrice) ?? 0.0)
            : (double.tryParse(item.wholesalePrice) ?? 0.0));
    final bool taxInclude =
        isPurchase ? item.taxIncludePurchase : item.taxInclude;

    debugPrint(
      '🧮 [PurchaseTax] Payload | type=$calculationType | productId=${item.productData!.productId} | categoryId=${item.categoryData!.categoryId} | price=$priceToCalculate | taxInclude=$taxInclude',
    );

    final String? accessToken = ports.auth.token;
    if (accessToken == null) {
      debugPrint('❌ [PurchaseTax] No access token');
      return;
    }

    try {
      final taxData = await ports.stock.calculateTaxAPI(
        accessToken: accessToken,
        price: priceToCalculate,
        productId: item.productData!.productId!,
        categoryId: item.categoryData!.categoryId!,
        taxInclude: taxInclude,
      );

      if (taxData != null && mounted) {
        debugPrint(
          '✅ [PurchaseTax] API success | type=$calculationType | response=$taxData',
        );
        setState(() {
          if (isPurchase) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'purchaseTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_purchase':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_purchase':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_purchase':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else if (isRetail) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'retailTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_retail':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_retail':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_retail':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'wholesaleTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_wholesale':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_wholesale':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_wholesale':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          }
        });
      } else {
        debugPrint('❌ [PurchaseTax] API returned null | type=$calculationType');
        if (mounted) {
          setState(() {
            item.calculatedTaxData ??= {};
            if (isPurchase) {
              item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
              item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
            } else if (isRetail) {
              item.calculatedTaxData!['retailTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_retail'] = 0.0;
              item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
            } else {
              item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
              item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
            }
          });
        }
      }
    } catch (e) {
      debugPrint(
        '💥 [PurchaseTax] Exception | type=$calculationType | error=$e',
      );
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isPurchase) {
            item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
            item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
          } else if (isRetail) {
            item.calculatedTaxData!['retailTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_retail'] = 0.0;
            item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
          } else {
            item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
            item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
          }
        });
      }
    }
  }

  /// Trigger all three tax calculations for the current item (debounced)

  void triggerTaxRecalculation() {
    taxCalcDebounceTimer?.cancel();
    final itemToCalc = currentItem;
    taxCalcDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      calculateTaxForCurrentItem(item: itemToCalc, isRetail: true);
      calculateTaxForCurrentItem(item: itemToCalc, isRetail: false);
      calculateTaxForCurrentItem(item: itemToCalc, isPurchase: true);
    });
  }

  void setSellingTaxInclusion(bool value) {
    setState(() {
      includeTax = value;
      currentItem.taxInclude = value;
    });
    calculateTaxForCurrentItem(item: currentItem, isRetail: true);
    calculateTaxForCurrentItem(item: currentItem, isRetail: false);
    saveDraftToHive();
  }

  void setPurchaseTaxInclusion(bool value) {
    setState(() {
      includeTaxPurchase = value;
      currentItem.taxIncludePurchase = value;
    });
    calculateTaxForCurrentItem(item: currentItem, isPurchase: true);
    saveDraftToHive();
  }

  bool? getSelectAllReceiveState() {
    final unreceivedItems =
        orderItems.where((item) => !item.alreadyReceived).toList();
    if (unreceivedItems.isEmpty) return false;
    final allChecked = unreceivedItems.every((item) => item.receive);
    if (allChecked) return true;
    final noneChecked = unreceivedItems.every((item) => !item.receive);
    if (noneChecked) return false;
    return null; // Tristate / Indeterminate
  }

  void toggleSelectAllReceive(bool? value) {
    final unreceivedItems =
        orderItems.where((item) => !item.alreadyReceived).toList();
    if (unreceivedItems.isEmpty) return;

    final currentState = getSelectAllReceiveState();
    final newTargetState = currentState != true;

    setState(() {
      for (final item in unreceivedItems) {
        item.receive = newTargetState;
      }
      syncPaidAmount();
    });
    saveDraftToHive();
  }

  double getEffectiveRetailPrice(PurchaseOrderItem item) {
    final basePrice = double.tryParse(item.retailPrice) ?? 0.0;
    if (!item.taxInclude) {
      final calculated =
          item.calculatedTaxData?['price_including_tax_retail'] as num?;
      if (calculated != null && calculated > 0) {
        return calculated.toDouble();
      }
      final taxRate = item.productData?.totalTaxRate ?? 0.0;
      if (taxRate > 0) {
        return basePrice * (1 + taxRate / 100);
      }
      debugPrint(
        '⚠️ [PurchaseTax] Fallback used for retail price of ${item.productData?.productName ?? "unknown product"} (ID: ${item.productData?.productId}). basePrice=$basePrice, calculatedTaxData=${item.calculatedTaxData}',
      );
    }
    return basePrice;
  }

  double getEffectiveWholesalePrice(PurchaseOrderItem item) {
    final basePrice = double.tryParse(item.wholesalePrice) ?? 0.0;
    if (!item.taxInclude) {
      final calculated =
          item.calculatedTaxData?['price_including_tax_wholesale'] as num?;
      if (calculated != null && calculated > 0) {
        return calculated.toDouble();
      }
      final taxRate = item.productData?.totalTaxRate ?? 0.0;
      if (taxRate > 0) {
        return basePrice * (1 + taxRate / 100);
      }
      debugPrint(
        '⚠️ [PurchaseTax] Fallback used for wholesale price of ${item.productData?.productName ?? "unknown product"} (ID: ${item.productData?.productId}). basePrice=$basePrice, calculatedTaxData=${item.calculatedTaxData}',
      );
    }
    return basePrice;
  }

  double getSupplierBalance() {
    return selectedSupplier?.currentBalance ?? 0.0;
  }

  Future<void> addSupplier() async {
    final purchaseProvider = ports.purchases;

    final result = await ports.pickSupplier();
    if (!mounted) return;
    if (result != null && result is Map && result['status'] == 'success') {
      final createdPhone = (result['phone'] ?? '').toString();
      try {
        final String? accessToken = ports.auth.token;
        if (accessToken != null) {
          await purchaseProvider.listAllSuppliers(
            accessToken,
            null,
          );
          if (!mounted) return;
          final updatedList = purchaseProvider.getSupplierList ?? [];
          if (updatedList.isNotEmpty) {
            try {
              final newSupplier = updatedList.firstWhere(
                (s) =>
                    s.phone == createdPhone || (s.user?.phone == createdPhone),
              );
              setState(() {
                selectedSupplier = newSupplier;
              });
              saveDraftToHive();
            } catch (_) {
              debugPrint(
                'New supplier not found by phone in refreshed list',
              );
            }
          }
        }
      } catch (e) {
        debugPrint(
          'Error auto-selecting new supplier: $e',
        );
      }
    }
  }
}
