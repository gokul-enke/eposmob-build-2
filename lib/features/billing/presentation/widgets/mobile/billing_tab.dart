import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/customer_summary_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_section_row.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/delivery_options_sheet.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/coupon_sheet.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_sheet.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_action_buttons.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/quotation_checkout_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/select_customer_page.dart';

/// Mobile "Billing & Payment" tab. Pure layout/composition: each section is its
/// own widget under `mobile/billing/`, and the action bar is
/// [BillingActionButtons]. Business logic lives in `BillingMobileController`.
class MobileBillingTab extends StatefulWidget {
  final bool isQuotationMode;
  final GlobalKey autocompletePhoneKey;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onSaveAndPrint;
  final VoidCallback? onCreateQuotation;
  final VoidCallback? onCreateQuotationAndPrint;
  final VoidCallback? onOpenQuotationList;
  final DateTime? quotationDate;
  final DateTime? quotationExpiryDate;
  final ValueChanged<DateTime>? onQuotationDateChanged;
  final ValueChanged<DateTime>? onQuotationExpiryDateChanged;
  final TextEditingController? quotationInlineNameController;
  final TextEditingController? quotationInlinePhoneController;
  final VoidCallback? onQuotationInlineCustomerChanged;
  final bool isSavingOrder;
  final bool isConfirmingOrder;
  final bool isConfirmingAndPrinting;
  final bool isSavingAndPrinting;

  const MobileBillingTab({
    super.key,
    this.isQuotationMode = false,
    required this.autocompletePhoneKey,
    required this.onConfirmOrder,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onSaveAndPrint,
    this.onCreateQuotation,
    this.onCreateQuotationAndPrint,
    this.onOpenQuotationList,
    this.quotationDate,
    this.quotationExpiryDate,
    this.onQuotationDateChanged,
    this.onQuotationExpiryDateChanged,
    this.quotationInlineNameController,
    this.quotationInlinePhoneController,
    this.onQuotationInlineCustomerChanged,
    this.isSavingOrder = false,
    this.isConfirmingOrder = false,
    this.isConfirmingAndPrinting = false,
    this.isSavingAndPrinting = false,
  });

  @override
  State<MobileBillingTab> createState() => _MobileBillingTabState();
}

