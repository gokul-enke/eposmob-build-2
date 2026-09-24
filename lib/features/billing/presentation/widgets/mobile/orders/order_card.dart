import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Compact saved-order card matching desktop [HorizontalSavedOrdersView] fields.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.isSelected,
    required this.onTap,
    this.onPrint,
    this.onDelete,
    this.isLoadingOrder = false,
  });

  final SavedOrder order;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onPrint;
  final VoidCallback? onDelete;
  final bool isLoadingOrder;

  String get _orderNumber =>
      order.orderNumber.trim().isNotEmpty ? order.orderNumber.trim() : order.id;

  String get _createdAtTime =>
      DateHelper.formatToISOTimeOnlyFromISO(order.createdAt);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoadingOrder ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? ColorManager.kPrimaryColor
                  : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? ColorManager.kPrimaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _createdAtTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Consumer<AppSettingsProvider>(
                      builder: (context, settings, _) {
                        final currency =
                            settings.appSettings?.currency ?? 'INR';
                        return Text(
                          '$currency ${order.total.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(
                      '${order.items.length} ${'common.items'.tr}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OrderIconAction(
                    icon: Icons.print,
                    color: Colors.blue,
                    onPressed: isLoadingOrder ? null : onPrint,
                    semanticLabel: 'billing.print_saved_order'.tr,
                  ),
                  _OrderIconAction(
                    icon: Icons.delete_outline,
                    color: ColorManager.kButtonRed,
                    onPressed: isLoadingOrder ? null : onDelete,
                    semanticLabel: 'billing.delete_saved_order'.tr,
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

class _OrderIconAction extends StatelessWidget {
  const _OrderIconAction({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticLabel,
  });

  static const double _minTouchTarget = 44;

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _minTouchTarget,
            height: _minTouchTarget,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
