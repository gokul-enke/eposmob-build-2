import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/features/purchases/presentation/navigation/purchase_navigation.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

part 'purchase_details_items.dart';
part 'purchase_details_helpers_1.dart';
part 'purchase_details_helpers_2.dart';
part 'purchase_details_helpers_3.dart';

class PurchaseDetailsView extends StatelessWidget {
  const PurchaseDetailsView(
      {super.key,
      required this.purchase,
      required this.products,
      required this.categories,
      required this.currency});
  final PurchaseDetailsInput purchase;
  final List<GetProduct>? products;
  final List<Category> categories;
  final String currency;

  static const double _productColumnWidth = 220;
  static const double _categoryColumnWidth = 160;
  static const double _quantityColumnWidth = 120;
  static const double _unitPriceColumnWidth = 140;
  static const double _totalColumnWidth = 140;
  static const double _batchColumnWidth = 120;
  static const double _expiryColumnWidth = 140;
  static const double _statusColumnWidth = 120;

  static const double _minimumTableWidth = _productColumnWidth +
      _categoryColumnWidth +
      _quantityColumnWidth +
      _unitPriceColumnWidth +
      _totalColumnWidth +
      _batchColumnWidth +
      _expiryColumnWidth +
      _statusColumnWidth;

  @override
  Widget build(BuildContext context) {
    final viewData = _PurchaseViewData.fromProvider(
      purchase,
      products,
      categories,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: ColorManager.boxShadowColor,
                      blurRadius: 6,
                      offset: Offset(1, 1),
                    ),
                  ],
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 10.0,
                  ),
                  child: viewData == null
                      ? _EmptyPurchaseState(
                          onBack: () => PurchaseNavigation.openList(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomBackButton(
                              onPressed: () {
                                PurchaseNavigation.openList();
                              },
                              text: 'purchase_order.all_purchases'.tr,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'purchase_order.purchase_voucher_hash'
                                        .tr
                                        .replaceAll(
                                            '@number', viewData.voucherNumber),
                                    style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s24,
                                      0.2,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                ),
                                _TopActionButton(
                                  label: 'purchase_order.print'.tr,
                                  icon: Icons.print_outlined,
                                  onPressed: () {
                                    AppToast.info(context,
                                        'purchase_order.print_coming_soon'.tr);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _SectionCard(
                              title: 'purchase_order.voucher_information'.tr,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 720;
                                  final blockWidth = isCompact
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 40) / 3;

                                  return Wrap(
                                    spacing: 20,
                                    runSpacing: 26,
                                    children: [
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'purchase_order.voucher_number'
                                              .tr,
                                          value: viewData.voucherNumber,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label:
                                              'purchase_order.purchase_date'.tr,
                                          value: _DisplayFormatter.date(
                                            viewData.purchaseDate,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label:
                                              'purchase_order.net_payable'.tr,
                                          value: _DisplayFormatter.currency(
                                            viewData.amountTotal,
                                            currency: currency,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'purchase_order.supplier'.tr,
                                          value: viewData.supplierName,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'purchase_order.store'.tr,
                                          value: viewData.storeName,
                                        ),
                                      ),
                                      SizedBox(
                                        width: blockWidth,
                                        child: _InfoBlock(
                                          label: 'purchase_order.status'.tr,
                                          value: viewData.statusLabel,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            _SectionCard(
                              title: 'purchase_order.purchase_items'.tr,
                              child: _buildItems(viewData, currency),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PurchaseDetailsInput {
  PurchaseDetailsInput(
      {required this.activePurchaseOrderDetails,
      required this.getVoucherDetails,
      required this.getlistPurchaseItemView,
      required this.storeName,
      required this.supplierName});
  final Map<String, dynamic>? activePurchaseOrderDetails;
  final VoucherDetail? getVoucherDetails;
  final List<PurchaseItem>? getlistPurchaseItemView;
  final String? Function(int) storeName;
  final String? Function(int) supplierName;
}
