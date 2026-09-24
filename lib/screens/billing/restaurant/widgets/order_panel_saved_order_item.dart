// ignore_for_file: invalid_use_of_protected_member

part of 'order_panel.dart';

extension OrderPanelSavedOrderItemExtension on OrderPanelState {
  // Public method called by parent after successful send
  void deleteLoadedDraftIfAny({String? fallbackDraftId}) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    // Check multiple sources for the draft ID to ensure cleanup in all flows:
    // 1. _loadedLocalDraftId (set when a local draft is loaded into cart)
    // 2. fallbackDraftId (passed explicitly by caller, e.g., kitchen send)
    // 3. localProductProvider.currentOrder?.id (set by loadOrderForEditing)
    final targetDraftId = _loadedLocalDraftId ??
        fallbackDraftId ??
        localProductProvider.currentOrder?.id;
    if (targetDraftId != null &&
        targetDraftId.isNotEmpty &&
        localProductProvider.findOrderById(targetDraftId) != null) {
      localProductProvider.deleteSavedOrder(targetDraftId);
      _loadedLocalDraftId = null;
    }

    _refreshLocalDrafts();
  }

  Future<void> _updateSavedItemPrice(
      dynamic cartItem, String newPriceStr) async {
    final newPrice = double.tryParse(newPriceStr);
    if (newPrice == null || newPrice < 0) {
      showScaffoldError(context: context, message: 'restaurant.restaurant_order_item.invalid_price'.tr);
      return;
    }

    // Determine cartItemId
    final cartItemId = cartItem['id'];
    if (cartItemId == null) {
      showScaffoldError(context: context, message: 'restaurant.restaurant_order_item.item_id_not_found'.tr);
      return;
    }

    setState(() {
      _loadingCartItems.add('${cartItemId}_price');
      // _isLoadingOrderDetails = true; // Removed full loader
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      debugPrint(
          '🔄 Updating saved item price: Item $cartItemId to $newPriceStr');

      final response = await cartProvider.updateCartItemPrice(
        cartItemId: int.parse(cartItemId.toString()),
        unitPrice: newPriceStr,
        accessToken: authModel.token ?? '',
        // Pass cartId and customerId if available/needed
        cartId: _selectedOrder['cart']?['id'] ?? _selectedOrder['cart_id'],
        customerId: _selectedOrder['customer_id'] ??
            _selectedOrder['cart']?['customer_id'],
      );

      if (isApiSuccess(response)) {
        debugPrint('✅ Price updated successfully');
        showScaffold(context: context, message: 'restaurant.restaurant_order_item.price_updated'.tr);

        // Refresh the order to show new price
        await _refreshSelectedOrderAfterCartUpdate();
      } else {
        debugPrint('❌ Price update failed: ${response['message']}');
        showScaffoldError(
            context: context,
            message: response['message'] ??
                'restaurant.restaurant_order_item.error_updating_price'.tr);
      }
    } catch (e) {
      debugPrint('❌ Exception updating price: $e');
      showScaffoldError(context: context, message: 'restaurant.restaurant_order_item.error_updating_price'.trParams({'error': '$e'}));
    } finally {
      if (mounted) {
        setState(() {
          _loadingCartItems.remove('${cartItemId}_price');
          // _isLoadingOrderDetails = false; // Removed full loader
        });
      }
    }
  }

  void _showEditItemPriceDialog(dynamic cartItem, {bool isLocal = false}) {
    final double price = isLocal
        ? (cartItem as LocalCartItem).price ?? 0.0
        : (double.tryParse((cartItem['unit_price'] ?? cartItem['price'] ?? 0)
                .toString()) ??
            0.0);

    final String productName = isLocal
        ? (cartItem as LocalCartItem).displayName
        : (cartItem['product']?['name'] ?? cartItem['product_name'] ?? 'Item');

    final TextEditingController priceController =
        TextEditingController(text: price.toStringAsFixed(2));

    // Auto-select all text when dialog opens
    priceController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: priceController.text.length,
    );

    void handleUpdate() {
      Provider.of<KeyboardProvider>(context, listen: false).hide();
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context);
      final newPriceStr = priceController.text;
      final newPrice = double.tryParse(newPriceStr);

      if (newPrice != null && newPrice >= 0) {
        if (isLocal) {
          // Update Local Item
          final localItem = cartItem as LocalCartItem;
          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);
          localProductProvider.updateItemPrice(
            localItem.product.productId!,
            localItem.selectedStock,
            newPrice,
            stockGroupIds: localItem.stockGroupIds,
            saleUnitId: localItem.saleUnitId,
            variantId: localItem.variantId,
          );
        } else {
          // Update Saved Item
          _updateSavedItemPrice(cartItem, newPriceStr);
        }
      } else {
        showScaffoldError(context: context, message: 'restaurant.restaurant_order_item.invalid_price'.tr);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.edit, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'billing.edit_price'.tr,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18,
                    0.21, const Color(0xFF1E293B)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'restaurant.restaurant_order_item.current_price'.trParams({'price': price.toStringAsFixed(2)}),
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                    0.21, const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: priceController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => handleUpdate(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  labelText: 'restaurant.new_unit_price'.tr,
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  prefixText: ' ',
                  prefixStyle: const TextStyle(
                      color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Provider.of<KeyboardProvider>(context, listen: false).show(
                      'number', priceController,
                      replaceOnFirstInput: true);
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .hide();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'general.cancel'.tr,
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s14, 0.21, const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'restaurant.update'.tr,
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s14, 0.21, Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showEditItemQuantityDialog(dynamic cartItem, {bool isLocal = false}) {
    final double quantity = isLocal
        ? (cartItem as LocalCartItem).quantity.toDouble()
        : (double.tryParse((cartItem['quantity'] ?? 1).toString()) ?? 1.0);

    final String productName = isLocal
        ? (cartItem as LocalCartItem).displayName
        : (cartItem['product']?['name'] ?? cartItem['product_name'] ?? 'Item');

    final TextEditingController quantityController =
        TextEditingController(text: quantity.toStringAsFixed(0));

    quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: quantityController.text.length,
    );

    void handleUpdate() {
      Provider.of<KeyboardProvider>(context, listen: false).hide();
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context);
      final newQtyStr = quantityController.text;
      final newQty = double.tryParse(newQtyStr);

      if (newQty != null && newQty > 0) {
        if (isLocal) {
          final localItem = cartItem as LocalCartItem;
          _updateCurrentCartItemQuantity(localItem, newQty);
        } else {
          _updateCartItemQuantityWithLoading(cartItem, newQty, 'increase');
        }
      } else {
        showScaffoldError(context: context, message: 'restaurant.restaurant_order_item.invalid_quantity'.tr);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.numbers_rounded,
                    color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'restaurant.edit_qty'.tr,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18,
                    0.21, const Color(0xFF1E293B)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'restaurant.restaurant_order_item.current_quantity'.trParams({'quantity': quantity.toStringAsFixed(0)}),
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                    0.21, const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: quantityController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => handleUpdate(),
                keyboardType: TextInputType.number,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  labelText: 'restaurant.new_qty'.tr,
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF059669), width: 2),
                  ),
                ),
                onTap: () {
                  Provider.of<KeyboardProvider>(context, listen: false).show(
                      'number', quantityController,
                      replaceOnFirstInput: true);
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .hide();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'general.cancel'.tr,
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s14, 0.21, const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'restaurant.update'.tr,
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s14, 0.21, Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedOrderItem(dynamic cartItem, int index) {
    final productName = cartItem['product']?['name'] ??
        cartItem['product_name'] ??
        cartItem['names']?[0]?['name'] ??
        'Unknown Product';
    final quantity = double.tryParse(cartItem['quantity'].toString()) ?? 0.0;
    final unitPrice = double.tryParse(cartItem['unit_price'].toString()) ?? 0.0;
    final totalPrice = double.tryParse(cartItem['total_price'].toString()) ??
        (quantity * unitPrice);

    final status = cartItem['status']?.toString();
    final statusUpper = (status ?? '').toUpperCase();
    final hasStarted = statusUpper == 'PREPARING' ||
        statusUpper == 'COOKING' ||
        statusUpper == 'IN_PROGRESS' ||
        statusUpper == 'READY' ||
        statusUpper == 'SERVED' ||
        statusUpper == 'COMPLETED';
    final isRemovable = !hasStarted;
    final statusText = _statusTextForDisplay(status);

    // Highlight newly added item: matches product ID and has no status yet
    final cartItemProductId = cartItem['product_id']?.toString() ??
        cartItem['product']?['id']?.toString();
    final isHighlighted = _highlightedCartItemProductId != null &&
        cartItemProductId == _highlightedCartItemProductId.toString() &&
        status == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFF059669).withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF059669) : Colors.grey.shade200,
          width: isHighlighted ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name, editable unit price, line total, and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        productName,
                        style: buildCustomStyle(
                            FontWeightManager.bold,
                            widget.isCompact ? FontSize.s13 : FontSize.s15,
                            0.21,
                            const Color(0xFF1E293B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_price')
                            ? null
                            : () => _showEditItemPriceDialog(
                                  cartItem,
                                  isLocal: false,
                                ),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_price')
                              ? SizedBox(
                                  width: widget.isCompact ? 14 : 16,
                                  height: widget.isCompact ? 14 : 16,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                )
                              : Text(
                                  unitPrice.toStringAsFixed(2),
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s11,
                                    0.21,
                                    const Color(0xFF2563EB),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          _loadingCartItems.contains('${cartItem['id']}_price')
                              ? null
                              : () => _showEditItemPriceDialog(
                                    cartItem,
                                    isLocal: false,
                                  ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          totalPrice.toStringAsFixed(2),
                          style: buildCustomStyle(
                              FontWeightManager.bold,
                              widget.isCompact ? FontSize.s13 : FontSize.s14,
                              0.21,
                              const Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusColor(status).withOpacity(0.4)),
                    ),
                    child: Text(
                      statusText,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s10 : FontSize.s11,
                        0.21,
                        _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity controls with modern styling (for saved orders, these will use cart API)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                    .contains('${cartItem['id']}_decrease') ||
                                !isRemovable
                            ? null
                            : () => _updateCartItemQuantityWithLoading(
                                cartItem, quantity - 1, 'decrease'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_decrease')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFDC2626),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.remove,
                                  size: widget.isCompact ? 16 : 18,
                                  color: isRemovable
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: isRemovable
                          ? () => _showEditItemQuantityDialog(cartItem,
                              isLocal: false)
                          : null,
                      child: Container(
                        width: widget.isCompact ? 32 : 40,
                        alignment: Alignment.center,
                        child: Text(
                          quantity.toStringAsFixed(0),
                          style: buildCustomStyle(
                              FontWeightManager.bold,
                              widget.isCompact ? FontSize.s14 : FontSize.s16,
                              0.21,
                              isRemovable
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_increase')
                            ? null
                            : () => _updateCartItemQuantityWithLoading(
                                cartItem, quantity + 1, 'increase'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_increase')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF059669),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.add,
                                  size: widget.isCompact ? 16 : 18,
                                  color: const Color(0xFF059669),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Comment and Remove buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartItem['comment'] != null &&
                      cartItem['comment'].toString().isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.isCompact ? 90 : 130,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cartItem['comment'].toString(),
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.21,
                            const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  // Comment button for saved order item
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _showItemCommentDialog(cartItem, isLocal: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? Icons.chat
                              : Icons.chat_bubble_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  if (isRemovable) ...[
                    const SizedBox(width: 8),
                    // Remove button with modern styling
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_remove')
                            ? null
                            : () => _removeCartItemWithLoading(cartItem),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_remove')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFDC2626),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.delete_outline,
                                  size: widget.isCompact ? 16 : 18,
                                  color: const Color(0xFFDC2626),
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
