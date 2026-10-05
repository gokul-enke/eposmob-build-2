part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations8 on PurchaseOrderFormView {
  Widget _buildPaymentSection() {
    if (_isPaymentDisabled) {
      // PO is already fully paid — show a read-only info banner, hide selector.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'purchase_order.already_fully_paid'.tr,
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BuildDynamicPaymentSelector(
      title: 'purchase_order.select_payment_method'.tr,
      paymentMethods: _paymentMethods,
      isLoading: _isLoadingPaymentMethods,
      initialData: paymentData,
      onPaymentChanged: (data) {
        setState(() {
          paymentData = data;
          _lastKnownNetPayable = _purchaseTotals.netPayable;
        });
        _saveDraftToHive();
      },
      showTotalAmount: true,
      expectedAmount: _purchaseTotals.netPayable,
      allowPartialPayment: true,
      maxMethods: 2,
    );
  }

  Widget _buildFooter() {
    final totals = _purchaseTotals;
    final discountValidationMessage =
        _discountValidationTotals.discountErrorKey?.tr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuildBoxShadowContainer(
          circleRadius: 8,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildTotalSummaryRow(
                'purchase_order.gross_total'.tr,
                totals.grossAmount,
              ),
              const SizedBox(height: 8),
              _buildDiscountSummaryRow(),
              const Divider(height: 20),
              _buildTotalSummaryRow(
                'purchase_order.net_payable'.tr,
                totals.netPayable,
                valueColor: ColorManager.kPrimaryColor,
                emphasize: true,
              ),
              if (discountValidationMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    discountValidationMessage,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.2,
                      Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomRoundButton(
          title: _isReceiveMode
              ? 'purchase_order.receive_items_btn'.tr
              : 'purchase_order.finish_btn'.tr,
          fct: _submitPurchaseOrder,
          width: double.infinity,
          height: 45,
          fontSize: 12,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildDiscountSummaryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'purchase_order.overall_discount'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.2,
            Colors.grey.shade700,
          ),
        ),
        SizedBox(
          width: 180,
          child: _buildInlineField(
            discountController,
            "0.00",
            (value) => setState(_syncPaidAmount),
            isNumber: true,
            prefixText: '$_currency ',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummaryRow(
    String label,
    double amount, {
    Color? valueColor,
    bool emphasize = false,
    String prefix = '',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.medium,
            emphasize ? FontSize.s15 : FontSize.s12,
            0.2,
            emphasize ? ColorManager.textColor : Colors.grey.shade700,
          ),
        ),
        Text(
          '$prefix$_currency ${amount.toStringAsFixed(2)}',
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.semiBold,
            emphasize ? FontSize.s18 : FontSize.s13,
            0.2,
            valueColor ?? ColorManager.textColor,
          ),
        ),
      ],
    );
  }
}
