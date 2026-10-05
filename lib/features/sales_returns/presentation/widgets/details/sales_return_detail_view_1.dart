part of 'sales_return_detail_view.dart';

extension _DetailSection1 on SalesReturnDetailSections {
  Widget _buildView() {
    final isPhone = salesReturnIsPhone(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: isPhone ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isPhone ? screenSize.width : 640,
          maxHeight: screenSize.height * (isPhone ? 0.92 : 0.85),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'sales_return.details_title'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.28,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SalesReturnContentCard(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SalesReturnLabelPill(
                              label: 'sales_return.order_info'.tr,
                            ),
                            const SizedBox(height: 14),
                            if (order.receiptNumber != null)
                              _buildInfoRow(
                                'sales_return.bill_number'.tr,
                                order.receiptNumber!,
                              ),
                            _buildInfoRow(
                              order.receiptNumber != null
                                  ? 'sales_return.order_number'.tr
                                  : 'sales.order_number_hint'.tr,
                              order.order?.orderNumber ?? '#${order.orderId}',
                            ),
                            _buildInfoRow(
                              'billing.customer'.tr,
                              order.order?.customer?.user?.name ??
                                  'confirmed_orders.na'.tr,
                            ),
                            Builder(
                              builder: (context) {
                                final currency = this.currency;
                                final raw = order.order?.grandTotal ?? '0.00';
                                final parsed = double.tryParse(raw);
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : raw;
                                return _buildInfoRow(
                                  'sales_return.grand_total'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            _buildInfoRow(
                              'confirmed_orders.payment_method'.tr,
                              order.order?.paymentMethod?.join(', ') ??
                                  'confirmed_orders.na'.tr,
                            ),
                            _buildInfoRow(
                              'sales.date_col'.tr,
                              DateHelper.formatDate(order.createdAt).toString(),
                            ),
                            Builder(
                              builder: (context) {
                                final currency = this.currency;
                                final parsed = double.tryParse(
                                  order.totalAmount,
                                );
                                final amount = parsed != null
                                    ? parsed.toStringAsFixed(2)
                                    : order.totalAmount;
                                return _buildInfoRow(
                                  'sales_return.return_total'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'sales_return.status_prefix'.tr,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    Colors.grey.shade600,
                                  ),
                                ),
                                SalesReturnStatusBadge(
                                  label: order.status.toString() == '1'
                                      ? 'sales_return.status_completed'.tr
                                      : 'sales_return.status_pending'.tr,
                                  isCompleted: order.status.toString() == '1',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'sales_return.return_items'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.22,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (order.items.isNotEmpty)
                        if (isPhone)
                          ...order.items.map(_buildMobileItemCard)
                        else
                          _buildItemsTable(context)
                      else if (_isLoadingItems)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _itemsError == null
                                ? 'sales_return.no_items_available'.tr
                                : 'sales_return.err_load_items'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SalesReturnActionRow(
                children: [
                  CustomRoundButton(
                    fct: () {
                      onPrint();
                    },
                    title: 'general.print'.tr,
                    fontSize: FontSize.s12,
                    height: 44,
                    width: isPhone ? double.infinity : 100,
                  ),
                  CustomRoundButton(
                    fct: onClose,
                    title: 'confirmed_orders.close'.tr,
                    fontSize: FontSize.s12,
                    height: 44,
                    width: isPhone ? double.infinity : 100,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 400;
          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  '$label:',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
