import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class QuotationDetailWidget extends StatelessWidget {
  final QuotationDetailsData data;

  const QuotationDetailWidget({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(context),
        const SizedBox(height: 16),
        _buildItemsTable(context, currency),
        const SizedBox(height: 16),
        _buildSummaryCard(context, currency),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quotation # ${data.quotationNumber ?? ''}",
                style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18, 0.3, ColorManager.textColor),
              ),
              _buildStatusChip(data.status ?? ''),
            ],
          ),
          const Divider(),
          _infoRow("Customer", data.customer?.name ?? 'NA'),
          _infoRow("Store", data.store?.name ?? 'NA'),
          _infoRow("Date", data.quotationDate ?? 'NA'),
          _infoRow("Expiry", data.expiryDate ?? 'NA'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'order created':
        color = Colors.green;
        break;
      case 'rejected':
      case 'expired':
        color = ColorManager.kButtonRed;
        break;
      case 'sent':
        color = ColorManager.kPrimaryColor;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, String currency) {
    final items = data.items ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Items", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16, 0.2, ColorManager.textColor)),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: ColorManager.kPrimaryColor.withOpacity(0.05)),
                children: ["Product", "Qty", "Price", "Total"].map((t) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )).toList(),
              ),
              ...items.map((item) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(12), child: Text(item.productName ?? 'NA', style: const TextStyle(fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(12), child: Text(item.quantity?.toString() ?? '0', style: const TextStyle(fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(12), child: Text("$currency ${item.unitPrice ?? '0'}", style: const TextStyle(fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(12), child: Text("$currency ${item.totalPrice ?? '0'}", style: const TextStyle(fontSize: 12))),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String currency) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BuildPaymentRow(title: "Sub Total", amount: "$currency ${data.subTotal ?? '0.00'}", color: ColorManager.textColor),
          BuildPaymentRow(title: "Tax", amount: "$currency ${data.tax ?? '0.00'}", color: ColorManager.textColor),
          if (data.discount != null)
             BuildPaymentRow(title: "Discount", amount: "$currency ${data.discount}", color: ColorManager.textColor),
          const Divider(),
          BuildPaymentRow(
            title: "Grand Total",
            amount: "$currency ${data.grandTotal ?? '0.00'}",
            color: ColorManager.kPrimaryColor,
            firstRowTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorManager.kPrimaryColor),
            secondRowTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorManager.kPrimaryColor),
          ),
        ],
      ),
    );
  }

}
