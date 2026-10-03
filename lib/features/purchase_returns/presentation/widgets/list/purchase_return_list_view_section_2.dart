part of 'purchase_return_list_view.dart';

extension _Section2 on PurchaseReturnListView {
  Widget _buildStatusBadge(bool isCompleted) {
    final color = isCompleted ? Colors.green.shade700 : Colors.orange.shade800;
    final bgColor = isCompleted
        ? Colors.green.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1);
    final label = isCompleted
        ? 'purchase_return.status_completed'.tr
        : 'purchase_return.status_pending'.tr;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.13,
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
