part of 'purchase_provider.dart';

extension PurchaseProviderOperations2 on PurchaseProvider {
  Future<dynamic> _listAllPurchaseItemsOperation(
    String accessToken,
  ) async {
    final request = await repository.prepareListAllPurchaseItems(accessToken);
    try {
      final response = await request.send();
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        ListPurchaseItemModel listPurchaseItemModel = response.items;

        purchaseItems = listPurchaseItemModel.data ?? [];

        _notifyPurchaseListeners();
        return response.json;
      } else {}
    } finally {}
  }
  //          *********************** ADD PURCHASE ITEM API ***************************************************

  Future<dynamic> _addPurchaseItemOperation({
    required String categoryId,
    required String productId,
    required String quantity,
    required String unit,
    required String supplierId,
    required String storeId,
    required String batchNumber,
    required String accessToken,
  }) async {
    return repository.addPurchaseItem(
        categoryId: categoryId,
        productId: productId,
        quantity: quantity,
        unit: unit,
        supplierId: supplierId,
        storeId: storeId,
        batchNumber: batchNumber,
        accessToken: accessToken);
  }

  Future<dynamic> _addPurchaseProductStockAPIOperation({
    required String accessToken,
    required String purchaseItemId,
    required String quantity,
    required String purchaseRate,
    required String retailPrice,
    required String wholesalePrice,
    required String wholesaleMinUnit,
    required String expiryDate,
    required String batchNumber,
    required String unit,
  }) async {
    return repository.addPurchaseProductStockAPI(
        accessToken: accessToken,
        purchaseItemId: purchaseItemId,
        quantity: quantity,
        purchaseRate: purchaseRate,
        retailPrice: retailPrice,
        wholesalePrice: wholesalePrice,
        wholesaleMinUnit: wholesaleMinUnit,
        expiryDate: expiryDate,
        batchNumber: batchNumber,
        unit: unit);
  } //          *********************** ADD PURCHASE  API ***************************************************

  Future<dynamic> _addPurchaseOperation({
    required String purchaseId,
    required String accessToken,
  }) async {
    return repository.addPurchase(
        purchaseId: purchaseId, accessToken: accessToken);
  } //          *********************** REMOVE PURCHASE ITEM API ***************************************************

  Future<dynamic> _removePurchaseItemOperation({
    required String itemId,
    required String accessToken,
  }) async {
    return repository.removePurchaseItem(
        itemId: itemId, accessToken: accessToken);
  }
  //          *********************** FINISH PURCHASE ORDER API ***************************************************

  Future<dynamic> _finishPurchaseOrderOperation({
    required String accessToken,
    String? purchaseId,
    String? purchaseVoucherId,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
  }) async {
    return repository.finishPurchaseOrder(
        accessToken: accessToken,
        purchaseId: purchaseId,
        purchaseVoucherId: purchaseVoucherId,
        paymentMethods: paymentMethods,
        paidMethods: paidMethods);
  }

  Future<void> _listPurchaseOrdersOperation({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    final request = await repository.prepareListPurchaseOrders(
        accessToken: accessToken,
        storeId: storeId,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page);
    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final jsonData = response.json;
        if (jsonData["status"] == "success") {
          listPurchaseOrderModel = response.orders;
          listPurchaseOrderCurrentPage =
              listPurchaseOrderModel?.data?.currentPage ?? 1;
          listPurchaseOrderTotalPages =
              listPurchaseOrderModel?.data?.lastPage ?? 1;
          purchaseOrdersList = listPurchaseOrderModel?.data?.data ?? [];
        } else {
          purchaseOrdersList = [];
        }
        _notifyPurchaseListeners();
      } else {
        purchaseOrdersList = [];
        _notifyPurchaseListeners();
      }
    } catch (e) {
      debugPrint("Error making API request: $e");
      purchaseOrdersList = [];
      _notifyPurchaseListeners();
    }
  }

  Future<void> _fetchPurchaseOrderDetailsOperation({
    required String accessToken,
    required String purchaseId,
  }) async {
    isLoading = true;
    _notifyPurchaseListeners();
    try {
      final request = await repository.prepareFetchPurchaseOrderDetails(
          accessToken: accessToken, purchaseId: purchaseId);
      final response = await request.send();

      debugPrint("Details response status: ${response.statusCode}");
      debugPrint("Details response body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = response.json;
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          activePurchaseOrderDetails = jsonData['data'];

          // Map to PurchaseItem for PurchaseDetailsPage compatibility
          if (jsonData['data']['purchase_items'] != null) {
            listPurchaseItemView = response.detailItems;

            // Map header data to voucherDetails
            voucherDetails = response.detailVoucher;

            // Map to ListPurchaseModelDataDetails for PurchaseDetailsPage compatibility
            ListPurchaseModelDataDetails = response.detailHeader;
          } else {
            listPurchaseItemView = [];
            voucherDetails = null;
          }
        }
      } else {
        debugPrint("Failed to fetch details: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching purchase details: $e");
    } finally {
      isLoading = false;
      _notifyPurchaseListeners();
    }
  }

  Future<dynamic> _createPurchaseOrderOperation({
    required String accessToken,
    required String purchaseDate,
    required String supplierId,
    required String storeId,
    String? voucherNumber,
    String? invoiceRef,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
    required List<Map<String, dynamic>> items,
  }) async {
    return repository.createPurchaseOrder(
        accessToken: accessToken,
        purchaseDate: purchaseDate,
        supplierId: supplierId,
        storeId: storeId,
        voucherNumber: voucherNumber,
        invoiceRef: invoiceRef,
        discount: discount,
        paymentMethods: paymentMethods,
        paidAmounts: paidAmounts,
        items: items);
  }

  Future<dynamic> _receivePurchaseOrderOperation({
    required String accessToken,
    required String purchaseId,
    required List<Map<String, dynamic>> items,
    String? invoiceRef, // NEW!
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) async {
    return repository.receivePurchaseOrder(
        accessToken: accessToken,
        purchaseId: purchaseId,
        items: items,
        invoiceRef: invoiceRef,
        discount: discount,
        paymentMethods: paymentMethods,
        paidAmounts: paidAmounts,
        timeoutMessage: 'purchase_order.receive_timeout'.tr);
  }
  // ── Purchase Returns ────────────────────────────────────────────────

  Future<void> _listPurchaseReturnsOperation(
          {required String accessToken,
          int? page,
          String? supplierId,
          String? dateFrom,
          String? dateTo}) =>
      purchaseReturnProvider.listPurchaseReturns(
          accessToken: accessToken,
          page: page,
          supplierId: supplierId,
          dateFrom: dateFrom,
          dateTo: dateTo);
  Future<PurchaseReturnData?> _fetchPurchaseReturnDetailsOperation(
          {required String accessToken, required int returnId}) =>
      purchaseReturnProvider.fetchPurchaseReturnDetails(
          accessToken: accessToken, returnId: returnId);
  Future<void> _fetchReturnableItemsOperation(
          {required String accessToken, required int purchaseVoucherId}) =>
      purchaseReturnProvider.fetchReturnableItems(
          accessToken: accessToken, purchaseVoucherId: purchaseVoucherId);
  Future<Map<String, dynamic>> _createPurchaseReturnOperation(
          {required String accessToken,
          required int purchaseVoucherId,
          required String returnDate,
          required List<Map<String, dynamic>> items,
          bool hasPayment = false,
          double? paidAmount,
          String? paymentMethod}) =>
      purchaseReturnProvider.createPurchaseReturn(
          accessToken: accessToken,
          purchaseVoucherId: purchaseVoucherId,
          returnDate: returnDate,
          items: items,
          hasPayment: hasPayment,
          paidAmount: paidAmount,
          paymentMethod: paymentMethod);
}
