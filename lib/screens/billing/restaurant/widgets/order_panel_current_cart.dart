// ignore_for_file: invalid_use_of_protected_member

part of 'order_panel.dart';

extension OrderPanelCurrentCartExtension on OrderPanelState {
  Widget _buildCurrentCartItem(LocalCartItem cartItem, int index) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    final productName = cartItem.product.productName ?? 'Unknown Product';
    final quantity = cartItem.quantity;
    final unitPrice = cartItem.price ?? 0.0;
    final totalPrice = quantity * unitPrice;

    return Container(
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currency ${totalPrice.toStringAsFixed(2)}',
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s12,
                      0.21, const Color(0xFF059669)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit price and quantity info
          Row(
            children: [
              // Editable Price Trigger for Local Items (Blue Box style)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _showEditItemPriceDialog(cartItem, isLocal: true),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.withOpacity(0.05),
                    ),
                    child: Text(
                      '$currency ${unitPrice.toStringAsFixed(2)}',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          widget.isCompact ? FontSize.s11 : FontSize.s12,
                          0.21,
                          const Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),
              Text(
                ' × ${quantity.toStringAsFixed(0)}',
                style: buildCustomStyle(
                    FontWeightManager.medium,
                    widget.isCompact ? FontSize.s11 : FontSize.s12,
                    0.21,
                    const Color(0xFF64748B)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity controls with modern styling (for current cart, these will use local provider)
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
                        onTap: () => _updateCurrentCartItemQuantity(
                            cartItem, quantity - 1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.remove,
                            size: widget.isCompact ? 16 : 18,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: widget.isCompact ? 32 : 40,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toStringAsFixed(0),
                        style: buildCustomStyle(FontWeightManager.bold,
                            FontSize.s14, 0.21, const Color(0xFF1E293B)),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _updateCurrentCartItemQuantity(
                            cartItem, quantity + 1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartItem.comment != null && cartItem.comment!.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.isCompact ? 90 : 130,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cartItem.comment!,
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
                  // Comment button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _showItemCommentDialog(cartItem, isLocal: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? Icons.chat
                              : Icons.chat_bubble_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Remove button with modern styling
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeCurrentCartItem(cartItem),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Footer actions for current cart (New Order flow)
  Widget _buildCurrentCartActionButtons(List<LocalCartItem> cartItems) {
    final showSendToKitchen = widget.tableId != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.isCompact ? 10.0 : 12.0,
          8,
          widget.isCompact ? 10.0 : 12.0,
          widget.isCompact ? 10.0 : 12.0,
        ),
        child: Container(
          padding: EdgeInsets.all(widget.isCompact ? 10.0 : 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCurrentCartSummaryCard(cartItems),
              const SizedBox(height: 12),
              // Top: Comment button (full width)
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCommentDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: widget.isCompact ? 44 : 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _orderComment.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.comment,
                              color: _orderComment.isNotEmpty
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                              size: widget.isCompact ? 14 : 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Comment',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  widget.isCompact
                                      ? FontSize.s13
                                      : FontSize.s14,
                                  0.21,
                                  const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCurrentCartFooterButton(
                      label: 'Clear',
                      color: const Color(0xFFDC2626),
                      isDisabled: cartItems.isEmpty,
                      onTap: () => _clearCurrentCart(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCurrentCartFooterButton(
                      label: 'Save',
                      color: const Color(0xFF2563EB),
                      isDisabled: cartItems.isEmpty ||
                          (widget.tableId == null &&
                              (widget.preselectedDeliveryMethodId == null ||
                                  widget.preselectedDeliveryMethodId!.isEmpty)),
                      onTap: () => _saveCurrentCartAsPending(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (showSendToKitchen) ...[
                    Expanded(
                      flex: 2,
                      child: _buildCurrentCartFooterButton(
                        label: 'Send To Kitchen',
                        color: const Color(0xFF059669),
                        isDisabled: cartItems.isEmpty || widget.isLoadingPrint,
                        isLoading: widget.isLoadingPrint,
                        onTap: () => widget.onPrintOrder(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCartSummaryCard(List<LocalCartItem> cartItems) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    double netAmount = 0.0;
    for (final item in cartItems) {
      final unitPrice = item.price ?? 0.0;
      netAmount += unitPrice * item.quantity;
    }
    final totalPayable = netAmount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(
            'Net Amount',
            '$currency ${netAmount.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFFE4E4ED)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total Payable',
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF3B82F6),
            isBold: true,
            large: true,
          ),
          _buildSummaryRow(
            'Total Paid',
            '$currency 0.00',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'Balance',
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF00C739),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCartFooterButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    final disabled = isDisabled || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.isCompact ? 44 : 48,
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFF94A3B8) : color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: widget.isCompact ? 16 : 20,
                    height: widget.isCompact ? 16 : 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            widget.isCompact ? FontSize.s12 : FontSize.s13,
                            0.21,
                            Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Methods for current cart operations
  Future<void> _updateCurrentCartItemQuantity(
      LocalCartItem cartItem, double newQuantity) async {
    if (newQuantity <= 0) {
      await _removeCurrentCartItem(cartItem);
      return;
    }

    try {
      debugPrint(
          '🔄 _updateCurrentCartItemQuantity: Updating quantity for ${cartItem.product.productName} to ${newQuantity.toInt()}');

      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        context: context,
        cartItem: cartItem,
        newQuantity: newQuantity,
      );

      if (result.changed) {
        showScaffold(
          context: context,
          message: 'Item quantity updated successfully',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to update quantity: ${e.toString()}',
      );
    }
  }

  Future<void> _removeCurrentCartItem(LocalCartItem cartItem) async {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      debugPrint(
          '🗑️ _removeCurrentCartItem: Removing ${cartItem.product.productName} from cart');

      // Use LocalProductProvider to remove the item
      localProductProvider.removeFromCart(
        cartItem.product.productId!,
        cartItem.selectedStock,
        stockGroupIds: cartItem.stockGroupIds,
        saleUnitId: cartItem.saleUnitId,
      );

      showScaffold(
        context: context,
        message: 'Item removed successfully',
      );
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to remove item: ${e.toString()}',
      );
    }
  }

  Future<void> _clearCurrentCart() async {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isNotEmpty) {
        debugPrint('🗑️ _clearCurrentCart: Clearing local cart');

        // Use LocalProductProvider to clear the cart
        localProductProvider.clearCart();
        setState(() {
          _orderComment = '';
          _loadedLocalDraftId = null;
        });

        showScaffold(
          context: context,
          message: 'Cart cleared successfully',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to clear cart: ${e.toString()}',
      );
    }
  }

  // Save current cart locally as a PENDING draft for the active table/delivery method
  Future<void> _saveCurrentCartAsPending() async {
    if (widget.tableId == null &&
        (widget.preselectedDeliveryMethodId == null ||
            widget.preselectedDeliveryMethodId!.isEmpty)) {
      showScaffoldError(
          context: context, message: 'Select a table or delivery method first');
      return;
    }

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final isNonTableOrderContext = widget.tableId == null &&
          (widget.preselectedDeliveryMethodId?.isNotEmpty == true ||
              (widget.allowCounterBilling && widget.isCounterBillingMode));

      debugPrint('📝 [_saveCurrentCartAsPending] START');
      debugPrint('📝 tableId: ${widget.tableId}');
      debugPrint(
          '📝 preselectedDeliveryMethodId: ${widget.preselectedDeliveryMethodId}');
      debugPrint('📝 isNonTableOrderContext: $isNonTableOrderContext');
      debugPrint('📝 cartItemsCount: ${localProductProvider.cartItems.length}');

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: 'No items in cart to save');
        return;
      }

      final paymentData = _getLocalDraftPaymentData();
      final draftComment = widget.tableId != null
          ? buildTaggedDraftComment(widget.tableId!)
          : _orderComment.trim();
      debugPrint('📝 draftComment: "$draftComment"');
      debugPrint('📝 deliveryMethodForDraft: $deliveryMethodForDraft');
      debugPrint('📝 deliveryMethodIdForDraft: $deliveryMethodIdForDraft');
      debugPrint('📝 selectedCustomerIdForDraft: $selectedCustomerIdForDraft');
      debugPrint('📝 paymentData: $paymentData');

      // If a local draft is loaded, update it instead of creating a new one
      if (_loadedLocalDraftId != null) {
        debugPrint('📝 Updating existing local draft $_loadedLocalDraftId');
        localProductProvider.updateSavedOrder(
          _loadedLocalDraftId!,
          customerName: selectedCustomerNameForDraft,
          customerPhone: selectedCustomerPhoneForDraft,
          comment: draftComment.isNotEmpty ? draftComment : null,
          deliveryMethod: deliveryMethodForDraft,
          customerId: selectedCustomerIdForDraft,
          paymentMethod: paymentData['paymentMethod'],
          paidAmount: paymentData['paidAmount'],
          balanceAmount: balanceAmountForDraft,
          transactionId: transactionNumberForDraft,
          couponId: couponIdForDraft,
          deliveryMethodId: deliveryMethodIdForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        showScaffold(context: context, message: 'Updated local draft');
      } else {
        debugPrint('📝 Creating new local draft');
        final saved = localProductProvider.saveCurrentCartAsOrder(
          customerName: selectedCustomerNameForDraft,
          customerPhone: selectedCustomerPhoneForDraft,
          comment: draftComment.isNotEmpty ? draftComment : null,
          deliveryMethod: deliveryMethodForDraft,
          customerId: selectedCustomerIdForDraft,
          paymentMethod: paymentData['paymentMethod'],
          paidAmount: paymentData['paidAmount'],
          balanceAmount: balanceAmountForDraft,
          transactionId: transactionNumberForDraft,
          couponId: couponIdForDraft,
          deliveryMethodId: deliveryMethodIdForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        showScaffold(
            context: context,
            message: 'Saved local draft ${saved.orderNumber}');
      }

      // Clear cart and refresh local drafts
      localProductProvider.clearCart();
      setState(() {
        _loadedLocalDraftId = null;
        _orderComment = '';
        _activeOrderPanelTab = OrderPanelTab.saved;
        _showSavedOrdersView = true;
      });
      _refreshLocalDrafts();
    } catch (e) {
      showScaffoldError(
          context: context,
          message: 'Failed to save local draft: ${e.toString()}');
    }
  }

  // Refresh local drafts from Hive filtered by table tag and pending status
  Future<void> _refreshLocalDrafts() async {
    final hasSelectedCustomer = _selectedCustomer != null ||
        _selectedCustomerID != null ||
        (_selectedCustomerPhone?.isNotEmpty ?? false);
    if (!hasSelectedCustomer) {
      _isCustomerManuallySelected = false;
      _applyDefaultCustomer();
    }

    try {
      final localProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final drafts = localProvider.savedOrders.where((o) {
        final st = (o.status ?? '').toLowerCase();
        if (st != 'pending') return false;
        // In counter billing mode, Orders should show every local pending draft
        // even before the user chooses Dining or Delivery.
        if (_usesCounterOrderTabs) {
          return true;
        }
        // Filter by table when a table is selected
        if (widget.tableId != null) {
          return o.tableId == widget.tableId;
        }
        // Filter by delivery method when no table is selected
        if (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty) {
          return o.tableId == null &&
              o.deliveryMethodId == widget.preselectedDeliveryMethodId;
        }
        return false;
      }).toList();
      setState(() {
        _localDrafts = drafts;
      });
    } catch (_) {}
  }

  // Delete local draft
  void _deleteLocalDraft(SavedOrder order) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.deleteSavedOrder(order.id);
    _refreshLocalDrafts();
  }

  // Local draft item card
  Widget _buildLocalDraftItem(SavedOrder order) {
    final int totalItems = order.items.length;
    final tableName = _localDraftTableName(order);
    final contextLabel = tableName != null
        ? 'Dining: $tableName'
        : ((order.deliveryMethod?.isNotEmpty ?? false)
            ? 'Delivery: ${order.deliveryMethod}'
            : 'No context');
    final contextIcon =
        tableName != null ? Icons.restaurant_rounded : Icons.local_shipping;
    final customerLabel = _localDraftCustomerLabel(order);
    final comment = this._cleanDraftComment(order.comment);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Load back to current cart for editing
          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);
          _loadedLocalDraftId = order.id;
          localProductProvider.loadOrderForEditing(order.id);
          _rehydrateLocalDraftMetadata(order);
          widget.onLocalDraftLoaded?.call(order);
          showCurrentOrderTab(preserveLoadedDraftMetadata: true);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s13 : FontSize.s15,
                        0.21,
                        const Color(0xFF1E293B)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD97706).withOpacity(0.4)),
                        ),
                        child: Text(
                          'PENDING',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s10 : FontSize.s11,
                              0.21,
                              const Color(0xFFD97706)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalItems',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s11 : FontSize.s13,
                              0.21,
                              const Color(0xFF059669)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _deleteLocalDraft(order),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: widget.isCompact ? 16 : 18,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildLocalDraftInfoChip(
                    icon: contextIcon,
                    label: contextLabel,
                    color: tableName != null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF059669),
                  ),
                  if (customerLabel != null)
                    _buildLocalDraftInfoChip(
                      icon: Icons.person_rounded,
                      label: customerLabel,
                      color: const Color(0xFF7C3AED),
                    ),
                  if (order.deliveryDate?.isNotEmpty == true ||
                      order.deliveryTime?.isNotEmpty == true)
                    _buildLocalDraftInfoChip(
                      icon: Icons.schedule_rounded,
                      label: [
                        if (order.deliveryDate?.isNotEmpty == true)
                          order.deliveryDate,
                        if (order.deliveryTime?.isNotEmpty == true)
                          order.deliveryTime,
                      ].whereType<String>().join(' '),
                      color: const Color(0xFF64748B),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      comment.isNotEmpty ? comment : 'No note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                          FontWeightManager.medium,
                          widget.isCompact ? FontSize.s11 : FontSize.s13,
                          0.21,
                          const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Items: $totalItems',
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        widget.isCompact ? FontSize.s11 : FontSize.s13,
                        0.21,
                        const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _localDraftTableName(SavedOrder order) {
    if (order.tableId == null || order.tableId!.isEmpty) return null;
    try {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      for (final table in tableProvider.tables) {
        if (table.id == order.tableId) {
          return table.name;
        }
      }
    } catch (_) {
      // Fall through to id display when provider is not ready.
    }
    return order.tableId;
  }

  String? _localDraftCustomerLabel(SavedOrder order) {
    final name = order.customerName?.trim();
    final phone = order.customerPhone?.trim();
    if (name != null && name.isNotEmpty && phone != null && phone.isNotEmpty) {
      return '$name / $phone';
    }
    if (name != null && name.isNotEmpty) return name;
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  Widget _buildLocalDraftInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: widget.isCompact ? 13 : 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                widget.isCompact ? FontSize.s10 : FontSize.s11,
                0.21,
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Safe comment cleaner: strips TABLE:<id> prefix without regex
  String _cleanDraftComment(String? comment) {
    final c = (comment ?? '').trim();
    if (c.startsWith('TABLE:')) {
      final parts = c.split('|');
      if (parts.length >= 2) {
        return parts.sublist(1).join('|').trim();
      } else {
        return '';
      }
    }
    return c;
  }
}
