part of 'purchase_order_list_view.dart';

extension _PurchaseOrderListView4 on PurchaseOrderListView {
  Widget _buildReceivedBadgeWidget(String itemsReceived) {
    int received = 0;
    int total = 0;
    final parts = itemsReceived.split('/');
    if (parts.length == 2) {
      received = int.tryParse(parts[0].trim()) ?? 0;
      total = int.tryParse(parts[1].trim()) ?? 0;
    }

    final isFull = total > 0 && received == total;
    final hasProgress = total > 0 && received > 0 && received < total;
    final backgroundColor = isFull
        ? const Color(0xFFE7F8EC)
        : hasProgress
            ? const Color(0xFFFFF4DD)
            : const Color(0xFFF3F5F7);
    final borderColor = isFull
        ? const Color(0xFF65C16F)
        : hasProgress
            ? const Color(0xFFF0B54A)
            : const Color(0xFFD7DDE3);
    final iconColor = isFull
        ? const Color(0xFF2E9B42)
        : hasProgress
            ? const Color(0xFFB97A00)
            : const Color(0xFF7B8794);
    final icon = isFull
        ? Icons.check_circle_rounded
        : hasProgress
            ? Icons.timelapse_rounded
            : Icons.inventory_2_outlined;

    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            itemsReceived,
            style: TextStyle(
              fontWeight: FontWeightManager.semiBold,
              fontSize: FontSize.s12,
              color: isFull
                  ? const Color(0xFF166534)
                  : hasProgress
                      ? const Color(0xFF8A5A00)
                      : const Color(0xFF4B5563),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedBadge(String itemsReceived) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
        child: Center(
          child: _buildReceivedBadgeWidget(itemsReceived),
        ),
      ),
    );
  }
}
