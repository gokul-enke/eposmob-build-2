import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Minimum recommended touch target (WCAG / Material).
const double kBillingMinTouchTarget = 44;

/// Persistent bottom action bar for the mobile Billing tab.
/// Mirrors desktop [ActionButtons]: Save Order + online confirm actions, or
/// offline Save & Print. In quotation mode shows Create Quotation + Quotation
/// List instead (payment-disabled checkout path).
class BillingActionButtons extends StatelessWidget {
  final bool isQuotationMode;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveAndPrint;
  final VoidCallback? onCreateQuotation;
  final VoidCallback? onCreateQuotationAndPrint;
  final VoidCallback? onOpenQuotationList;
  final bool isSavingOrder;
  final bool isConfirmingOrder;
  final bool isConfirmingAndPrinting;
  final bool isSavingAndPrinting;

  const BillingActionButtons({
    super.key,
    this.isQuotationMode = false,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    required this.onSaveAndPrint,
    this.onCreateQuotation,
    this.onCreateQuotationAndPrint,
    this.onOpenQuotationList,
    this.isSavingOrder = false,
    this.isConfirmingOrder = false,
    this.isConfirmingAndPrinting = false,
    this.isSavingAndPrinting = false,
  });

  bool get _isCheckoutBusy =>
      isSavingOrder ||
      isConfirmingOrder ||
      isConfirmingAndPrinting ||
      isSavingAndPrinting;

  @override
  Widget build(BuildContext context) {
    final localProvider = Provider.of<LocalProductProvider>(context);
    final billingProvider = Provider.of<BillingProvider>(context);
    final hasItems = localProvider.cartItems.isNotEmpty;
    final hasInternet = billingProvider.hasInternet;
    final showConfirmButton = Provider.of<AppSettingsProvider>(context)
            .appSettings
            ?.showConfirmOrderButton ??
        true;

    if (isQuotationMode) {
      return _buildQuotationActions(hasItems: hasItems);
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Save Order',
            button: true,
            child: ExcludeSemantics(
              child: ElevatedButton.icon(
                icon: isSavingOrder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined,
                        color: Colors.white, size: 18),
                label: const Text(
                  'Save Order',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: hasItems
                      ? const Color(0xFFEAB308)
                      : Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (hasItems && !_isCheckoutBusy) ? onSaveOrder : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (hasInternet)
            _buildOnlineActions(
              hasItems: hasItems,
              showConfirmButton: showConfirmButton,
            )
          else
            _buildOfflineActions(hasItems: hasItems),
        ],
      ),
    );
  }

  Widget _buildQuotationActions({required bool hasItems}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Create Quotation',
            button: true,
            child: ExcludeSemantics(
              child: ElevatedButton.icon(
                icon: isSavingOrder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.request_quote_outlined,
                        color: Colors.white, size: 18),
                label: const Text(
                  'Create Quotation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      hasItems ? const Color(0xFF14B8A6) : Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (hasItems && !_isCheckoutBusy)
                    ? onCreateQuotation
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Create Quotation and Print',
                  button: true,
                  child: ExcludeSemantics(
                    child: ElevatedButton.icon(
                      icon: isConfirmingAndPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.print,
                              color: Colors.white, size: 18),
                      label: const Text(
                        'Create & Print',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: hasItems
                            ? const Color(0xFF15803D)
                            : Colors.grey.shade300,
                        minimumSize: const Size(0, kBillingMinTouchTarget),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (hasItems && !_isCheckoutBusy)
                          ? onCreateQuotationAndPrint
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: 'Quotation List',
                  button: true,
                  child: ExcludeSemantics(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: const Text(
                        'Quotation List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, kBillingMinTouchTarget),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          !_isCheckoutBusy ? onOpenQuotationList : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineActions({required bool hasItems}) {
    return Semantics(
      label: 'Save and Print',
      button: true,
      child: ExcludeSemantics(
        child: ElevatedButton.icon(
          icon: isSavingAndPrinting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.print, color: Colors.white, size: 18),
          label: const Text(
            'Save & Print',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor:
                hasItems ? const Color(0xFF15803D) : Colors.grey.shade300,
            minimumSize: const Size(double.infinity, kBillingMinTouchTarget),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (hasItems && !_isCheckoutBusy) ? onSaveAndPrint : null,
        ),
      ),
    );
  }

  Widget _buildOnlineActions({
    required bool hasItems,
    required bool showConfirmButton,
  }) {
    return Row(
      children: [
        if (showConfirmButton) ...[
          Expanded(
            child: Semantics(
              label: 'Confirm',
              button: true,
              child: ExcludeSemantics(
                child: ElevatedButton.icon(
                  icon: isConfirmingOrder
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                  label: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: hasItems
                        ? const Color(0xFF0056B3)
                        : Colors.grey.shade300,
                    minimumSize: const Size(0, kBillingMinTouchTarget),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      (hasItems && !_isCheckoutBusy) ? onConfirmOrder : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Semantics(
            label: 'Confirm & Print',
            button: true,
            child: ExcludeSemantics(
              child: ElevatedButton.icon(
                icon: isConfirmingAndPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.print, color: Colors.white, size: 18),
                label: const Text(
                  'Confirm & Print',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      hasItems ? const Color(0xFF15803D) : Colors.grey.shade300,
                  minimumSize: const Size(0, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (hasItems && !_isCheckoutBusy)
                    ? onCreateOrderAndPrint
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
