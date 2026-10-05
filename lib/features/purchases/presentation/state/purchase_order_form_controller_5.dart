part of 'purchase_order_form_controller.dart';

extension PurchaseOrderFormControllerOperations5
    on PurchaseOrderFormController {
  Future<void> submitPurchaseOrder() async {
    if (!mounted || isSubmitting) return;
    if (!ports.validate()) return;

    final isReceiveMode = this.isReceiveMode;

    if (selectedSupplier == null) {
      showErrorMessage('purchase_order.please_select_supplier'.tr);
      return;
    }

    if (selectedStore == null) {
      showErrorMessage('purchase_order.please_select_store'.tr);
      return;
    }

    if (orderItems.isEmpty) {
      showErrorMessage('purchase_order.add_at_least_one_item'.tr);
      return;
    }

    final purchaseTotals = this.purchaseTotals;

    // When payment is disabled (PO already fully paid), skip payment entirely.
    final bool effectivePaymentDisabled = isPaymentDisabled;
    final apiPaymentData = effectivePaymentDisabled
        ? {'payment_methods': <String>[], 'paid_amounts': <String, double>{}}
        : convertPaymentDataToPurchaseApiFormat(paymentData);
    final List<String> paymentMethods =
        (apiPaymentData['payment_methods'] as List<String>);
    final Map<String, double> paidAmountsMap =
        (apiPaymentData['paid_amounts'] as Map<String, double>);

    final bool hasPayment =
        !effectivePaymentDisabled && paymentMethods.isNotEmpty;
    final paidAmount = paidAmountsMap.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final List<Map<String, dynamic>> apiItems = [];

    for (final i in orderItems) {
      if (isReceiveMode && i.alreadyReceived) {
        continue;
      }

      if (isReceiveMode && !i.receive) {
        continue;
      }

      if (!isReceiveMode && i.productData?.productId == null) {
        showErrorMessage('purchase_order.item_must_have_valid_product'.tr);
        return;
      }

      final itemValidationError = validatePurchaseItemFields(i);
      if (itemValidationError != null) {
        showErrorMessage(itemValidationError);
        return;
      }

      if (i.receive || isReceiveMode) {
        final receiveValidationError = validateReceiveItemFields(i);
        if (receiveValidationError != null) {
          showErrorMessage(receiveValidationError);
          return;
        }
      }

      if (isReceiveMode) {
        final receiveItem = <String, dynamic>{
          "purchase_item_id": i.id,
          "quantity": double.tryParse(i.quantity) ?? 1,
          "unit_price": double.tryParse(i.purchaseRate) ?? 0,
          "retail_price": double.tryParse(i.retailPrice) ?? 0,
          "wholesale_price": double.tryParse(i.wholesalePrice) ?? 0,
          "mrp": double.tryParse(i.mrp) ?? 0,
          "tax_include": i.taxInclude,
          "tax_include_purchase": i.taxIncludePurchase,
          "wholesale_min_unit": double.tryParse(i.wholesaleMinUnit) ?? 1,
          if (i.unitPriceOverrides.isNotEmpty)
            "unit_prices": unitPricesPayload(i),
          if (i.selectedPurchaseUnit != null) ...{
            "purchase_unit_id": i.selectedPurchaseUnit!.id,
            "purchase_qty": double.tryParse(i.purchaseQty ?? '') ?? 1.0,
          },
        };

        final selectedRack =
            (i.selectedRack != null && i.selectedRack!.isNotEmpty)
                ? i.selectedRack!
                : i.rack;
        if (selectedRack.isNotEmpty) {
          receiveItem["rack"] = selectedRack;
        }

        if (i.expDate != null) {
          receiveItem["expiry_date"] = formatDate(i.expDate!);
        }
        if (i.pkgMfg != null) {
          receiveItem["pkg_mfg"] = formatDate(i.pkgMfg!);
        }

        if (i.barcode.isNotEmpty) {
          receiveItem["batch_number"] = i.barcode;
        }

        apiItems.add(receiveItem);
        continue;
      }

      final variantId = i.productVariantId ?? i.productData?.matchedVariantId;
      final retailPrice = double.tryParse(i.retailPrice);
      final wholesalePrice = double.tryParse(i.wholesalePrice);
      final mrp = double.tryParse(i.mrp);
      final wholesaleMinUnit = double.tryParse(i.wholesaleMinUnit);
      final selectedRack =
          (i.selectedRack != null && i.selectedRack!.isNotEmpty)
              ? i.selectedRack!
              : i.rack;
      final baseItem = <String, dynamic>{
        "product_id": i.productData?.productId,
        if (variantId != null) "product_variant_id": variantId,
        "quantity": double.tryParse(i.quantity) ?? 1,
        "unit_price": double.tryParse(i.purchaseRate) ?? 0,
        "tax_include": i.taxInclude,
        "tax_include_purchase": i.taxIncludePurchase,
        "receive": i.receive,
        if (retailPrice != null) "retail_price": retailPrice,
        if (wholesalePrice != null) "wholesale_price": wholesalePrice,
        if (mrp != null) "mrp": mrp,
        if (wholesaleMinUnit != null) "wholesale_min_unit": wholesaleMinUnit,
        if (selectedRack.isNotEmpty) "rack": selectedRack,
        if (i.unitPriceOverrides.isNotEmpty)
          "unit_prices": unitPricesPayload(i),
        if (i.pkgMfg != null) "pkg_mfg": formatDate(i.pkgMfg!),
        if (i.expDate != null) "expiry_date": formatDate(i.expDate!),
        if (i.barcode.isNotEmpty) "batch_number": i.barcode,
        if (i.selectedPurchaseUnit != null) ...{
          "purchase_unit_id": i.selectedPurchaseUnit!.id,
          "purchase_qty": double.tryParse(i.purchaseQty ?? '1') ?? 1.0,
        },
      };

      if (i.receive) {
        baseItem.addAll({
          "retail_price": retailPrice!,
          "wholesale_price": wholesalePrice!,
          "mrp": mrp!,
          "wholesale_min_unit": wholesaleMinUnit ?? 1,
          "unit": (i.selectedUnit != null && i.selectedUnit!.isNotEmpty)
              ? i.selectedUnit
              : i.unit,
        });
      }

      apiItems.add(baseItem);
    }

    if (isReceiveMode && apiItems.isEmpty) {
      showErrorMessage('purchase_order.select_at_least_one_pending'.tr);
      return;
    }

    final discountValidationMessage =
        discountValidationTotals.discountValidationMessage;
    if (discountValidationMessage != null) {
      showErrorMessage(discountValidationMessage);
      return;
    }

    final paymentValidationMessage = purchaseTotals.validatePaymentAmount(
      paidAmount,
    );
    if (hasPayment && paymentValidationMessage != null) {
      showErrorMessage(paymentValidationMessage);
      return;
    }

    final token = ports.auth.token;
    if (token == null || token.isEmpty) {
      showErrorMessage('purchase_order.session_expired'.tr);
      return;
    }

    final provider = ports.purchases;

    try {
      if (mounted) {
        setState(() {
          isSubmitting = true;
        });
      }

      final result = isReceiveMode
          ? await provider.receivePurchaseOrder(
              accessToken: token,
              purchaseId: purchaseOrderId.toString(),
              invoiceRef: invoiceRefController.text.trim().isEmpty
                  ? null
                  : invoiceRefController.text.trim(),
              discount: purchaseTotals.discountAmount,
              // Omit payment fields entirely when disabled (fully paid PO).
              paymentMethods: hasPayment ? paymentMethods : null,
              paidAmounts: hasPayment ? paidAmountsMap : null,
              items: apiItems,
            )
          : await provider.createPurchaseOrder(
              accessToken: token,
              purchaseDate: formatDate(selectedDate),
              supplierId: selectedSupplier!.id.toString(),
              storeId: selectedStore!.id.toString(),
              voucherNumber: voucherNumberController.text,
              invoiceRef: invoiceRefController.text,
              discount: purchaseTotals.discountAmount,
              paymentMethods: hasPayment ? paymentMethods : null,
              paidAmounts: hasPayment ? paidAmountsMap : null,
              items: apiItems,
            );

      if (!mounted) return;

      // ── Point 5: 422 fallback safety net ─────────────────────────────────
      // The provider surfaces http_status_code for non-200/201 responses.
      final httpStatus = result?['http_status_code'];
      final is422 = httpStatus == 422;

      if (is422) {
        // Parse structured error envelope — support Envelope A, B, top-level.
        String? errorMessage;

        // Envelope A: { "success": false, "errors": { "field": ["msg"] } }
        final errorsA = result?['errors'];
        if (errorsA is Map && errorsA.isNotEmpty) {
          final firstEntry = errorsA.values.first;
          if (firstEntry is List && firstEntry.isNotEmpty) {
            errorMessage = firstEntry.first?.toString();
          } else {
            errorMessage = firstEntry?.toString();
          }
        }

        // Envelope B: { "data": { "field": ["msg"] } }
        if (errorMessage == null) {
          final dataB = result?['data'];
          if (dataB is Map && dataB.isNotEmpty) {
            final firstEntry = dataB.values.first;
            if (firstEntry is List && firstEntry.isNotEmpty) {
              errorMessage = firstEntry.first?.toString();
            } else {
              errorMessage = firstEntry?.toString();
            }
          }
        }

        // Top-level message fallback
        errorMessage ??= result?['message']?.toString() ??
            'purchase_order.payment_error_422'.tr;

        // Only disable payment if the 422 specifically indicates the PO is
        // already fully paid. Other 422 errors (validation, etc.) should show
        // the error but leave payment inputs functional.
        final bool isFullyPaidError =
            isAlreadyFullyPaidPurchaseOrderError(result, errorMessage);

        if (mounted && isFullyPaidError) {
          setState(() {
            paymentData = DynamicPaymentData();
            isPaymentDisabled = true;
          });
        }
        showErrorMessage(errorMessage);
        return;
      }
      // ─────────────────────────────────────────────────────────────────────

      if (result != null &&
          (result['status'] == 'success' ||
              result['status'] == true ||
              (result['message']?.toString().toLowerCase().contains(
                        'success',
                      ) ??
                  false))) {
        await clearDraftFromHive();
        if (!mounted) return;
        showSuccessMessage(
          result['message'] ??
              (isReceiveMode
                  ? 'purchase_order.order_received'.tr
                  : 'purchase_order.order_created'.tr),
        );

        await provider.listPurchaseOrders(accessToken: token, storeId: "all");

        if (!mounted) return;
        provider.activePurchaseOrderDetails = null;

        if (mounted) ports.onComplete();
      } else {
        showErrorMessage(
          result?['message'] ??
              (isReceiveMode
                  ? 'purchase_order.failed_receive_items'.tr
                  : 'purchase_order.failed_create'.tr),
        );
      }
    } catch (e) {
      showErrorMessage(
        'purchase_order.failed_submit_order'.tr.replaceAll(
              '@error',
              e.toString(),
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}
