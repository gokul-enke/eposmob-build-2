import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/features/sales_returns/presentation/printing/sales_return_print_items.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import '../sales_return_responsive.dart';

import '../../state/sales_return_details_controller.dart';

part 'sales_return_detail_view_1.dart';
part 'sales_return_detail_view_2.dart';

class SalesReturnDetailSections {
  const SalesReturnDetailSections(
      {required this.context,
      required this.order,
      required this.controller,
      required this.currency,
      required this.onPrint,
      required this.onClose});
  final BuildContext context;
  final SalesReturnOrder order;
  final SalesReturnDetailsController controller;
  final String currency;
  final VoidCallback onPrint, onClose;
  List<SalesReturnCart> get _loadedItems => controller.items;
  bool get _isLoadingItems => controller.loading;
  String? get _itemsError => controller.error;
  Widget build() => _buildView();
}

class _SalesReturnTableHeaderCell extends StatelessWidget {
  final String label;

  const _SalesReturnTableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}
