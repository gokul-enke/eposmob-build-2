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

class WithdrawStockModal extends StatefulWidget {
  final ListStockModelData stock;

  const WithdrawStockModal({super.key, required this.stock});

  @override
  State<WithdrawStockModal> createState() => _WithdrawStockModalState();
}

class _WithdrawStockModalState extends State<WithdrawStockModal> {
  final TextEditingController productController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController withdrawQtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    productController.text = widget.stock.productName ?? '';
    storeController.text = widget.stock.storeName ?? '';
    supplierController.text = widget.stock.supplierName ?? '';
    retailPriceController.text = widget.stock.retailPrice ?? '';
    mrpController.text = widget.stock.mrp ?? '';
    purchasePriceController.text = widget.stock.purchaseRate ?? '';
    withdrawQtyController.text = '1';
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
                    'Withdraw Stock',
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
                    child: _buildField('Retail Price', retailPriceController,
                        readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField('MRP', mrpController, readOnly: true),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField(
                        'Purchase Price', purchasePriceController,
                        readOnly: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 3: Available Stock and Withdraw Quantity
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Stock',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.27,
                            Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.stock.qty} ${widget.stock.unit ?? ""}',
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s14,
                            0.27,
                            Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: 'Withdraw Quantity',
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
                          border: Border.all(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.5)),
                          child: TextField(
                            controller: withdrawQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter the quantity to withdraw from stock',
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.27,
                            Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Row 4: Submit and Cancel Buttons
              Row(
                children: [
                  CustomRoundButton(
                    title: "Submit",
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: () async {
                      if (withdrawQtyController.text.isEmpty) {
                        showScaffoldError(
                            context: context,
                            message: "Please enter withdraw quantity");
                        return;
                      }

                      final stockProvider =
                          Provider.of<StockProvider>(context, listen: false);
                      final authModel =
                          Provider.of<AuthModel>(context, listen: false);

                      final qty =
                          double.parse(withdrawQtyController.text.trim());

                      debugPrint('🚀 SUBMITTING STOCK WITHDRAWAL:');
                      debugPrint('   STOCK ID: ${widget.stock.stockId}');
                      debugPrint('   QUANTITY: $qty');

                      showLoadingOverlay(context,
                          message: 'Withdrawing Stock...');

                      try {
                        final success = await stockProvider.withdrawStockAPI(
                          stockId: widget.stock.stockId!,
                          quantity: qty,
                          accessToken: authModel.token!,
                        );

                        hideLoadingOverlay();

                        if (success) {
                          showScaffold(
                              context: context,
                              message: "Stock withdrawn successfully");
                          Navigator.pop(context);
                        } else {
                          showScaffoldError(
                              context: context,
                              message: "Failed to withdraw stock");
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
