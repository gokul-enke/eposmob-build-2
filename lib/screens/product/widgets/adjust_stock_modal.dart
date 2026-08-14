import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';

class AdjustStockModal extends StatefulWidget {
  final ListStockModelData stock;

  const AdjustStockModal({super.key, required this.stock});

  @override
  State<AdjustStockModal> createState() => _AdjustStockModalState();
}

class _AdjustStockModalState extends State<AdjustStockModal> {
  final TextEditingController productController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController adjustQtyController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  String adjustType = 'Increase Stock';

  @override
  void initState() {
    super.initState();
    productController.text = widget.stock.productName ?? '';
    storeController.text = widget.stock.storeName ?? '';
    supplierController.text = widget.stock.supplierName ?? '';
    retailPriceController.text = widget.stock.retailPrice ?? '';
    mrpController.text = widget.stock.mrp ?? '';
    purchasePriceController.text = widget.stock.purchaseRate ?? '';
    adjustQtyController.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    final canShowPurchasePrice = canViewPurchasePrice(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'stock.adjust_stock'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 1: Product, Store, Supplier
              Row(
                children: [
                  Expanded(
                    child: _buildField('stock.col_product'.tr, productController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('stock.label_store'.tr, storeController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('stock.supplier'.tr, supplierController,
                        readOnly: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 2: Retail Price, MRP, Purchase Price
              Row(
                children: [
                  Expanded(
                    child: _buildField('stock.retail_price'.tr, retailPriceController),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('stock.mrp'.tr, mrpController),
                  ),
                  if (canShowPurchasePrice) ...[
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildField(
                          'stock.purchase_price'.tr, purchasePriceController),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Row 3: Stock Adjust Type
              Text(
                'stock.adjust_type_label'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.27,
                  Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Radio<String>(
                    value: 'Increase Stock',
                    groupValue: adjustType,
                    activeColor: ColorManager.kPrimaryColor,
                    onChanged: (value) {
                      setState(() {
                        adjustType = value!;
                      });
                    },
                  ),
                  Text('stock.adjust_increase'.tr),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'Decrease Stock',
                    groupValue: adjustType,
                    activeColor: ColorManager.kPrimaryColor,
                    onChanged: (value) {
                      setState(() {
                        adjustType = value!;
                      });
                    },
                  ),
                  Text('stock.adjust_decrease'.tr),
                ],
              ),
              const SizedBox(height: 20),

              // Row 4: Adjust Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'stock.adjust_qty_label'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s14,
                        0.27,
                        Colors.black,
                      ),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    height: 45,
                    child: TextField(
                      controller: adjustQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 5: Reason
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'stock.adjust_reason_label'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.27,
                      Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.all(15),
                    height: 100,
                    child: TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'stock.adjust_reason_hint'.tr,
                        hintStyle: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Row 6: Submit and Cancel Buttons
              Row(
                children: [
                  CustomRoundButton(
                    title: 'stock.btn_submit'.tr,
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: () async {
                      if (adjustQtyController.text.isEmpty) {
                        showScaffoldError(
                            context: context,
                            message: 'stock.adjust_err_qty_required'.tr);
                        return;
                      }

                      final stockProvider =
                          Provider.of<StockProvider>(context, listen: false);
                      final authModel =
                          Provider.of<AuthModel>(context, listen: false);

                      final type = adjustType == 'Increase Stock'
                          ? 'increase'
                          : 'decrease';
                      final qty = double.parse(adjustQtyController.text.trim());
                      final reason = reasonController.text.trim();

                      debugPrint('🚀 SUBMITTING STOCK ADJUSTMENT:');
                      debugPrint('   STOCK ID: ${widget.stock.stockId}');
                      debugPrint('   TYPE: $type');
                      debugPrint('   QUANTITY: $qty');
                      debugPrint('   REASON: $reason');

                      showLoadingOverlay(context,
                          message: 'stock.adjust_loading'.tr);

                      try {
                        final success = await stockProvider.adjustStockAPI(
                          stockId: widget.stock.stockId!,
                          type: type,
                          quantity: qty,
                          reason: reason,
                          accessToken: authModel.token!,
                        );

                        hideLoadingOverlay();

                        if (success) {
                          showScaffold(
                              context: context,
                              message: 'stock.adjust_success'.tr);
                          Navigator.pop(context);
                        } else {
                          showScaffoldError(
                              context: context,
                              message: 'stock.adjust_err_failed'.tr);
                        }
                      } catch (e) {
                        hideLoadingOverlay();
                        showScaffoldError(
                            context: context,
                            message: '${'stock.err_occurred'.tr}${e.toString()}');
                      }
                    },
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s14,
                  ),
                  const SizedBox(width: 15),
                  CustomRoundButton(
                    title: 'stock.btn_cancel'.tr,
                    boxColor: Colors.white,
                    textColor: Colors.black,
                    borderColor: Colors.grey.withOpacity(0.5),
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.27,
            Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          height: 45,
          color: readOnly ? Colors.grey[50] : Colors.white,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.27,
              readOnly ? Colors.grey[600]! : Colors.black,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
