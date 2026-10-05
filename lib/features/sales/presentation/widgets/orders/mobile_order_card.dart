import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class MobileOrderCard extends StatelessWidget {
  final ListOrderModelData order;
  final int index;
  final VoidCallback onView, onPrint, onOptions;
  final String currency;
  final Function(ListOrderModelData) onSharePDF;
  final Function(ListOrderModelData) onShareWhatsApp;

  const MobileOrderCard({
    super.key,
    required this.order,
    required this.index,
    required this.onView,
    required this.onPrint,
    required this.onOptions,
    required this.currency,
    required this.onSharePDF,
    required this.onShareWhatsApp,
  });

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'sales.status_new'.tr;
      case 'pending':
        return 'sales.status_pending'.tr;
      case 'confirmed':
        return 'sales.status_confirmed'.tr;
      case 'cancelled':
        return 'sales.status_cancelled'.tr;
      default:
        return UiCodeLabels.status(status);
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade800;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        break;
      case 'new':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.12);
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(
          start: 10, end: 12, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PriceSummary priceSummary = order.priceSummary ?? PriceSummary();
    final customerLabel = (order.customerName?.isNotEmpty == true)
        ? order.customerName!
        : (order.customerDetails?.phone?.isNotEmpty == true
            ? order.customerDetails!.phone!
            : "NA");

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        padding: const EdgeInsets.all(16),
        showShadow: true,
        blurRadius: 10,
        offsetValue: const Offset(0, 3),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        color: Colors.white,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "#${order.orderNumber}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.18,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ),
                        if (order.customerReceiptNumber != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: order.customerReceiptNumber!));
                              showScaffold(
                                context: context,
                                message: 'sales.order_number_copied'.tr,
                              );
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(order.status ?? "pending"),
                ],
              ),
              if (order.receiptNumber?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                SelectableText(
                  order.receiptNumber!.trim(),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.12,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      customerLabel,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DateHelper.formatYearMonthDay(order.orderDate!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.18,
                              Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "${order.cartItems?.length ?? 0} items",
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.18,
                          Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            // Keep the mobile amount consistent with the desktop
                            // table, which displays the order-level grand_total.
                            "$currency ${AmountHelper.formatAmount(order.grantTotal ?? priceSummary.grandTotal ?? 0.0)}",
                            maxLines: 1,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.18,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.visibility,
                        color: ColorManager.kPrimaryColor,
                        onPressed: onView,
                      ),
                      _buildActionButton(
                        icon: Icons.print,
                        color: Colors.blue,
                        onPressed: onPrint,
                      ),
                      _buildActionButton(
                        icon: Icons.more_vert,
                        color: Colors.blue,
                        onPressed: onOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
