import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../state/stock_list_controller.dart';

class StockListHeader extends StatelessWidget {
  final bool isMobile;
  final bool showFilters;
  final bool Function() hasActiveFilters;
  final VoidCallback onAdd;
  final VoidCallback onToggle;
  final StockListController inputs;
  const StockListHeader(
      {super.key,
      required this.isMobile,
      required this.showFilters,
      required this.hasActiveFilters,
      required this.onAdd,
      required this.onToggle,
      required this.inputs});
  @override
  Widget build(BuildContext context) =>
      isMobile ? _buildMobileHeader() : _buildDesktopHeader();
  Widget _buildDesktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'stock.title'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                0.30, ColorManager.textColor),
          ),
        ),
        _buildFilterToggleButton(),
        const SizedBox(width: 8),
        CustomRoundButton(
          title: 'stock.add'.tr,
          fct: () async {
            onAdd();
          },
          fontSize: 12,
          height: 45,
          width: 150,
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'stock.title'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
            ),
            _buildFilterToggleButton(),
          ],
        ),
        const SizedBox(height: 12),
        CustomRoundButton(
          title: 'stock.add'.tr,
          fct: () async {
            onAdd();
          },
          fontSize: 12,
          height: 45,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildFilterToggleButton() {
    return FilterToggleButton(
      key: const Key('stock-filter-toggle'),
      showFilters: showFilters,
      hasActiveFilters: hasActiveFilters(),
      activeFiltersListenable: Listenable.merge([
        inputs.stockNameController,
        inputs.categoryController,
        inputs.barcodeController,
        inputs.rackController,
        inputs.storeController,
        inputs.stockStatusController,
      ]),
      activeFiltersBuilder: hasActiveFilters,
      onPressed: () => onToggle(),
      showTooltip: 'stock.show_filters'.tr,
      hideTooltip: 'stock.hide_filters'.tr,
    );
  }
}
