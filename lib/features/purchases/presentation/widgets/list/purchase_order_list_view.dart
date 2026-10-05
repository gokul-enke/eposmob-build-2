import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/purchase_orders_responsive.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/purchase_order_list_controller.dart';

part 'purchase_order_list_view_1.dart';
part 'purchase_order_list_view_2.dart';
part 'purchase_order_list_view_3.dart';
part 'purchase_order_list_view_4.dart';

class PurchaseOrderListView {
  PurchaseOrderListView(
      {required this.context,
      required this.controller,
      required this.currency,
      required this.onCreate,
      required this.onOpen});
  final BuildContext context;
  final PurchaseOrderListController controller;
  final String currency;
  final VoidCallback onCreate;
  final Future<void> Function(PurchaseOrderData, int) onOpen;
  Widget build() => _buildView();
  static const int _itemsPerPage = 15;
  TextEditingController get supplierController => controller.supplierController;
  TextEditingController get supplierSearchController =>
      controller.supplierSearchController;
  TextEditingController get storeController => controller.storeController;
  TextEditingController get storeSearchController =>
      controller.storeSearchController;
  TextEditingController get fromDateController => controller.fromDateController;
  TextEditingController get toDateController => controller.toDateController;
  bool get initLoading => controller.initLoading;
  List<String> get suppliers => controller.suppliers;
  List<String> get stores => controller.stores;
}
