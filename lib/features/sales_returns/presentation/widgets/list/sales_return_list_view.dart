import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/features/sales_returns/presentation/widgets/sales_return_responsive.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/sales_return_list_controller.dart';

part 'sales_return_list_view_1.dart';
part 'sales_return_list_view_2.dart';

class SalesReturnListSections {
  const SalesReturnListSections(
      {required this.context,
      required this.controller,
      required this.currency,
      required this.onCopy,
      required this.onView,
      required this.onPrint});
  Widget build() => _buildView();
  final BuildContext context;
  final SalesReturnListController controller;
  final String currency;
  final void Function(SalesReturnOrder) onCopy, onView, onPrint;
  bool get _isLoading => controller.isLoading;
  String? get _loadError => controller.loadError;
  Future<void> _fetchSalesReturns() => controller.load();
  void _searchSalesReturns(int page) => controller.load(page: page);
}
