import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'quotations_responsive.dart';

class QuotationDetailWidget extends StatelessWidget {
  final QuotationDetailsData data;

  const QuotationDetailWidget({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(context),
        const SizedBox(height: 16),
        _buildItemsSection(context, currency),
        const SizedBox(height: 16),
        _buildSummaryCard(context, currency),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final isPhone = quotationsIsPhone(context);

    return QuotationsContentCard(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPhone) ...[
            Text(
              "Quotation # ${data.quotationNumber ?? ''}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.3,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusChip(data.status ?? ''),
            const SizedBox(height: 12),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Quotation # ${data.quotationNumber ?? ''}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s18,
                      0.3,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(data.status ?? ''),
              ],
            ),
          Divider(color: Colors.grey.withOpacity(0.15)),
          if (isPhone) ...[
            QuotationsInfoChip(
              label: 'Customer',
              value: data.customer?.name ?? 'NA',
            ),
            const SizedBox(height: 10),
            QuotationsInfoChip(
              label: 'Store',
              value: data.store?.name ?? 'NA',
            ),
            const SizedBox(height: 10),
            QuotationsTwoColumnLayout(
              start: QuotationsInfoChip(
                label: 'Date',
                value: data.quotationDate ?? 'NA',
              ),
              end: QuotationsInfoChip(
                label: 'Expiry',
                value: data.expiryDate ?? 'NA',
              ),
            ),
          ] else ...[
            _infoRow("Customer", data.customer?.name ?? 'NA'),
            _infoRow("Store", data.store?.name ?? 'NA'),
            _infoRow("Date", data.quotationDate ?? 'NA'),
            _infoRow("Expiry", data.expiryDate ?? 'NA'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return QuotationsStatusBadge(label: status, color: color);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'order created':
      case 'confirmed':
        return Colors.green;
      case 'rejected':
      case 'expired':
      case 'cancel':
      case 'cancelled':
        return ColorManager.kButtonRed;
      case 'sent':
        return ColorManager.kPrimaryColor;
      default:
        return Colors.orange;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, String currency) {
    final items = data.items ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    if (quotationsIsPhone(context)) {
      return _buildMobileItemsList(items, currency);
    }

    return QuotationsContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: QuotationsSectionTitle(title: 'Items'),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final table = Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.05),
                      ),
                      children: ['Product', 'Qty', 'Price', 'Total']
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                t,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  ColorManager.textColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...items.map(
                      (item) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              item.productName ?? 'NA',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.18,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              item.quantity?.toString() ?? '0',
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.18,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              "$currency ${item.unitPrice ?? '0'}",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.18,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              "$currency ${item.totalPrice ?? '0'}",
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.18,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth >= 640) return table;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 640),
                    child: table,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemsList(List<QuotationItem> items, String currency) {
    return QuotationsContentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuotationsSectionTitle(title: 'Items'),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildMobileItemCard(items[i], currency),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(QuotationItem item, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName ?? 'NA',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          QuotationsDetailGrid(
            children: [
              QuotationsInfoChip(
                label: 'Qty',
                value: item.quantity?.toString() ?? '0',
              ),
              QuotationsInfoChip(
                label: 'Price',
                value: '$currency ${item.unitPrice ?? '0'}',
              ),
              QuotationsInfoChip(
                label: 'Total',
                value: '$currency ${item.totalPrice ?? '0'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String currency) {
    return QuotationsContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BuildPaymentRow(
            title: "Sub Total",
            amount: "$currency ${data.subTotal ?? '0.00'}",
            color: ColorManager.textColor,
          ),
          BuildPaymentRow(
            title: "Tax",
            amount: "$currency ${data.tax ?? '0.00'}",
            color: ColorManager.textColor,
          ),
          if (data.discount != null)
            BuildPaymentRow(
              title: "Discount",
              amount: "$currency ${data.discount}",
              color: ColorManager.textColor,
            ),
          Divider(color: Colors.grey.withOpacity(0.15)),
          BuildPaymentRow(
            title: "Grand Total",
            amount: "$currency ${data.grandTotal ?? '0.00'}",
            color: ColorManager.kPrimaryColor,
            firstRowTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorManager.kPrimaryColor,
            ),
            secondRowTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
