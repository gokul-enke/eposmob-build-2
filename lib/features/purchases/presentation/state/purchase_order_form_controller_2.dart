part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations2
    on PurchaseOrderFormController {
  Future<void> loadDraftFromHive() async {
    if (!mounted || !canPersistDraft) return;

    if (draftBox == null || !draftBox!.isOpen) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (draftBox == null || !draftBox!.isOpen) {
        return;
      }
    }

    try {
      final draftRaw = draftBox!.read();
      if (draftRaw is! Map) return;

      final draft = draftRaw.cast<dynamic, dynamic>();
      final purchaseProvider = ports.purchases;

      final dynamic orderItemsRaw = draft['orderItems'];
      final List<PurchaseOrderItem> restoredItems = [];
      if (orderItemsRaw is List) {
        for (final rawItem in orderItemsRaw) {
          if (rawItem is Map) {
            restoredItems.add(mapToPurchaseOrderItem(rawItem));
          }
        }
      }

      final currentItemRaw = draft['currentItem'];
      final PurchaseOrderItem restoredCurrentItem = (currentItemRaw is Map)
          ? mapToPurchaseOrderItem(currentItemRaw)
          : PurchaseOrderItem();

      GetStoreModelData? restoredStore;
      final int? restoredStoreId = toInt(draft['selectedStoreId']);
      if (restoredStoreId != null &&
          purchaseProvider.getStoreList != null &&
          purchaseProvider.getStoreList!.isNotEmpty) {
        try {
          restoredStore = purchaseProvider.getStoreList!.firstWhere(
            (store) => store.id == restoredStoreId,
          );
        } catch (_) {}
      }

      GetSuppliersModelData? restoredSupplier;
      final int? restoredSupplierId = toInt(draft['selectedSupplierId']);
      if (restoredSupplierId != null &&
          purchaseProvider.getSupplierList != null &&
          purchaseProvider.getSupplierList!.isNotEmpty) {
        try {
          restoredSupplier = purchaseProvider.getSupplierList!.firstWhere(
            (supplier) => supplier.id == restoredSupplierId,
          );
        } catch (_) {}
      }

      isHydratingDraft = true;
      if (!mounted) return;

      setState(() {
        selectedDate = draft['selectedDate'] != null
            ? DateTime.tryParse(draft['selectedDate'].toString()) ??
                DateTime.now()
            : DateTime.now();
        selectedStore = restoredStore ?? selectedStore;
        selectedSupplier = restoredSupplier;
        includeTax = toBool(draft['includeTax']);
        includeTaxPurchase = toBool(
          draft['includeTaxPurchase'],
          fallback: includeTax,
        );
        showItemDetails = draft['showItemDetails'] != false;
        editingItemIndex = toInt(draft['editingItemIndex']);
        ownedItems.addAll(orderItems);
        ownedItems.add(currentItem);
        orderItems = restoredItems;
        currentItem = restoredCurrentItem;
        paymentData = mapToPaymentData(draft['paymentData']);

        currentItem.syncControllers();
      });

      voucherNumberController.text = draft['voucherNumber']?.toString() ?? '';
      invoiceRefController.text = draft['invoiceRef']?.toString() ?? '';
      discountController.text = draft['discount']?.toString() ?? '0';
      barcodeController.text = currentItem.barcode;
      unitController.text = currentItem.unit;
      quantityController.text = currentItem.purchaseQty ?? currentItem.quantity;
      rateController.text = currentItem.purchaseRate;
      retailPriceController.text = currentItem.retailPrice;
      mrpController.text = currentItem.mrp;
      wholesalePriceController.text = currentItem.wholesalePrice;
      wholesaleMinUnitController.text = currentItem.wholesaleMinUnit;
      rackController.text = currentItem.rack;

      if (selectedStore != null) {
        storeSearchController.text = selectedStore?.name ?? '';
      }
      if (selectedSupplier != null) {
        supplierSearchController.text =
            selectedSupplier?.user?.name ?? selectedSupplier?.name ?? '';
      }

      syncPaidAmount();
      debugPrint('✅ Purchase order draft restored successfully');
    } catch (e) {
      debugPrint('❌ Failed to load purchase order draft: $e');
    } finally {
      isHydratingDraft = false;
    }
  }

  Future<void> clearDraftFromHive() async {
    draftSaveDebouncer?.cancel();
    if (draftBox == null || !draftBox!.isOpen) return;
    try {
      await draftBox!.clear();
    } catch (e) {
      debugPrint('❌ Failed to clear purchase order draft: $e');
    }
  }

  Future<void> loadInitialData() async {
    String? token = ports.auth.token;
    if (token != null) {
      final purchaseProvider = ports.purchases;
      final localProducts = ports.products.products;
      await purchaseProvider.listAllStores(token, null);
      if (!mounted) return;
      await purchaseProvider.listAllSuppliers(token, null);
      if (!mounted) return;
      await loadActiveStore();
      if (!mounted) return;
      await loadPaymentMethods();
      if (!mounted) return;

      // Handle pre-population if activePurchaseOrderDetails is set
      if (purchaseProvider.activePurchaseOrderDetails != null) {
        final data = purchaseProvider.activePurchaseOrderDetails!;
        setState(() {
          // Header
          purchaseOrderId = toInt(data['id']); // NEW! Capture the ID
          // Read payment state and disable payment inputs if fully paid.
          final paymentStatus = data['payment_status']?.toString();
          isPaymentDisabled = (paymentStatus == 'paid');
          voucherNumberController.text =
              data['voucher_number']?.toString() ?? "";
          invoiceRefController.text = data['invoice_ref']?.toString() ?? "";
          discountController.text = data['discount']?.toString() ?? "0";
          if (data['purchase_date'] != null) {
            selectedDate =
                DateTime.tryParse(data['purchase_date'].toString()) ??
                    DateTime.now();
          }

          // Store
          if (data['store'] != null) {
            selectedStore = GetStoreModelData.fromJson(data['store']);
            storeSearchController.text = selectedStore?.name ?? "";
          }

          // Supplier
          if (data['supplier'] != null) {
            final supplierFromPayload = GetSuppliersModelData.fromJson(
              data['supplier'],
            );
            final supplierId = supplierFromPayload.id;
            if (supplierId != null &&
                purchaseProvider.getSupplierList != null &&
                purchaseProvider.getSupplierList!.isNotEmpty) {
              try {
                selectedSupplier = purchaseProvider.getSupplierList!.firstWhere(
                  (s) => s.id == supplierId,
                );
              } catch (_) {
                selectedSupplier = supplierFromPayload;
              }
            } else {
              selectedSupplier = supplierFromPayload;
            }
            supplierSearchController.text = selectedSupplier?.name ?? "";
          }

          // Items - Support both 'items' (new list API) and 'purchase_items' (old/detail API)
          final itemsList = data['items'] ?? data['purchase_items'];
          if (itemsList != null) {
            ownedItems.addAll(orderItems);
            orderItems = (itemsList as List).map((item) {
              final itemStatus =
                  (item['status'] ?? '').toString().trim().toUpperCase();
              final isAlreadyReceived = itemStatus == 'Y' ||
                  itemStatus == 'RECEIVED' ||
                  itemStatus == 'FULLY_RECEIVED';
              final unitPrice =
                  (item['unit_price'] ?? item['purchase_rate'] ?? '')
                      .toString();
              final unitPriceValue = double.tryParse(unitPrice) ?? 0;
              final calculatedPurchaseRate = double.tryParse(
                    item['calculated_purchase_rate']?.toString() ?? '',
                  ) ??
                  unitPriceValue;
              final taxInclude = toBool(item['tax_include']);
              final taxIncludePurchase = toBool(
                item['tax_include_purchase'],
                fallback: taxInclude,
              );
              final purchaseUnitId = toInt(item['purchase_unit_id']);

              final productId = toInt(item['product_id']);
              GetProduct? productData;
              if (item['product'] != null) {
                productData = GetProduct.fromJson(item['product']);
              } else if (productId != null) {
                try {
                  productData = localProducts.firstWhere(
                    (product) => product.productId == productId,
                  );
                } catch (_) {}
              }
              productData ??=
                  (item['product_name'] != null || item['name'] != null)
                      ? GetProduct(
                          productId: productId,
                          productName:
                              (item['product_name'] ?? item['name']).toString(),
                        )
                      : null;
              Category? categoryData;
              if (productData != null) {
                categoryData = resolveCategoryForProduct(productData);
              }
              final categoryId = toInt(item['category_id']);
              categoryData ??=
                  categoryId == null ? null : Category(categoryId: categoryId);
              SaleUnit? selectedPurchaseUnit;
              if (purchaseUnitId != null) {
                try {
                  selectedPurchaseUnit = productData?.saleUnits?.firstWhere(
                    (unit) => unit.id == purchaseUnitId,
                  );
                } catch (_) {}
                selectedPurchaseUnit ??= SaleUnit(
                  id: purchaseUnitId,
                  unitName: item['purchase_unit_type']?.toString(),
                  conversionRate:
                      item['purchase_unit_conversion_rate']?.toString(),
                );
              }

              return PurchaseOrderItem(
                id: toInt(item['id']),
                barcode: (item['bar_code'] ??
                        item['barcode'] ??
                        item['batch_number'] ??
                        '')
                    .toString(),

                quantity: item['quantity']?.toString() ?? "1",
                purchaseRate: unitPrice,
                unit: (item['unit'] ?? "").toString(),
                productData: productData,
                categoryData: categoryData,

                // Map additional fields if present in the response
                retailPrice:
                    (item['retail_price'] ?? item['selling_price'] ?? unitPrice)
                        .toString(),
                mrp: (item['mrp'] ?? unitPrice).toString(),
                wholesalePrice:
                    (item['wholesale_price'] ?? unitPrice).toString(),
                wholesaleMinUnit: item['wholesale_min_unit']?.toString() ?? "",
                rack: item['rack']?.toString() ?? "",
                taxInclude: taxInclude,
                taxIncludePurchase: taxIncludePurchase,
                calculatedTaxData: {
                  'purchaseTaxAmount':
                      (calculatedPurchaseRate - unitPriceValue).clamp(
                    0,
                    double.infinity,
                  ),
                  'price_including_tax_purchase': calculatedPurchaseRate,
                  'price_excluding_tax_purchase': unitPriceValue,
                  'tax_rate_purchase': 0.0,
                },
                pkgMfg: item['pkg_mfg'] != null
                    ? DateTime.tryParse(item['pkg_mfg'].toString())
                    : null,
                expDate: item['expiry_date'] != null
                    ? DateTime.tryParse(item['expiry_date'].toString())
                    : null,
                alreadyReceived: isAlreadyReceived,
                productVariantId: toInt(item['product_variant_id']),
                variantName: item['variant_name']?.toString(),
                selectedPurchaseUnit: selectedPurchaseUnit,
                purchaseQty: item['purchase_qty']?.toString(),
                purchaseConversionRate:
                    item['purchase_unit_conversion_rate']?.toString(),
                unitPriceOverrides: parseUnitPriceOverrides(
                  item['unit_prices'],
                ),
              )
                ..receive = false
                ..syncControllers();
            }).toList();
            syncPaidAmount();
          }
        });
        return;
      }

      await loadDraftFromHive();
    }
  }

  Future<void> loadPaymentMethods() async {
    final masterDataProvider = ports.masterData;

    setState(() {
      isLoadingPaymentMethods = true;
    });

    try {
      final cachedMethods = masterDataProvider.paymentMethods;
      final methods = (cachedMethods != null && cachedMethods.isNotEmpty)
          ? cachedMethods
          : (await masterDataProvider.fetchPaymentMethods() ??
              <MasterDataValue>[]);

      if (!mounted) return;

      setState(() {
        paymentMethods = methods;
        isLoadingPaymentMethods = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingPaymentMethods = false;
      });
    }
  }
}
