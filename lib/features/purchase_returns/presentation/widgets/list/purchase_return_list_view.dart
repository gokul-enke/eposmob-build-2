import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';
import '../../state/purchase_return_list_controller.dart';
part 'purchase_return_list_view_section_0.dart';
part 'purchase_return_list_view_section_1.dart';
part 'purchase_return_list_view_section_2.dart';

class PurchaseReturnListView {
  PurchaseReturnListView(
      {required this.context,
      required this.controller,
      required this.currency,
      required this.onCreate,
      required this.onView});
  final BuildContext context;
  final PurchaseReturnListController controller;
  final String currency;
  final VoidCallback onCreate;
  final void Function(PurchaseReturnData) onView;
  Widget build() {
    final provider = controller;
    final isPhone = purchaseOrdersIsPhone(context);
    final createButton = CustomRoundButton(
      key: const ValueKey('purchase-return-create-action'),
      title: 'purchase_return.create_btn'.tr,
      fct: () {
        onCreate();
      },
      fontSize: 12,
      height: 44,
      width: isPhone ? double.infinity : 200,
    );

    return PurchaseOrdersListShell(
      onRefresh: controller.resetFilters,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PurchaseOrdersPageHeader(
            title: 'purchase_return.title'.tr,
            subtitle: 'purchase_return.subtitle'.tr,
            leading: isPhone ? _buildFilterToggleButton() : null,
            trailing: isPhone
                ? createButton
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterToggleButton(),
                      const SizedBox(width: 8),
                      createButton,
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (controller.showFilters) ...[
            ConstrainedBox(
              key: const ValueKey('purchase-return-filters'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    (isPhone ? 0.42 : 0.55),
              ),
              child: SingleChildScrollView(child: _buildFiltersCard()),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: PurchaseOrdersContentCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  controller.isLoading && provider.purchaseReturnsList.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorManager.kPrimaryColor,
                          ),
                        )
                      : _buildContent(provider),
                  if (controller.isLoading &&
                      provider.purchaseReturnsList.isNotEmpty)
                    Container(
                      color: Colors.white.withOpacity(0.6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PaginationControl(
            currentPage: provider.purchaseReturnCurrentPage,
            totalPages: provider.purchaseReturnTotalPages,
            onPageChanged: (page) => this.controller.fetchReturns(page: page),
          ),
        ],
      ),
    );
  }
}
