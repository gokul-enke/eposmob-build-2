import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Minimum recommended touch target (WCAG / Material).
const double kBillingMinTouchTarget = 44;

/// Persistent bottom action bar for the mobile Billing tab.
/// Save Order plus the confirm actions. Offline uses the same confirm actions:
/// sales are confirmed offline-first and synced later. In quotation mode shows
/// Create Quotation + Quotation List instead (payment-disabled checkout path).
class BillingActionButtons extends StatelessWidget {
  final bool isQuotationMode;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final VoidCallback? onCreateQuotation;
  final VoidCallback? onCreateQuotationAndPrint;
  final VoidCallback? onOpenQuotationList;
  final bool isSavingOrder;
  final bool isConfirmingOrder;
  final bool isConfirmingAndPrinting;

  const BillingActionButtons({
    super.key,
    this.isQuotationMode = false,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    this.onCreateQuotation,
    this.onCreateQuotationAndPrint,
    this.onOpenQuotationList,
    this.isSavingOrder = false,
    this.isConfirmingOrder = false,
    this.isConfirmingAndPrinting = false,
  });

  bool get _isCheckoutBusy =>
      isSavingOrder || isConfirmingOrder || isConfirmingAndPrinting;

  @override
  Widget build(BuildContext context) {
    final localProvider = Provider.of<LocalProductProvider>(context);
    final hasItems = localProvider.cartItems.isNotEmpty;
    final appSettings = Provider.of<AppSettingsProvider>(context).appSettings;
    final showConfirmButton = appSettings?.showConfirmOrderButton ?? true;
    final showConfirmAndPrintButton =
        appSettings?.showConfirmOrderAndPrintButton ?? true;

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
            label: 'billing.save_order'.tr,
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
                label: Text(
                  'billing.save_order'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      hasItems ? const Color(0xFFEAB308) : Colors.grey.shade300,
                  minimumSize:
                      const Size(double.infinity, kBillingMinTouchTarget),
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
          _buildConfirmActions(
            hasItems: hasItems,
            showConfirmButton: showConfirmButton,
            showConfirmAndPrintButton: showConfirmAndPrintButton,
          ),
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
            label: 'billing.create_quotation'.tr,
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
                label: Text(
                  'billing.create_quotation'.tr,
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
                  minimumSize:
                      const Size(double.infinity, kBillingMinTouchTarget),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    (hasItems && !_isCheckoutBusy) ? onCreateQuotation : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'billing.create_quotation_and_print'.tr,
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
                      label: Text(
                        'billing.create_and_print'.tr,
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
                  label: 'billing.quotation_list'.tr,
                  button: true,
                  child: ExcludeSemantics(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: Text(
                        'billing.quotation_list'.tr,
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
                      onPressed: !_isCheckoutBusy ? onOpenQuotationList : null,
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

  Widget _buildConfirmActions({
    required bool hasItems,
    required bool showConfirmButton,
    required bool showConfirmAndPrintButton,
  }) {
    return Row(
      children: [
        if (showConfirmButton) ...[
          Expanded(
            child: Semantics(
              label: 'general.confirm'.tr,
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
                  label: Text(
                    'general.confirm'.tr,
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
        if (showConfirmAndPrintButton)
          Expanded(
            child: Semantics(
              label: 'general.confirm_and_print'.tr,
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
                  label: Text(
                    'general.confirm_and_print'.tr,
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