class _MobileBillingTabState extends State<MobileBillingTab> {
  static const _customerController = BillingMobileCustomerController();
  static const _settingsController = BillingMobileSettingsController();
  static const _deliveryController = BillingMobileDeliveryController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPaymentValidationContext();
      try {
        final terminalProvider = context.read<PineLabsTerminalProvider>();
        terminalProvider.ensureBinding();
      } catch (_) {
        // Ignore; UI will still allow manual binding on first attempt.
      }
    });
  }

  void _syncPaymentValidationContext() {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    _customerController.syncPaymentValidationCustomerContext(
      billingProvider: billingProvider,
      customerSelectionProvider: customerSelection,
      appSettings: appSettings,
    );
  }

  void _markPaymentStepVisited() {
    Provider.of<BillingProvider>(context, listen: false).markPaymentStepVisited();
  }

  /// Summary text for the delivery row value, e.g. "Door Delivery · SAR 5.00"
  /// or just the method name when the fee can't be cheaply resolved.
  String _deliveryValueText(
    BillingProvider bp,
    DeliveryMethodsProvider deliveryMethodsProvider,
    String currency,
  ) {
    if (bp.deliveryMethod.isEmpty) return 'Select';

    DeliveryMethod? selected;
    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if (method.id == bp.deliveryMethodId || method.name == bp.deliveryMethod) {
        selected = method;
        break;
      }
    }
    if (selected == null) return bp.deliveryMethod;

    final feeLabel = _deliveryController.feeLabel(selected, currency);
    return '${selected.name} · $feeLabel';
  }

  /// Summary text for the coupon row value, e.g. "SAVE10 · 10% off" or
  /// "SAVE10 · SAR 20.00 off" when applied, else "None applied".
  String _couponValueText(
    BillingProvider bp,
    LocalProductProvider localProductProvider,
    String currency,
  ) {
    if (!bp.isCouponApplied) return 'None applied';

    final code = bp.coupenCodeTextController.text.trim();
    final currentDiscounts = localProductProvider.getCurrentDiscount();
    final flat = currentDiscounts['flatDiscount'] ?? 0.0;
    final pct = currentDiscounts['percentageDiscount'] ?? 0.0;

    String amountText;
    if (pct > 0) {
      amountText = '${pct.toStringAsFixed(0)}% off';
    } else if (flat > 0) {
      amountText = '$currency ${flat.toStringAsFixed(2)} off';
    } else {
      amountText = 'Applied';
    }

    return code.isNotEmpty ? '$code · $amountText' : amountText;
  }

  /// Summary text for the payment methods row value, e.g.
  /// "Cash + Card · SAR 150.00" or "Select payment" when nothing is chosen.
  String _paymentValueText(BillingProvider bp, String currency) {
    final selectedNames = <String>[];
    if (bp.isCashSelected) selectedNames.add('Cash');
    if (bp.isCardSelected) selectedNames.add('Card');
    if (bp.isUpiSelected) selectedNames.add('UPI');
    if (bp.isCodSelected) selectedNames.add('COD');
    if (bp.selectedExtraMethodIds.isNotEmpty) {
      selectedNames.add(
        bp.selectedExtraMethodIds.length == 1
            ? '1 other method'
            : '${bp.selectedExtraMethodIds.length} other methods',
      );
    }

    if (selectedNames.isEmpty) return 'Select payment';

    return '${selectedNames.join(' + ')} · $currency '
        '${AmountHelper.formatAmount(bp.totalPaidAmount)}';
  }

  /// Navigate to the full-screen Select Customer page.
  Future<void> _navigateToSelectCustomer(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SelectCustomerPage(),
      ),
    );
    if (!mounted) return;
    _syncPaymentValidationContext();
    final selected = Provider.of<CustomerSelectionProvider>(context, listen: false)
        .selectedCustomer;
    if (selected?.id != null) {
      widget.quotationInlineNameController?.clear();
      widget.quotationInlinePhoneController?.clear();
    }
    _syncPaymentValidationContext();
    setState(() {});
  }

  // TODO(temporary): restore with walk-in phone field block in build().
  // Widget _buildWalkInPhoneField(BuildContext context) {
  //   final billingProvider = Provider.of<BillingProvider>(context, listen: false);
  //   final customerSelection =
  //       Provider.of<CustomerSelectionProvider>(context, listen: false);
  //
  //   return TextField(
  //     controller: billingProvider.mobileNumberTextController,
  //     keyboardType: TextInputType.phone,
  //     decoration: InputDecoration(
  //       hintText: 'billing.enter_mobile_hint'.tr,
  //       prefixIcon: const Icon(Icons.phone_outlined, size: 20),
  //       filled: true,
  //       fillColor: const Color(0xFFF8FAFC),
  //       contentPadding:
  //           const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(8),
  //         borderSide: BorderSide(color: Colors.grey.shade300),
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(8),
  //         borderSide: BorderSide(color: Colors.grey.shade300),
  //       ),
  //     ),
  //     onChanged: (value) {
  //       _customerController.applyWalkInPhone(
  //         billingProvider: billingProvider,
  //         customerSelectionProvider: customerSelection,
  //         phone: value,
  //       );
  //       _syncPaymentValidationContext();
  //     },
  //   );
  // }

  void _clearCustomer(BuildContext context) {
    _customerController.clearSelection(
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: Provider.of<BillingProvider>(context, listen: false),
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
    widget.quotationInlineNameController?.clear();
    widget.quotationInlinePhoneController?.clear();
  }

  MobileCustomerBalanceDisplay? _balanceDisplayForCustomer(
    BuildContext context,
    CustomerListModelData? customer,
  ) {
    if (customer == null) return null;

    final customerSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final salesExecutive = Provider.of<SalesExecutiveProvider>(context,
            listen: false)
        .getCurrentUser(context);
    final isQuotationDraft = Provider.of<LocalProductProvider>(context,
            listen: false)
        .currentOrder
        ?.quotationId !=
        null;

    final shouldShow = _customerController.shouldShowCustomerBalance(
      customer: customer,
      customerSelectionProvider: customerSelection,
      defaultCustomerPhone:
          appSettings?.autoAssignDefaultCustomerPhone ?? '',
      isQuotationDraft: isQuotationDraft,
      salesExecutivePhone: salesExecutive?.phone,
    );
    if (!shouldShow) return null;

    return _customerController.balanceDisplay(
      balance: customer.balance ?? 0.0,
      currency: appSettings?.currency ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerSelection = Provider.of<CustomerSelectionProvider>(context);
    final billingProvider = Provider.of<BillingProvider>(context);
    final deliveryMethodsProvider = Provider.of<DeliveryMethodsProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);
    final selectedCustomer = customerSelection.selectedCustomer;
    final defaultPhoneCustomer = _customerController
        .defaultSalesExecutivePhoneCustomer(
      billingProvider: billingProvider,
      localProductProvider: localProductProvider,
      customerSelectionProvider: customerSelection,
    );
    final displayCustomer = selectedCustomer ?? defaultPhoneCustomer;
    final showDefaultPhoneOnly = defaultPhoneCustomer != null;
    final balanceDisplay =
        _balanceDisplayForCustomer(context, displayCustomer);
    final appSettings =
        Provider.of<AppSettingsProvider>(context).appSettings;
    final showCouponSection =
        _settingsController.shouldShowCouponSection(appSettings);
    final bool showCustomerType = appSettings?.companyB2BEnabled ?? false;
    final isQuotationMode = widget.isQuotationMode;

    // TODO(temporary): walk-in mobile number field hidden on mobile billing.
    // Re-enable with:
    // final showWalkInPhone = !isQuotationMode &&
    //     !showDefaultPhoneOnly &&
    //     selectedCustomer?.id == null;
    // if (showWalkInPhone) ...[
    //   const SizedBox(height: 8),
    //   _buildWalkInPhoneField(context),
    // ],

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPaymentValidationContext();
    });

    // Safe bottom padding so content can scroll fully above the persistent
    // bottomSheet buttons (padding 16 + button row height + bottom inset).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomActionsHeight = isQuotationMode ? 156.0 : 156.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                bottomActionsHeight + bottomInset + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isQuotationMode &&
                      widget.quotationDate != null &&
                      widget.quotationExpiryDate != null &&
                      widget.quotationInlineNameController != null &&
                      widget.quotationInlinePhoneController != null) ...[
                    const Text(
                      'Quotation Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QuotationCheckoutSection(
                      quotationDate: widget.quotationDate!,
                      expiryDate: widget.quotationExpiryDate!,
                      onQuotationDateChanged:
                          widget.onQuotationDateChanged ?? (_) {},
                      onExpiryDateChanged:
                          widget.onQuotationExpiryDateChanged ?? (_) {},
                      inlineNameController:
                          widget.quotationInlineNameController!,
                      inlinePhoneController:
                          widget.quotationInlinePhoneController!,
                      onInlineCustomerChanged:
                          widget.onQuotationInlineCustomerChanged ?? () {},
                      onSelectCustomer: () => _navigateToSelectCustomer(context),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Customer Section
                    CustomerSummaryCard(
                      customer: displayCustomer,
                      balanceDisplay: balanceDisplay,
                      customerType: showCustomerType
                          ? displayCustomer?.customerType
                          : null,
                      onTap: showDefaultPhoneOnly
                          ? null
                          : () => _navigateToSelectCustomer(context),
                      onClear: displayCustomer != null
                          ? () => _clearCustomer(context)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Delivery & Options Section (Select Delivery Method)
                  BillingSectionRow(
                    icon: Icons.local_shipping_outlined,
                    title: 'Select Delivery Method',
                    value: _deliveryValueText(
                      billingProvider,
                      deliveryMethodsProvider,
                      appSettings?.currency ?? '',
                    ),
                    onTap: () => showDeliveryOptionsSheet(context),
                  ),
                  const SizedBox(height: 12),

                  if (showCouponSection) ...[
                    BillingSectionRow(
                      icon: Icons.local_offer_outlined,
                      title: 'Coupon',
                      value: _couponValueText(
                        billingProvider,
                        localProductProvider,
                        appSettings?.currency ?? '',
                      ),
                      isHighlighted: billingProvider.isCouponApplied,
                      onTap: () => showCouponSheet(context),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (!isQuotationMode) ...[
                    BillingSectionRow(
                      icon: Icons.payment_outlined,
                      title: 'billing.payment_methods'.tr,
                      value: _paymentValueText(
                        billingProvider,
                        appSettings?.currency ?? '',
                      ),
                      isHighlighted: billingProvider.totalPaidAmount > 0,
                      onTap: () async {
                        _markPaymentStepVisited();
                        await showPaymentMethodsSheet(context);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Order Summary — always visible, no longer an accordion.
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Summary',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0066CC),
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 12),
                          PaymentSummary(
                            compact: false,
                            showToCustomerCreditToggle: false,
                            taxBreakdownEnabled: true,
                            taxBreakdownUseBottomSheet: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Action Buttons
      bottomSheet: BillingActionButtons(
        isQuotationMode: isQuotationMode,
        onSaveOrder: widget.onSaveOrder,
        onCreateOrderAndPrint: widget.onCreateOrderAndPrint,
        onConfirmOrder: widget.onConfirmOrder,
        onSaveAndPrint: widget.onSaveAndPrint,
        onCreateQuotation: widget.onCreateQuotation,
        onCreateQuotationAndPrint: widget.onCreateQuotationAndPrint,
        onOpenQuotationList: widget.onOpenQuotationList,
        isSavingOrder: widget.isSavingOrder,
        isConfirmingOrder: widget.isConfirmingOrder,
        isConfirmingAndPrinting: widget.isConfirmingAndPrinting,
        isSavingAndPrinting: widget.isSavingAndPrinting,
      ),
    );
  }
}
