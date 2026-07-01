import 'package:flutter/material.dart';
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
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_accordion_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/customer_summary_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/delivery_options_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/coupon_section.dart';
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

  @override
  void initState() {
    super.initState();
    // Proactively bind Pine Labs so the first payment attempt doesn't need to bind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final terminalProvider = context.read<PineLabsTerminalProvider>();
        terminalProvider.ensureBinding();
      } catch (_) {
        // Ignore; UI will still allow manual binding on first attempt.
      }
    });
  }

  /// Navigate to the full-screen Select Customer page.
  Future<void> _navigateToSelectCustomer(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SelectCustomerPage(),
      ),
    );
    if (!mounted) return;
    final selected = Provider.of<CustomerSelectionProvider>(context, listen: false)
        .selectedCustomer;
    if (selected?.id != null) {
      widget.quotationInlineNameController?.clear();
      widget.quotationInlinePhoneController?.clear();
      setState(() {});
    }
  }

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
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
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
                  const BillingAccordionCard(
                    title: 'Select Delivery Method',
                    initiallyExpanded: true,
                    child: DeliveryOptionsSection(),
                  ),
                  const SizedBox(height: 12),

                  if (showCouponSection) ...[
                    const BillingAccordionCard(
                      title: 'Coupon',
                      initiallyExpanded: false,
                      child: CouponSection(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (!isQuotationMode) ...[
                    // Payment Methods Section
                    const BillingAccordionCard(
                      title: 'Payment Methods',
                      initiallyExpanded: true,
                      child: PaymentMethodsSection(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Order Summary
                  const BillingAccordionCard(
                    title: 'Order Summary',
                    initiallyExpanded: true,
                    child: PaymentSummary(
                      compact: false,
                      showToCustomerCreditToggle: false,
                      taxBreakdownEnabled: true,
                      taxBreakdownUseBottomSheet: true,
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
