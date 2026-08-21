import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart/mobile_cart_price_fields.dart';
import 'package:pos_machine/features/billing/presentation/widgets/pos_security_key_dialog.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_purchase_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/customer_purchase_history_modal.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/show_product_details.dart';
import 'package:provider/provider.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
    required this.controller,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onSaleUnitChanged,
    this.showMrp = false,
    this.showTaxRate = false,
    this.showTaxAmount = false,
    this.showItemCode = false,
    this.isLowStock = false,
    this.isOutOfStock = false,
  });

  static const _settingsController = BillingMobileSettingsController();
  static const double _qtyButtonSize = 40;

  final LocalCartItem item;
  final BillingMobileCartController controller;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;
  final ValueChanged<MobileSaleUnitChangeResult> onSaleUnitChanged;
  final bool showMrp;
  final bool showTaxRate;
  final bool showTaxAmount;
  final bool showItemCode;
  final bool isLowStock;
  final bool isOutOfStock;

  String? get _imageUrl {
    final attachments = item.product.attachment ?? const <Attachment>[];
    if (attachments.isEmpty) return null;
    final raw = attachments.first.file?.toString().trim().isNotEmpty == true
        ? attachments.first.file.toString().trim()
        : attachments.first.filePath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  String get _lineTotal {
    final total = BillingCrashGuards.lineTotal(
      unitPrice: item.price,
      quantity: item.quantity,
    );
    return AmountHelper.formatAmount(total);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String>? unitLabels;
    try {
      unitLabels =
          Provider.of<PurchaseProvider>(context, listen: false).getUnitList;
    } on ProviderNotFoundException {
      // Lightweight cart/test hosts can omit this optional master-data source.
    }
    final unitOptions = controller.cartUnitOptionsForItem(
      item,
      unitLabels: unitLabels,
    );
    final selectedUnit = controller.selectedCartUnitValue(item);
    final canChangeUnit = controller.canChangeSaleUnit(
      item,
      unitLabels: unitLabels,
    );
    final appSettings = context.watch<AppSettingsProvider>().appSettings;
    final multiSaleUnitEnabled =
        context.watch<AppSettingsProvider>().multiSaleUnitEnabled;
    final customerSelection = context.watch<CustomerSelectionProvider>();
    final canViewBillingProductDetails = context
        .watch<RoleProvider>()
        .currentUserHasPermissionSync('billing.product.view');
    final canShowPurchaseHistoryAction =
        _settingsController.shouldShowPurchaseHistoryAction(
      appSettings: appSettings,
      hasSelectedCustomer: customerSelection.hasSelectedCustomer,
      isDefaultCustomer: customerSelection.isDefaultCustomer,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? ColorManager.kRed.withValues(alpha: 0.06)
            : isLowStock
                ? ColorManager.kOrange.withValues(alpha: 0.06)
                : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutOfStock
              ? ColorManager.kRed.withValues(alpha: 0.35)
              : isLowStock
                  ? ColorManager.kOrange.withValues(alpha: 0.35)
                  : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _imageUrl == null
                      ? _fallbackImage()
                      : Image.network(
                          _imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _fallbackImage();
                          },
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: ColorManager.kTitleTextColor,
                      ),
                    ),
                    if (showItemCode) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.product.itemCode ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorManager.kGreyColor,
                        ),
                      ),
                    ],
                    if (isLowStock || isOutOfStock) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isOutOfStock
                                  ? ColorManager.kRed
                                  : ColorManager.kOrange)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOutOfStock ? 'Out of stock' : 'Low stock',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock
                                ? ColorManager.kRed
                                : ColorManager.kOrange,
                          ),
                        ),
                      ),
                    ],
                    if (multiSaleUnitEnabled && canChangeUnit) ...[
                      const SizedBox(height: 6),
                      _SaleUnitSelector(
                        currentLabel: item.displayUnitName,
                        options: unitOptions,
                        selectedValue: selectedUnit,
                        onSelected: (value) {
                          final result = controller.changeSaleUnit(
                            provider: context.read<LocalProductProvider>(),
                            item: item,
                            value: value,
                            unitLabels: unitLabels,
                          );
                          onSaleUnitChanged(result);
                          if (!result.success && result.errorMessage != null) {
                            showScaffoldError(
                              context: context,
                              message: result.errorMessage!,
                            );
                          }
                        },
                      ),
                    ] else if (item.hasSaleUnit) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.displayUnitName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorManager.kGreyColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canViewBillingProductDetails)
                    _CardIconButton(
                      key: const ValueKey('cart_product_details_action'),
                      tooltip: 'Product details',
                      icon: Icons.info_outline,
                      iconColor: ColorManager.kGreyColor,
                      onTap: () => _showProductDetailsDialog(context, item),
                    ),
                  if (canShowPurchaseHistoryAction)
                    _CardIconButton(
                      key: const ValueKey('cart_purchase_history_action'),
                      tooltip: 'Customer purchase history',
                      icon: Icons.history,
                      iconColor: ColorManager.kPrimaryColor,
                      onTap: () => _showCustomerPurchaseHistoryForCartItem(
                        context,
                        item,
                        controller,
                      ),
                    ),
                  _CardIconButton(
                    tooltip: 'Remove item',
                    icon: Icons.delete_outline,
                    iconColor: ColorManager.kButtonRed,
                    onTap: onRemove,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                filled: false,
                onTap: onDecrease,
              ),
              _MobileCartQuantityField(
                key: ValueKey(
                  'qty-field-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}',
                ),
                item: item,
                onBeforeRemove: () => PosSecurityKeyDialog.verify(
                  context,
                  action: 'remove this cart item',
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                filled: true,
                onTap: onIncrease,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _lineTotal,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: ColorManager.kPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MobileCartPriceSection(
            item: item,
            controller: controller,
            showMrp: showMrp,
            showTaxRate: showTaxRate,
            showTaxAmount: showTaxAmount,
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: ColorManager.kBgLightColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 24,
        color: Colors.blueGrey.shade200,
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  static const double _size = 36;

  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

void _showProductDetailsDialog(BuildContext context, LocalCartItem item) {
  final appSettingsProvider =
      Provider.of<AppSettingsProvider>(context, listen: false);
  final currency = appSettingsProvider.appSettings?.currency ?? '';

  showProductDetails(
    context,
    product: item.product,
    unitPrice: item.price,
    mrp: item.mrp,
    quantity: item.quantity,
    selectedStock: item.selectedStock,
    selectedVariantId: item.variantId,
    isCompact: true,
    currency: currency,
    useBillingProductPermissions: true,
  );
}

Future<void> _showCustomerPurchaseHistoryForCartItem(
  BuildContext context,
  LocalCartItem item,
  BillingMobileCartController controller,
) async {
  const settingsController = BillingMobileSettingsController();
  final appSettingsProvider =
      Provider.of<AppSettingsProvider>(context, listen: false);
  final customerSelectionProvider =
      Provider.of<CustomerSelectionProvider>(context, listen: false);

  if (!settingsController.shouldShowPurchaseHistoryAction(
    appSettings: appSettingsProvider.appSettings,
    hasSelectedCustomer: customerSelectionProvider.hasSelectedCustomer,
    isDefaultCustomer: customerSelectionProvider.isDefaultCustomer,
  )) {
    if (appSettingsProvider.appSettings?.showCustomerLastBuyedPriceList !=
        true) {
      showScaffoldError(
        context: context,
        message: 'Customer purchase history is disabled',
      );
      return;
    }
    if (customerSelectionProvider.isDefaultCustomer) {
      showScaffoldError(
        context: context,
        message: 'Purchase history is not shown for the default customer',
      );
      return;
    }
    showScaffoldError(
      context: context,
      message: 'Select a customer to view purchase history',
    );
    return;
  }

  final int? customerId = customerSelectionProvider.selectedCustomerID;
  final String? customerName = customerSelectionProvider.selectedCustomerName;
  final int? productId = item.product.productId;

  if (customerId == null || productId == null || customerName == null) {
    showScaffoldError(
      context: context,
      message: 'Select a customer to view purchase history',
    );
    return;
  }

  final String? token = BillingCrashGuards.accessTokenOrNull(
      Provider.of<AuthModel>(context, listen: false).token);
  if (token == null) {
    showScaffoldError(
      context: context,
      message: 'Unable to load purchase history',
    );
    return;
  }

  try {
    final CustomerPurchaseHistory? purchaseHistory =
        await CustomerPurchaseProvider().getCustomerLastPurchases(
      accessToken: token,
      customerId: customerId,
      productId: productId,
    );

    if (!context.mounted) return;

    if (purchaseHistory == null ||
        !purchaseHistory.success ||
        purchaseHistory.data.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'No purchase history found for this product',
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => CustomerPurchaseHistoryModal(
        product: item.product,
        purchaseHistory: purchaseHistory.data.take(5).toList(),
        customerName: customerName,
      ),
    );

    if (!context.mounted ||
        result == null ||
        result['useCurrentPrice'] == true) {
      return;
    }

    final rawPrice = result['price'];
    final double? selectedPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    if (selectedPrice == null) {
      return;
    }

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    final priceResult = controller.applyPurchaseHistoryPrice(
      provider: localProductProvider,
      item: item,
      historicalBasePrice: selectedPrice,
    );

    if (!priceResult.applied) {
      final minBase = priceResult.belowMinimumPrice;
      if (minBase != null && context.mounted) {
        showScaffoldError(
          context: context,
          message:
              'Selected price is below the minimum sale price of ${AmountHelper.formatAmount(minBase)}.',
        );
      }
      return;
    }
  } catch (error, stackTrace) {
    billingDebugLog('Failed to load customer purchase history: $error');
    assert(() {
      debugPrint('$stackTrace');
      return true;
    }());
    if (!context.mounted) return;
    showScaffoldError(
      context: context,
      message: 'Unable to load purchase history',
    );
  }
}

class _SaleUnitSelector extends StatelessWidget {
  const _SaleUnitSelector({
    required this.currentLabel,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String currentLabel;
  final List<MobileCartUnitOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: selectedValue,
      onSelected: onSelected,
      offset: const Offset(0, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ColorManager.kBgLightColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: ColorManager.kPrimaryColor,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return options
            .map(
              (option) => PopupMenuItem<String>(
                value: option.value,
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: option.value == selectedValue
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: option.value == selectedValue
                        ? ColorManager.kPrimaryColor
                        : Colors.black87,
                  ),
                ),
              ),
            )
            .toList();
      },
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  static const double _size = CartItemCard._qtyButtonSize;

  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? ColorManager.kPrimaryColor : ColorManager.kBgLightColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : ColorManager.kPrimaryColor,
          ),
        ),
      ),
    );
  }
}

