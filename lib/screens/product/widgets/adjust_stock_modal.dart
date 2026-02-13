import 'package:flutter/material.dart';
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
                    'Adjust Stock',
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
                    child: _buildField('Product', productController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child:
                        _buildField('Store', storeController, readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('Supplier', supplierController,
                        readOnly: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 2: Retail Price, MRP, Purchase Price
              Row(
                children: [
                  Expanded(
                    child: _buildField('Retail Price', retailPriceController),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('MRP', mrpController),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child:
                        _buildField('Purchase Price', purchasePriceController),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 3: Stock Adjust Type
              Text(
                'Stock Adjust Type',
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
                  const Text('Increase Stock'),
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
                  const Text('Decrease Stock'),
                ],
              ),
              const SizedBox(height: 20),

              // Row 4: Adjust Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Adjust Quantity',
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
                    'Reason',
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
                        hintText: 'Enter the reason',
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
                    title: "Submit",
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: () async {
                      if (adjustQtyController.text.isEmpty) {
                        showScaffoldError(
                            context: context,
                            message: "Please enter adjust quantity");
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
                          message: 'Adjusting Stock...');

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
                              message: "Stock adjusted successfully");
                          Navigator.pop(context);
                        } else {
                          showScaffoldError(
                              context: context,
                              message: "Failed to adjust stock");
                        }
                      } catch (e) {
                        hideLoadingOverlay();
                        showScaffoldError(
                            context: context,
                            message: "An error occurred: ${e.toString()}");
                      }
                    },
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s14,
                  ),
                  const SizedBox(width: 15),
                  CustomRoundButton(
                    title: "Cancel",
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
