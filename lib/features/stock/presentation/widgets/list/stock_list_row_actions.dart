import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/resources/color_manager.dart';

class StockListRowActions extends StatelessWidget {
  final bool isMobile;
  final ListStockModelData stock;
  final void Function(ListStockModelData) onEdit;
  final void Function(ListStockModelData) onView;
  final void Function(ListStockModelData) onAdjust;
  final void Function(ListStockModelData) onMove;
  final void Function(ListStockModelData) onWithdraw;
  const StockListRowActions(
      {super.key,
      required this.isMobile,
      required this.stock,
      required this.onEdit,
      required this.onView,
      required this.onAdjust,
      required this.onMove,
      required this.onWithdraw});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: isMobile
          ? _buildMobileStockActionButtons(stock)
          : _buildDesktopStockActionButtons(stock));
  List<Widget> _buildMobileStockActionButtons(ListStockModelData stock) {
    return [
      Tooltip(
        message: 'stock.edit_stock_tooltip'.tr,
        child: SizedBox(
          width: 30,
          height: 30,
          child: BuildBoxShadowContainer(
            color: ColorManager.kPrimaryColor.withOpacity(0.9),
            circleRadius: 6,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 14, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onEdit(stock),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: 'stock.view_details_tooltip'.tr,
        child: SizedBox(
          width: 30,
          height: 30,
          child: BuildBoxShadowContainer(
            color: Colors.white,
            circleRadius: 6,
            child: IconButton(
              icon: Icon(Icons.visibility,
                  size: 14, color: ColorManager.kPrimaryColor.withOpacity(0.9)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onView(stock),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 30,
        height: 30,
        child: BuildBoxShadowContainer(
          circleRadius: 6,
          child: PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.more_vert,
              size: 14,
              color: ColorManager.kPrimaryColor,
            ),
            onSelected: (value) {
              if (value == 'adjust') {
                onAdjust(stock);
              } else if (value == 'move') {
                onMove(stock);
              } else if (value == 'withdraw') {
                onWithdraw(stock);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'adjust',
                child: Row(
                  children: [
                    const Icon(Icons.sync,
                        size: 18, color: ColorManager.kPrimaryColor),
                    const SizedBox(width: 8),
                    Text('stock.adjust_stock'.tr),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'move',
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward,
                        size: 18, color: ColorManager.kPrimaryColor),
                    const SizedBox(width: 8),
                    Text('stock.move_stock'.tr),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'withdraw',
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward,
                        size: 18, color: ColorManager.kPrimaryColor),
                    const SizedBox(width: 8),
                    Text('stock.withdraw_stock'.tr),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildDesktopStockActionButtons(ListStockModelData stock) {
    return [
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        color: ColorManager.kPrimaryColor.withOpacity(0.9),
        circleRadius: 5,
        child: IconButton(
          icon: const Icon(
            Icons.edit,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => onEdit(stock),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ),
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        circleRadius: 5,
        child: IconButton(
          icon: Icon(
            Icons.visibility,
            size: 18,
            color: ColorManager.kPrimaryColor.withOpacity(0.9),
          ),
          onPressed: () => onView(stock),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ),
      BuildBoxShadowContainer(
        margin: const EdgeInsets.all(2),
        circleRadius: 5,
        child: PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(
            Icons.more_vert,
            size: 16,
            color: ColorManager.kPrimaryColor,
          ),
          onSelected: (value) {
            if (value == 'adjust') {
              onAdjust(stock);
            } else if (value == 'move') {
              onMove(stock);
            } else if (value == 'withdraw') {
              onWithdraw(stock);
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'adjust',
              child: Row(
                children: [
                  const Icon(Icons.sync,
                      size: 18, color: ColorManager.kPrimaryColor),
                  const SizedBox(width: 8),
                  Text('stock.adjust_stock'.tr),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'move',
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 18, color: ColorManager.kPrimaryColor),
                  const SizedBox(width: 8),
                  Text('stock.move_stock'.tr),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'withdraw',
              child: Row(
                children: [
                  const Icon(Icons.arrow_downward,
                      size: 18, color: ColorManager.kPrimaryColor),
                  const SizedBox(width: 8),
                  Text('stock.withdraw_stock'.tr),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
