part of 'sales_return_form_view.dart';

extension _FormSection6 on SalesReturnFormSections {
  Widget _buildPaymentDetailsSection() {
    return Builder(builder: (context) {
      final salesProvider = controller;
      final salesReturnItems = salesProvider.salesReturnItems;

      if (salesReturnItems.isEmpty) {
        return const SizedBox.shrink();
      }

      final refundSummary = refundSummaryFor(
        salesReturnItems,
        serverBreakdown: salesProvider.serverRefundBreakdown,
      );
      final suggestedRefund = refundSummary.netRefundAmount;
      final maxCashRefund = refundSummary.maxCashRefundAmount;

      if (hasPayment && paidAmountController.text.isEmpty) {
        paidAmountController.text = suggestedRefund.toStringAsFixed(2);
      }

      final double enteredAmount =
          double.tryParse(paidAmountController.text) ?? 0.0;
      final bool isExceedingMax = hasPayment && enteredAmount > maxCashRefund;

      return SalesReturnContentCard(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            EdgeInsetsDirectional.all(salesReturnIsPhone(context) ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Switch.adaptive(
                  value: deliveryChargeRefundable,
                  activeColor: ColorManager.kPrimaryColor,
                  onChanged: (value) {
                    setState(() {
                      deliveryChargeRefundable = value;
                      if (hasPayment) {
                        paidAmountController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_return_form.payment_delivery_refundable'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'sales_return_form.payment_delivery_hint'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isPhone =
                    constraints.maxWidth < kSalesReturnPhoneBreakpoint;
                final headerRow = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'sales_return_form.payment_section_title'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.25,
                          Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                );
                final paymentToggle = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'sales_return_form.payment_has_payment'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.25,
                        Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: hasPayment,
                      onChanged: (value) {
                        setState(() {
                          hasPayment = value;
                          if (!hasPayment) {
                            paidAmountController.clear();
                          }
                        });
                      },
                      activeColor: ColorManager.kPrimaryColor,
                    ),
                  ],
                );

                if (isPhone) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow,
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: paymentToggle,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: headerRow),
                    paymentToggle,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (!hasPayment)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'sales_return_form.payment_no_mode'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.25,
                          Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (hasPayment) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isPhone =
                      constraints.maxWidth < kSalesReturnPhoneBreakpoint;
                  final paymentMethodField = _paymentMethodField();
                  final amountField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_return_form.payment_amount_label'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.25,
                          Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final currency = this.currency;
                          return SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: paidAmountController,
                              focusNode: paidAmountFocusNode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textAlignVertical: TextAlignVertical.center,
                              onTap: () {
                                paidAmountController.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset:
                                      paidAmountController.text.length,
                                );
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                errorText: isExceedingMax
                                    ? 'sales_return_form.payment_amount_exceeds'
                                        .trParams({
                                        'max': maxCashRefund.toStringAsFixed(2)
                                      })
                                    : null,
                                prefixText: '$currency ',
                                constraints:
                                    const BoxConstraints.tightFor(height: 48),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: ColorManager.kPrimaryColor),
                                ),
                                contentPadding:
                                    const EdgeInsetsDirectional.symmetric(
                                        horizontal: 12, vertical: 12),
                              ),
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s14,
                                0.25,
                                ColorManager.textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );

                  if (isPhone) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        paymentMethodField,
                        const SizedBox(height: 12),
                        amountField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 2, child: paymentMethodField),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: amountField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                refundSummary.isFromServer
                    ? 'sales_return_form.payment_returned_total'.trParams({
                        'total':
                            refundSummary.sessionItemsTotal.toStringAsFixed(2)
                      })
                    : 'sales_return_form.payment_items_total'.trParams({
                        'total':
                            refundSummary.sessionItemsTotal.toStringAsFixed(2)
                      }),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
              if (refundSummary.isFromServer) ...[
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_server_calc'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s10,
                    0.25,
                    ColorManager.kPrimaryColor.withOpacity(0.8),
                  ),
                ),
              ],
              if (refundSummary.proRataDiscount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_suggested'
                      .trParams({'amount': suggestedRefund.toStringAsFixed(2)}),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'sales_return_form.payment_pro_rata'.trParams({
                    'amount': refundSummary.proRataDiscount.toStringAsFixed(2)
                  }),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'sales_return_form.payment_max_refund'
                    .trParams({'max': maxCashRefund.toStringAsFixed(2)}),
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'sales_return_form.payment_refund_note'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.25,
                  Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
