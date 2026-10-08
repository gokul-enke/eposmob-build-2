import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_stock.dart';

class StockListRowActions extends StatelessWidget {
  const StockListRowActions(
      {super.key,
      required this.isMobile,
      required this.stock,
      required this.onEdit,
      required this.onView,
      required this.onAdjust,
      required this.onMove,
      required this.onWithdraw});
  final bool isMobile;
  final ListStockModelData stock;
  final void Function(ListStockModelData) onEdit,
      onView,
      onAdjust,
      onMove,
      onWithdraw;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppOutlinedButton(
                label: 'stock.edit'.tr,
                icon: Icons.edit,
                height: AppSizes.compactControl,
                onPressed: () => onEdit(stock)),
            AppOutlinedButton(
                label: 'stock.list_view'.tr,
                icon: Icons.visibility,
                height: AppSizes.compactControl,
                onPressed: () => onView(stock)),
            PopupMenuButton<String>(
              color: AppColors.surface,
              surfaceTintColor: AppColors.surface,
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onSelected: (action) => switch (action) {
                'adjust' => onAdjust(stock),
                'move' => onMove(stock),
                'withdraw' => onWithdraw(stock),
                _ => null,
              },
              itemBuilder: (_) => [
                for (final entry in {
                  'adjust': 'stock.adjust_stock',
                  'move': 'stock.move_stock',
                  'withdraw': 'stock.withdraw_stock'
                }.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value.tr)),
              ],
              child: Builder(
                  builder: (menuContext) => AppSquareIconButton(
                      icon: Icons.more_vert,
                      tooltip:
                          MaterialLocalizations.of(context).showMenuTooltip,
                      size: AppSizes.compactControl,
                      foreground: AppColors.primary,
                      onPressed: () => menuContext
                          .findAncestorStateOfType<
                              PopupMenuButtonState<String>>()
                          ?.showButtonMenu())),
            ),
          ]);
}
