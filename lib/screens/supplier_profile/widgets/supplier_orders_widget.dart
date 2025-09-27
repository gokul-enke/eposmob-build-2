import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class SupplierOrdersWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierOrdersWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierOrdersWidget> createState() => _SupplierOrdersWidgetState();
}

class _SupplierOrdersWidgetState extends State<SupplierOrdersWidget> {
  late List<SupplierPurchase> purchases;

  @override
  void initState() {
    super.initState();
    purchases = widget.supplier.purchases;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: purchases.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: purchases.length,
                      itemBuilder: (context, index) =>
                          _buildPurchaseCard(purchases[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart,
                  color: ColorManager.kPrimaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Purchase Orders (${purchases.length})',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                    ColorManager.kTitleTextColor),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () {
                  // Add print functionality
                },
                color: ColorManager.kGreyColor,
                tooltip: 'Print purchases',
              ),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () {},
                color: ColorManager.kGreyColor,
                tooltip: 'Sort purchases',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            'No Purchase Orders Found',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'No purchase orders are available for this supplier.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }
  Widget _buildPurchaseCard(SupplierPurchase purchase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kBgDarkColor),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildPurchaseStatusIcon(purchase.status),
          title: Text(
            'Purchase #${purchase.purchaseNumber}',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            '${purchase.items.length} item${purchase.items.length != 1 ? 's' : ''}',
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0,
                ColorManager.kGreyColor),
          ),
          trailing: Consumer<AppSettingsProvider>(
            builder: (context, appSettingsProvider, child) {
              final currency =
                  appSettingsProvider.appSettings?.currency ?? 'INR';
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency ${purchase.amountTotal}',
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s14, 0, ColorManager.kSuccessColor),
                  ),
                  const SizedBox(height: 2),
                  _buildStatusBadge(purchase.status),
                ],
              );
            },
          ),
          children: [_buildPurchaseDetails(purchase)],
        ),
      ),
    );
  }

  Widget _buildPurchaseStatusIcon(String? status) {
    IconData iconData;
    switch (status?.toLowerCase()) {
      case 'y':
      case 'completed':
        iconData = Icons.check_circle;
        break;
      case 'n':
      case 'pending':
        iconData = Icons.pending_actions;
        break;
      case 'cancelled':
        iconData = Icons.cancel;
        break;
      default:
        iconData = Icons.shopping_cart;
    }
    return CircleAvatar(
      backgroundColor: _getStatusColor(status).withOpacity(0.1),
      child: Icon(iconData, color: _getStatusColor(status), size: 22),
    );
  }

  Widget _buildStatusBadge(String? status) {
    String displayStatus;
    switch (status?.toLowerCase()) {
      case 'y':
        displayStatus = 'COMPLETED';
        break;
      case 'n':
        displayStatus = 'PENDING';
        break;
      default:
        displayStatus = status?.toUpperCase() ?? 'N/A';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus,
        style: buildCustomStyle(
            FontWeightManager.medium, FontSize.s10, 0, _getStatusColor(status)),
      ),
    );
  }

  Widget _buildPurchaseDetails(SupplierPurchase purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: ColorManager.kBgLightColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Purchase Number', purchase.purchaseNumber),
          _buildDetailRow('Status', _getStatusDisplayText(purchase.status),
              valueColor: _getStatusColor(purchase.status)),
          const Divider(height: 20),
          ..._buildPurchaseItemsList(purchase.items),
          const Divider(height: 20),
          _buildTotalRow('Subtotal', purchase.amountTotal),
          if (purchase.taxTotal != null && purchase.taxTotal != '0.00')
            _buildTotalRow('Tax', purchase.taxTotal!),
          const SizedBox(height: 8),
          _buildTotalRow('Total Amount', purchase.amountTotal, isGrandTotal: true),
        ],
      ),
    );
  }

  List<Widget> _buildPurchaseItemsList(List<PurchaseItem>? items) {
    if (items == null || items.isEmpty) {
      return [const Text('No items in this purchase.')];
    }

    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';

    return items
        .map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName} (x${item.quantity})',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0, ColorManager.kTitleTextColor),
                    ),
                  ),
                  Text(
                    '$currency ${item.totalPrice}',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0, ColorManager.kTitleTextColor),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _buildDetailRow(String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0,
                  ColorManager.kGreyColor)),
          Text(value ?? 'N/A',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0, valueColor ?? ColorManager.kTitleTextColor)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String? value,
      {bool isGrandTotal = false, Color? color}) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: isGrandTotal
                    ? buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0,
                        ColorManager.kTitleTextColor)
                    : buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                        0, ColorManager.kGreyColor),
              ),
              Text(
                '$currency ${value ?? '0.00'}',
                style: isGrandTotal
                    ? buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0,
                        color ?? ColorManager.kSuccessColor)
                    : buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                        0, color ?? ColorManager.kTitleTextColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'y':
      case 'completed':
        return ColorManager.kSuccessColor;
      case 'n':
      case 'pending':
        return ColorManager.kOrange;
      case 'cancelled':
        return ColorManager.kRed;
      default:
        return ColorManager.kGreyColor;
    }
  }

  String _getStatusDisplayText(String? status) {
    switch (status?.toLowerCase()) {
      case 'y':
        return 'Completed';
      case 'n':
        return 'Pending';
      default:
        return status ?? 'N/A';
    }
  }
}
