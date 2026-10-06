import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/product/widgets/stock_responsive.dart';
import '../../state/stock_list_controller.dart';
import 'stock_list_filter_field.dart';

class StockListFilters extends StatelessWidget {
  final bool isMobile;
  final bool showFilters;
  final Size size;
  final StockListController inputs;
  final VoidCallback onSearch;
  final VoidCallback onReset;
  final VoidCallback onHide;
  const StockListFilters(
      {super.key,
      required this.isMobile,
      required this.showFilters,
      required this.size,
      required this.inputs,
      required this.onSearch,
      required this.onReset,
      required this.onHide});
  @override
  Widget build(BuildContext context) =>
      isMobile ? _buildMobileFiltersSection(size) : _buildDesktopFilters(size);
  Widget _buildMobileFiltersSection(Size size) {
    if (!showFilters) {
      return const SizedBox.shrink();
    }

    return StockContentCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'stock.filters_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.25,
                    ColorManager.textColor,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.expand_less),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => onHide(),
                  tooltip: 'stock.hide_filters'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StockListFilterField(
              field: StockListField.name,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 10),
          StockListFilterField(
              field: StockListField.category,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 10),
          StockListFilterField(
              field: StockListField.barcode,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 10),
          StockListFilterField(
              field: StockListField.rack,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 10),
          StockListFilterField(
              field: StockListField.store,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 10),
          StockListFilterField(
              field: StockListField.status,
              inputs: inputs,
              onSearch: onSearch,
              change: inputs.mutate),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: 'general.reset'.tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            borderColor: ColorManager.kPrimaryColor,
            fct: onReset,
            height: 44,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilters(Size size) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: StockListFilterField(
                    field: StockListField.name,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
            const SizedBox(width: 15),
            Expanded(
                child: StockListFilterField(
                    field: StockListField.category,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
            const SizedBox(width: 15),
            Expanded(
                child: StockListFilterField(
                    field: StockListField.barcode,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
            const SizedBox(width: 15),
            Expanded(
                child: StockListFilterField(
                    field: StockListField.rack,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: StockListFilterField(
                    field: StockListField.store,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
            const SizedBox(width: 15),
            Expanded(
                child: StockListFilterField(
                    field: StockListField.status,
                    inputs: inputs,
                    onSearch: onSearch,
                    change: inputs.mutate)),
            const SizedBox(width: 15),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 15),
            Expanded(
              child: CustomRoundButton(
                title: 'general.reset'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: onReset,
                height: 45,
                width: double.infinity,
                fontSize: FontSize.s12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