class _MobileCartQuantityField extends StatefulWidget {
  const _MobileCartQuantityField({
    super.key,
    required this.item,
    this.onBeforeRemove,
  });

  final LocalCartItem item;
  final Future<bool> Function()? onBeforeRemove;

  @override
  State<_MobileCartQuantityField> createState() =>
      _MobileCartQuantityFieldState();
}

class _MobileCartQuantityFieldState extends State<_MobileCartQuantityField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;
  bool _isSyncing = false;

  String? get _unit {
    final unitName = widget.item.displayUnitName;
    if (unitName != '-') return unitName;
    return widget.item.product.unit;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatDisplay(widget.item.displayQuantity),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _MobileCartQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && !_isSyncing) {
      final nextText = _formatDisplay(widget.item.displayQuantity);
      if (_controller.text != nextText) {
        _controller.text = nextText;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commitQuantity();
    }
  }

  void _beginEditing() {
    _isEditing = true;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      if (_controller.text.isNotEmpty) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  Future<void> _commitQuantity() async {
    _isEditing = false;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = _formatDisplay(widget.item.displayQuantity);
      return;
    }

    final parsed = num.tryParse(text);
    if (parsed == null || parsed < 0) {
      _controller.text = _formatDisplay(widget.item.displayQuantity);
      return;
    }

    final normalized = normalizeQuantityForUnit(parsed, _unit);
    if (normalized == widget.item.displayQuantity) {
      _controller.text = _formatDisplay(widget.item.displayQuantity);
      return;
    }

    _isSyncing = true;
    try {
      final provider = context.read<LocalProductProvider>();
      final baseQty = widget.item.hasSaleUnit
          ? widget.item.toBaseQuantity(normalized)
          : normalized;

      if (baseQty <= 0 && widget.onBeforeRemove != null) {
        final authorized = await widget.onBeforeRemove!();
        if (!authorized || !mounted) {
          if (mounted) {
            _controller.text = _formatDisplay(widget.item.displayQuantity);
          }
          return;
        }
      }

      await CartQuantityStockHelper.syncCartItemQuantity(
        context: context,
        cartItem: widget.item,
        newQuantity: baseQty,
        localProductProvider: provider,
      );
      if (!mounted) return;
      _controller.text = _formatDisplay(widget.item.displayQuantity);
    } finally {
      _isSyncing = false;
    }
  }

  String _formatDisplay(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: TextField(
        key: const ValueKey('cart_quantity_text_field'),
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorManager.kTitleTextColor,
        ),
        inputFormatters: quantityInputFormattersForUnit(_unit),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onTap: _beginEditing,
        onSubmitted: (_) => _commitQuantity(),
      ),
    );
  }
}
