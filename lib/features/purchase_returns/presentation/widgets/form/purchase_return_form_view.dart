import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/features/purchase_returns/domain/purchase_return_pricing.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';
import '../../state/create_purchase_return_controller.dart';
part 'purchase_return_form_view_section_0.dart';
part 'purchase_return_form_view_section_1.dart';
part 'purchase_return_form_view_section_2.dart';
part 'purchase_return_form_view_section_3.dart';

class PurchaseReturnFormView {
  PurchaseReturnFormView(
      {required this.context,
      required this.controller,
      required this.currency,
      required this.onBack,
      required this.onSubmit,
      required this.onPickDate});
  final BuildContext context;
  final CreatePurchaseReturnController controller;
  final String currency;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onPickDate;
  String _formatQty(double? value) =>
      PurchaseReturnPricing.formatQuantity(value);
  Widget build() {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersListShell(
      onRefresh:
          controller.voucherSelected ? () async {} : controller.loadVouchers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PurchaseOrdersPageHeader(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (controller.voucherSelected) {
                  controller.backToVouchers();
                } else {
                  onBack();
                }
              },
              tooltip: 'purchase_return.back_to_list'.tr,
            ),
            title: controller.voucherSelected
                ? 'purchase_return.returnable_items'.tr
                : 'purchase_return.select_voucher'.tr,
            subtitle: controller.voucherSelected
                ? '${'purchase_return.voucher_number'.tr}: ${controller.selectedVoucher?.voucherNumber ?? ''} • ${controller.selectedVoucher?.supplier?.name ?? ''}'
                : 'purchase_return.select_voucher_hint'.tr,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: controller.voucherSelected
                ? _buildReturnForm(isPhone)
                : _buildVoucherSelection(isPhone),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Voucher Selection ─────────────────────────────────────
}
