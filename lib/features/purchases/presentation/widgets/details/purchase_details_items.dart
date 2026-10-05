part of 'purchase_details_view.dart';

extension PurchaseDetailsItems on PurchaseDetailsView {
  Widget _buildItems(_PurchaseViewData viewData, String currency) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth =
              constraints.maxWidth < PurchaseDetailsView._minimumTableWidth
                  ? PurchaseDetailsView._minimumTableWidth
                  : constraints.maxWidth;
          final columns = _TableColumns.forWidth(tableWidth);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TableRowContainer(
                    width: tableWidth,
                    color: const Color(0xFFF9FAFB),
                    child: Row(
                      children: [
                        _TableHeaderCell(
                          text: 'purchase_order.product_col_caps'.tr,
                          width: columns.product,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.category_col_caps'.tr,
                          width: columns.category,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.quantity_col_caps'.tr,
                          width: columns.quantity,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.unit_price_col_caps'.tr,
                          width: columns.unitPrice,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.total_col_caps'.tr,
                          width: columns.total,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.batch_no_col'.tr,
                          width: columns.batch,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.expiry_date_col_caps'.tr,
                          width: columns.expiry,
                        ),
                        _TableHeaderCell(
                          text: 'purchase_order.status_col_caps'.tr,
                          width: columns.status,
                        ),
                      ],
                    ),
                  ),
                  ...viewData.items.map(
                    (item) => _TableRowContainer(
                      width: tableWidth,
                      child: Row(
                        children: [
                          SizedBox(
                            width: columns.product,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s12,
                                      0.2,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  if (item.variantName != null &&
                                      item.variantName!.isNotEmpty &&
                                      item.variantName != item.productName) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.variantName!.contains(' - ')
                                          ? item.variantName!.split(' - ').last
                                          : item.variantName!,
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s10,
                                        0.15,
                                        Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          _TableValueCell(
                            text: item.categoryName,
                            width: columns.category,
                            textColor: const Color(0xFF6B7280),
                          ),
                          _TableValueCell(
                            text: item.quantity,
                            width: columns.quantity,
                            align: TextAlign.center,
                          ),
                          _TableValueCell(
                            text: _DisplayFormatter.currency(
                              item.unitPrice,
                              currency: currency,
                            ),
                            width: columns.unitPrice,
                            align: TextAlign.center,
                          ),
                          _TableValueCell(
                            text: _DisplayFormatter.currency(
                              item.totalPrice,
                              currency: currency,
                            ),
                            width: columns.total,
                            isBold: true,
                            align: TextAlign.center,
                          ),
                          _TableValueCell(
                            text: item.batchNumber,
                            width: columns.batch,
                            align: TextAlign.center,
                            textColor: const Color(0xFF6B7280),
                          ),
                          _TableValueCell(
                            text: item.expiryDate,
                            width: columns.expiry,
                            align: TextAlign.center,
                            textColor: const Color(0xFF6B7280),
                          ),
                          _TableStatusCell(
                            width: columns.status,
                            label: item.statusLabel,
                            color: item.statusColor,
                            backgroundColor: item.statusBackground,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _TableRowContainer(
                    width: tableWidth,
                    color: const Color(0xFFF9FAFB),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 360,
                          child: _PurchaseTotalsSummary(
                            grossAmount: viewData.grossAmount,
                            discountAmount: viewData.discountAmount,
                            netPayable: viewData.amountTotal,
                            currency: currency,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
