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
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/select_customer_page.dart';

/// Mobile "Billing & Payment" tab. Pure layout/composition: each section is its
/// own widget under `mobile/billing/`, and the action bar is
/// [BillingActionButtons]. Business logic lives in `BillingMobileController`.
class MobileBillingTab extends StatefulWidget {
  final GlobalKey autocompletePhoneKey;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final bool isConfirmingOrder;
  final bool isConfirmingAndPrinting;

  const MobileBillingTab({
    super.key,
    required this.autocompletePhoneKey,
    required this.onConfirmOrder,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    this.isConfirmingOrder = false,
    this.isConfirmingAndPrinting = false,
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
  void _navigateToSelectCustomer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SelectCustomerPage(),
      ),
    );
  }

  void _clearCustomer(BuildContext context) {
    _customerController.clearSelection(
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: Provider.of<BillingProvider>(context, listen: false),
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
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
    final selectedCustomer = customerSelection.selectedCustomer;
    final balanceDisplay =
        _balanceDisplayForCustomer(context, selectedCustomer);
    final appSettings =
        Provider.of<AppSettingsProvider>(context).appSettings;
    final showCouponSection =
        _settingsController.shouldShowCouponSection(appSettings);

    // Safe bottom padding so content can scroll fully above the persistent
    // bottomSheet buttons (padding 16 + button row height + bottom inset).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double bottomActionsHeight = 88;

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
                  // Customer Section
                  CustomerSummaryCard(
                    customer: selectedCustomer,
                    balanceDisplay: balanceDisplay,
                    onTap: () => _navigateToSelectCustomer(context),
                    onClear: selectedCustomer != null
                        ? () => _clearCustomer(context)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Delivery & Options Section (Select Delivery Method)
                  const BillingAccordionCard(
                    title: 'Select Delivery Method:',
                    initiallyExpanded: true,
                    child: DeliveryOptionsSection(),
                  ),
                  const SizedBox(height: 16),

                  if (showCouponSection) ...[
                    const BillingAccordionCard(
                      title: 'Coupon:',
                      initiallyExpanded: false,
                      child: CouponSection(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Methods Section
                  const BillingAccordionCard(
                    title: 'Payment Methods:',
                    initiallyExpanded: true,
                    child: PaymentMethodsSection(),
                  ),
                  const SizedBox(height: 16),

                  // Order Summary calculations
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: const PaymentSummary(compact: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Action Buttons
      bottomSheet: BillingActionButtons(
        onSaveOrder: widget.onSaveOrder,
        onCreateOrderAndPrint: widget.onCreateOrderAndPrint,
        onConfirmOrder: widget.onConfirmOrder,
        isConfirmingOrder: widget.isConfirmingOrder,
        isConfirmingAndPrinting: widget.isConfirmingAndPrinting,
      ),
    );
  }
}
