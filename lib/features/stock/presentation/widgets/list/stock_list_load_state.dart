import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class StockListLoadState extends StatelessWidget {
  final bool loading;
  final bool hasFilters;
  final VoidCallback onReset;
  const StockListLoadState(
      {super.key,
      required this.loading,
      required this.hasFilters,
      required this.onReset});
  @override
  Widget build(BuildContext context) =>
      loading ? _buildLoadingState() : _buildEmptyState();
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: 14),
          Text(
            'stock.loading'.tr,
            style: const TextStyle(
              color: ColorManager.kGreyColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'stock.no_stock_filtered'.tr
                  : 'stock.no_stock_data'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.textColor,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              Text(
                'stock.try_adjusting_filters'.tr,
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.15,
                  Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'stock.reset_filters_btn'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: onReset,
                height: 44,
                width: 160,
                fontSize: FontSize.s12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
