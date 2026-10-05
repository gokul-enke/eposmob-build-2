import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/purchase_returns/domain/purchase_return_pricing.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/purchase_orders_responsive.dart';
import '../../state/purchase_return_detail_controller.dart';
part 'purchase_return_detail_view_section_0.dart';

class PurchaseReturnDetailView {
  PurchaseReturnDetailView(
      {required this.context,
      required this.controller,
      required this.currency});
  final BuildContext context;
  final PurchaseReturnDetailController controller;
  final String currency;
  Widget build() {
    final isPhone = purchaseOrdersIsPhone(context);
    final screenSize = MediaQuery.of(context).size;
    final data = controller.displayData;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: isPhone ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isPhone ? screenSize.width : 640,
          maxHeight: screenSize.height * (isPhone ? 0.92 : 0.85),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'purchase_return.details_title'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.28,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PurchaseOrdersContentCard(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'purchase_return.reference'.tr,
                              data.reference ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.voucher_number'.tr,
                              data.voucherNumber ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.supplier'.tr,
                              data.supplier?.name ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.return_date'.tr,
                              data.returnDate ?? '-',
                            ),
                            Builder(
                              builder: (context) {
                                final currency = this.currency;
                                final amount =
                                    data.totalAmount?.toStringAsFixed(2) ??
                                        '0.00';
                                return _buildInfoRow(
                                  'purchase_return.total_amount'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final currency = this.currency;
                                final amount =
                                    data.paidAmount?.toStringAsFixed(2) ??
                                        '0.00';
                                return _buildInfoRow(
                                  'purchase_return.paid_amount'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            _buildInfoRow(
                              'purchase_return.created_by'.tr,
                              data.createdBy?.name ?? '-',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${'purchase_return.status'.tr}: ',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    Colors.grey.shade600,
                                  ),
                                ),
                                _buildStatusBadge(data.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'purchase_return.return_items'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.22,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (controller.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (data.items != null && data.items!.isNotEmpty)
                        if (isPhone)
                          ...data.items!.map(_buildMobileItemCard)
                        else
                          _buildItemsTable(data.items!)
                      else
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'purchase_return.no_items'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.15,
                                Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('confirmed_orders.close'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
