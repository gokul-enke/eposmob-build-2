// ignore_for_file: invalid_use_of_protected_member

part of 'order_panel.dart';

extension OrderPanelCurrentCartExtension on OrderPanelState {
  Widget _buildCurrentCartItem(LocalCartItem cartItem, int index) {
    final productName = cartItem.displayName;
    final quantity = cartItem.quantity;
    final unitPrice = cartItem.price ?? 0.0;
    final totalPrice = quantity * unitPrice;
    final isKeyboardFocused = _currentCartItemsFocusNode.hasFocus &&
        _focusedCurrentCartItemIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isKeyboardFocused
              ? const Color(0xFFF59E0B)
              : Colors.grey.shade200,
          width: isKeyboardFocused ? 3 : 1,
        ),
        boxShadow: isKeyboardFocused
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name, editable unit price, and line total
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
                        onTap: () =>
                            _showEditItemPriceDialog(cartItem, isLocal: true),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _showEditItemPriceDialog(cartItem, isLocal: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        const Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
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
                    GestureDetector(
                      onTap: () =>
                          _showEditItemQuantityDialog(cartItem, isLocal: true),
                      child: Container(
                        width: widget.isCompact ? 32 : 40,
                        alignment: Alignment.center,
                        child: Text(
                          quantity.toStringAsFixed(0),
                          style: buildCustomStyle(FontWeightManager.bold,
                              FontSize.s14, 0.21, const Color(0xFF059669)),
                        ),
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
    final hasInternet = Provider.of<BillingProvider>(context).hasInternet;
    final appSettings = Provider.of<AppSettingsProvider>(context).appSettings;
    final showClearSaveActions = !_usesCounterOrderTabs;
    final hasSelectedTable = widget.tableId?.isNotEmpty ?? false;
    final hasKitchenOrderContext = hasSelectedTable ||
        (_usesCounterOrderTabs && _isSelectedDeliveryMethodDineIn);
    final kotBillEnabled = widget.allowCounterBilling &&
        widget.isCounterBillingMode &&
        (appSettings?.enableKotBillButton ?? false);
    final kotBillAllowedForContext = !hasKitchenOrderContext ||
        (appSettings?.kotBillAllowedForDineIn ?? false);
    final showKotBillForKitchenContext =
        kotBillEnabled && kotBillAllowedForContext && hasInternet;
    final showSendToKitchen = hasKitchenOrderContext &&
        hasInternet &&
        (appSettings?.enableSendToKitchenButton ?? true);
    final showKitchenActions =
        showSendToKitchen || showKotBillForKitchenContext;
    final showConfirmOrder = _usesCounterOrderTabs &&
        hasInternet &&
        !hasKitchenOrderContext &&
        (appSettings?.showConfirmOrderButton ?? true);
    final showOfflineSaveAndPrint = !hasInternet && !_usesCounterOrderTabs;
    final hasOfflineOrderContext = hasKitchenOrderContext ||
        (widget.allowCounterBilling && widget.isCounterBillingMode);
    final showFooterButtons = showClearSaveActions ||
        showKitchenActions ||
        showConfirmOrder ||
        showOfflineSaveAndPrint;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.isCompact ? 10.0 : 12.0,
          8,
          widget.isCompact ? 10.0 : 12.0,
          _usesCounterOrderTabs ? 6.0 : (widget.isCompact ? 10.0 : 12.0),
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            widget.isCompact ? 10.0 : 12.0,
            widget.isCompact ? 10.0 : 12.0,
            widget.isCompact ? 10.0 : 12.0,
            _usesCounterOrderTabs ? 8.0 : (widget.isCompact ? 10.0 : 12.0),
          ),
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
              _buildCurrentCartSummaryCard(
                cartItems,
                isCompact: widget.isCompact,
              ),
              if (!widget.hideFooterActionButtons) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (showFooterButtons) ...[
                      if (showClearSaveActions) ...[
                        Expanded(
                          child: _buildCurrentCartFooterButton(
                            label: 'general.cancel'.tr,
                            color: const Color(0xFFDC2626),
                            isDisabled: cartItems.isEmpty,
                            onTap: () => _clearCurrentCart(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCurrentCartFooterButton(
                            label: 'general.save'.tr,
                            color: const Color(0xFF2563EB),
                            isDisabled: cartItems.isEmpty ||
                                (widget.tableId == null &&
                                    (widget.preselectedDeliveryMethodId ==
                                            null ||
                                        widget.preselectedDeliveryMethodId!
                                            .isEmpty)),
                            onTap: () => _saveCurrentCartAsPending(),
                          ),
                        ),
                      ],
                      if (showClearSaveActions && showKitchenActions)
                        const SizedBox(width: 8),
                      if (showSendToKitchen) ...[
                        Expanded(
                          flex: showClearSaveActions ||
                                  showKotBillForKitchenContext
                              ? 1
                              : 2,
                          child: _buildCurrentCartFooterButton(
                            label: 'restaurant.send_kitchen'.tr,
                            color: const Color(0xFF059669),
                            isDisabled: cartItems.isEmpty ||
                                widget.isLoadingPrint ||
                                widget.tableId == null,
                            isLoading: widget.isLoadingPrint,
                            onTap: () => widget.onPrintOrder(),
                          ),
                        ),
                      ],
                      if (showSendToKitchen && showKotBillForKitchenContext)
                        const SizedBox(width: 8),
                      if (showKotBillForKitchenContext) ...[
                        Expanded(
                          flex: showConfirmOrder
                              ? 1
                              : (showClearSaveActions || showSendToKitchen
                                  ? 1
                                  : 2),
                          child: _buildCurrentCartFooterButton(
                            label: 'restaurant.kot_bill'.tr,
                            color: const Color(0xFF7C3AED),
                            isDisabled: cartItems.isEmpty ||
                                widget.onKotBill == null ||
                                widget.isLoadingKotBill,
                            isLoading: widget.isLoadingKotBill,
                            onTap: () => widget.onKotBill?.call(),
                          ),
                        ),
                      ],
                      if ((showClearSaveActions || showKitchenActions) &&
                          showConfirmOrder)
                        const SizedBox(width: 8),
                      if (showConfirmOrder) ...[
                        Expanded(
                          flex: showKotBillForKitchenContext
                              ? 1
                              : (showClearSaveActions ? 2 : 1),
                          child: _buildCurrentCartFooterButton(
                            label: showKotBillForKitchenContext
                                ? 'restaurant.confirm_order'.tr
                                : 'billing.confirm_order'.tr,
                            shortcutLabel: 'F2',
                            color: const Color(0xFF08C63F),
                            isDisabled: cartItems.isEmpty || _isLoadingConfirm,
                            isLoading: _isLoadingConfirm,
                            onTap: () => showCurrentCartCheckoutFromParent(),
                          ),
                        ),
                      ],
                      if ((showClearSaveActions ||
                              showKitchenActions ||
                              showConfirmOrder) &&
                          showOfflineSaveAndPrint)
                        const SizedBox(width: 8),
                      if (showOfflineSaveAndPrint) ...[
                        Expanded(
                          flex: showClearSaveActions ? 2 : 1,
                          child: _buildCurrentCartFooterButton(
                            label: 'restaurant.save_print'.tr,
                            color: const Color(0xFFF59E0B),
                            isDisabled: cartItems.isEmpty ||
                                !hasOfflineOrderContext ||
                                _isLoadingConfirm,
                            isLoading: _isLoadingConfirm,
                            onTap: () =>
                                showOfflineSaveAndPrintCheckoutFromParent(),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                    ] else
                      const Spacer(),
                    _buildCurrentCartCommentIconButton(),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCartCommentIconButton() {
    final hasComment = _orderComment.trim().isNotEmpty;
    final color =
        hasComment ? const Color(0xFF059669) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCommentDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: widget.isCompact ? 44 : 48,
          height: widget.isCompact ? 44 : 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasComment ? color : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: widget.isCompact ? 18 : 20,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentCartSummaryCard(
    List<LocalCartItem> cartItems, {
    bool isCompact = false,
  }) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    double netAmount = 0.0;
    for (final item in cartItems) {
      final unitPrice = item.price ?? 0.0;
      netAmount += unitPrice * item.quantity;
    }
    final totalPayable = netAmount;

    if (isCompact) {
      bool isExpanded = false;
      return StatefulBuilder(
        builder: (context, setStateBuilder) {
          if (!isExpanded) {
            return GestureDetector(
              onTap: () => setStateBuilder(() => isExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'billing.total_payable_label'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$currency ${totalPayable.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s16,
                          0.2,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => setStateBuilder(() => isExpanded = false),
            child: Container(
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
                    'billing.net_amount'.tr,
                    '$currency ${netAmount.toStringAsFixed(2)}',
                    color: const Color(0xFF3F3F46),
                  ),
                  const SizedBox(height: 6),
                  Container(height: 1, color: const Color(0xFFE4E4ED)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'billing.total_payable_label'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.21,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$currency ${totalPayable.toStringAsFixed(2)}',
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s18,
                            0.21,
                            const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFF3B82F6),
                        size: 18,
                      ),
                    ],
                  ),
                  _buildSummaryRow(
                    'billing.total_paid'.tr,
                    '$currency 0.00',
                    color: const Color(0xFF3F3F46),
                  ),
                  _buildSummaryRow(
                    'billing.balance'.tr,
                    '$currency ${totalPayable.toStringAsFixed(2)}',
                    color: const Color(0xFF00C739),
                    isBold: true,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

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
            'billing.net_amount'.tr,
            '$currency ${netAmount.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFFE4E4ED)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'billing.total_payable_label'.tr,
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF3B82F6),
            isBold: true,
            large: true,
          ),
          _buildSummaryRow(
            'billing.total_paid'.tr,
            '$currency 0.00',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'billing.balance'.tr,
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
    String? shortcutLabel,
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    final disabled = isDisabled || isLoading;
    final foregroundColor = Colors.white;
    final shortcutBackgroundColor = Colors.white.withOpacity(0.18);
    final shortcutBorderColor = Colors.white.withOpacity(0.35);
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
                            foregroundColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (shortcutLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: shortcutBackgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: shortcutBorderColor),
                          ),
                          child: Text(
                            shortcutLabel,
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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
        variantId: cartItem.variantId,
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
        localProductProvider.clearCurrentOrder();
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
      final targetDraftId =
          _loadedLocalDraftId ?? localProductProvider.currentOrder?.id;
      final shouldUpdateExistingDraft = targetDraftId != null &&
          localProductProvider.findOrderById(targetDraftId) != null;
      if (shouldUpdateExistingDraft) {
        debugPrint('📝 Updating existing local draft $_loadedLocalDraftId');
        localProductProvider.updateSavedOrder(
          targetDraftId,
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
          carNumber: carNumberForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          alternatePhone: selectedCustomerAlternatePhoneForDraft,
          customerVatNumber: selectedCustomerVatNumberForDraft,
          customerCrNumber: selectedCustomerCrNumberForDraft,
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
          carNumber: carNumberForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          alternatePhone: selectedCustomerAlternatePhoneForDraft,
          customerVatNumber: selectedCustomerVatNumberForDraft,
          customerCrNumber: selectedCustomerCrNumberForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        showScaffold(
            context: context,
            message: 'Saved local draft ${saved.orderNumber}');
      }

      // Clear cart and refresh local drafts
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();
      setState(() {
        _loadedLocalDraftId = null;
        _orderComment = '';
        _activeOrderPanelTab = OrderPanelTab.saved;
        _showSavedOrdersView = true;
      });
      _refreshLocalDrafts();
      widget.onLocalDraftSaved?.call();
      if (_usesCounterOrderTabs) {
        resetActiveOrderContext();
      }
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
        ? 'Dine In: $tableName'
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
                      if (!_usesCounterOrderTabs)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    const Color(0xFFD97706).withOpacity(0.4)),
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
