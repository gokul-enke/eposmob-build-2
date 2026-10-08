part of 'sales_return_form_controller.dart';

extension SalesReturnFormOperations on SalesReturnFormController {
  Future<void> loadInitData() async {
    if (!mounted) return;
    final request = ++ordersRequest;
    final selection = detailsRequest;
    try {
      setState(() {
        initLoading = true;
      });

      final accessToken = ports.token();

      final orderProvider = this;

      final storeId = await ports.storeId() ?? 1;
      if (!mounted || request != ordersRequest) return;

      await orderProvider.fetchOrders(
        accessToken: accessToken,
        storeId: storeId,
      );
    } catch (error, stackTrace) {
      debugPrint('Error in loadInitData: $error');
      debugPrint('Stack Trace for loadInitData: $stackTrace');
    } finally {
      if (mounted && request == ordersRequest && selection == detailsRequest) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  Future<void> searchOrders(page) async {
    if (!mounted) return;
    final request = ++ordersRequest;
    final selection = detailsRequest;
    try {
      setState(() {
        initLoading = true;
      });

      final accessToken = ports.token();
      final orderProvider = this;

      bool wasOrderSelected = isOrderSelected;
      String? prevSelectedOrderId = selectedOrderId;
      String? prevSelectedOrderNumber = selectedOrderNumber;

      await orderProvider.fetchOrders(
        accessToken: accessToken,
        orderNumber: orderNumberController.text,
        customerId: selectedCustomerID,
        date: selectedDate != null ? DateHelper.formatDate(selectedDate!) : '',
        page: page,
      );

      if (!mounted || request != ordersRequest || selection != detailsRequest)
        return;
      if (wasOrderSelected && prevSelectedOrderId != null) {
        debugPrint('Restoring selected order: $prevSelectedOrderNumber');

        setState(() {
          isOrderSelected = true;
          selectedOrderId = prevSelectedOrderId;
          selectedOrderNumber = prevSelectedOrderNumber;
        });

        if (prevSelectedOrderNumber != null &&
            prevSelectedOrderNumber.isNotEmpty) {
          getOrderDetails(prevSelectedOrderNumber);
        }
      } else {
        setState(() {
          initLoading = false;
          isOrderSelected = false;
          selectedOrderId = null;
          selectedOrderNumber = null;
          orderDetailsModelData = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Error in searchOrders: $error');
      debugPrint('Stack Trace for searchOrders: $stackTrace');
      if (mounted && request == ordersRequest && selection == detailsRequest) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  void resetSearch() {
    if (!mounted) return;
    detailsRequest++;
    ordersRequest++;
    setState(() {
      orderNumberController.clear();
      customerNameController.clear();
      amountController.clear();
      emailController.clear();
      phoneController.clear();
      storeController.clear();
      selectedDate = null;
      dateController.clear();
      isOrderSelected = false;
      selectedOrderId = null;
      selectedOrderNumber = null;
      orderDetailsModelData = null;
      activeReturnOrderId = null;
    });
    loadInitData();
  }

  Future<void> refreshData() async {
    if (selectedOrderNumber != null && selectedOrderNumber!.isNotEmpty) {
      await getOrderDetails(selectedOrderNumber!, resetInitialState: false);
    }
  }

  Future<void> getOrderDetails(String ordersId,
      {bool resetInitialState = true}) async {
    if (!mounted) return;
    final request = ++detailsRequest;
    debugPrint(
        "Starting getOrderDetails for order ID: $ordersId (resetInitialState: $resetInitialState)");
    try {
      if (ordersId.isEmpty) {
        debugPrint("Empty order ID provided to getOrderDetails");
        return;
      }

      debugPrint("Fetching sales return items for order ID: $ordersId");

      setState(() {
        initLoading = true;
      });

      await loadReturnItems(ordersId);
      if (!mounted || request != detailsRequest) return;

      try {
        final orderDetailsResponse = await ports.details(ordersId);
        if (!mounted || request != detailsRequest) return;

        if (orderDetailsResponse["status"] == "success") {
          setState(() {
            final orderDetails =
                OrderDetailsModel.fromJson(orderDetailsResponse);
            orderDetailsModelData = orderDetails.data;
          });
          debugPrint('✅ Full order details fetched for $ordersId');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch full order details: $e');
      }

      if (!mounted || request != detailsRequest) return;

      debugPrint('Fetched ${salesReturnItems.length} sales return items');

      if (resetInitialState) {
        activeReturnOrderId = null;
        clearServerRefundBreakdown();
        initialReturnedQuantities.clear();
        initialReturnedTotals.clear();
        for (var item in salesReturnItems) {
          initialReturnedQuantities[item.cartItemId] = item.returnedQuantity;
          initialReturnedTotals[item.cartItemId] =
              double.tryParse(item.returnedTotal.toString()) ?? 0.0;
        }
        debugPrint(
            '🔄 Reset initial return state for ${initialReturnedQuantities.length} items');
      } else {
        debugPrint('✅ Refreshed items without resetting initial state');
      }

      if (salesReturnItems.isNotEmpty) {
        setState(() {
          isOrderSelected = true;
          selectedOrderNumber = ordersId;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Error in getOrderDetails for order ID $ordersId: $error');
      debugPrint('Stack Trace for getOrderDetails: $stackTrace');
      if (mounted && request == detailsRequest) {
        ports.error(
          error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : 'sales_return_form.error_failed_load_items'.tr,
        );
      }
    } finally {
      if (mounted && request == detailsRequest) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  String resolvedProductUnit(SalesReturnCart item) {
    if (item.productUnit.trim().isNotEmpty) {
      return item.productUnit;
    }

    final orderItems = orderDetailsModelData?.cart?.cartItems ?? const [];
    for (final orderItem in orderItems) {
      final sameCartItem = orderItem.id == item.cartItemId;
      final sameProductName = orderItem.productName?.trim().toLowerCase() ==
          item.productName.trim().toLowerCase();
      if (!sameCartItem && !sameProductName) continue;

      final unit = orderItem.productUnit?.trim().isNotEmpty == true
          ? orderItem.productUnit!.trim()
          : orderItem.saleUnitName?.trim() ?? '';
      if (unit.isNotEmpty) return unit;
    }

    return '';
  }

  SalesReturnRefundSummary refundSummaryFor(
    List<SalesReturnCart> items, {
    SalesReturnRefundBreakdown? serverBreakdown,
  }) {
    final shippingCost =
        (orderDetailsModelData?.deliveryCharge ?? 0).toDouble();
    final orderDiscount =
        (orderDetailsModelData?.priceSummary?.discount ?? 0).toDouble();

    if (serverBreakdown != null) {
      return serverBreakdown.toRefundSummary(
        deliveryRefundable: deliveryChargeRefundable,
        shippingCost: shippingCost,
      );
    }

    if (draftReturnOrderId != null) {
      final draftTotal = items.fold<double>(
        0,
        (sum, item) =>
            sum + (double.tryParse(item.returnedTotal.toString()) ?? 0),
      );
      if (draftTotal > 0) {
        return SalesReturnCalculationHelper.calculateFromDraftTotals(
          items: items,
          orderDiscount: orderDiscount,
          shippingCost: shippingCost,
          deliveryRefundable: deliveryChargeRefundable,
        );
      }
    }

    return SalesReturnCalculationHelper.calculateRefund(
      items: items,
      initialReturnedTotals: initialReturnedTotals,
      orderDiscount: orderDiscount,
      shippingCost: shippingCost,
      deliveryRefundable: deliveryChargeRefundable,
    );
  }
}
