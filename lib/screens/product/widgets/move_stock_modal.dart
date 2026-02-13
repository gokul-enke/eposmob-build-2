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
import 'package:pos_machine/models/get_store.dart';

class MoveStockModal extends StatefulWidget {
  final ListStockModelData stock;
  final List<GetStoreModelData> stores;

  const MoveStockModal({super.key, required this.stock, required this.stores});

  @override
  State<MoveStockModal> createState() => _MoveStockModalState();
}

class _MoveStockModalState extends State<MoveStockModal> {
  final TextEditingController productController = TextEditingController();
  final TextEditingController currentStoreController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();

  GetStoreModelData? selectedDestinationStore;
  String selectedUser = 'Super Admin';

  @override
  void initState() {
    super.initState();
    productController.text = widget.stock.productName ?? '';
    currentStoreController.text = widget.stock.storeName ?? '';
    supplierController.text = widget.stock.supplierName ?? '';
    retailPriceController.text = widget.stock.retailPrice ?? '';
    mrpController.text = widget.stock.mrp ?? '';
    purchasePriceController.text = widget.stock.purchaseRate ?? '';
    qtyController.text = '1';
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
                    'Move Stock',
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
                    child: _buildField('Store', currentStoreController,
                        readOnly: true),
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

              // Row 3: Destination Store
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Destination Store',
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
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    height: 45,
                    border: Border.all(
                        color: ColorManager.kPrimaryColor.withOpacity(0.5)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<GetStoreModelData>(
                        isExpanded: true,
                        hint: const Text('Select an option'),
                        value: selectedDestinationStore,
                        items: widget.stores
                            .where((s) =>
                                s.name != 'All Stores' &&
                                s.name != 'Select Store' &&
                                s.name != widget.stock.storeName)
                            .map((GetStoreModelData store) {
                          return DropdownMenuItem<GetStoreModelData>(
                            value: store,
                            child: Text(store.name ?? ''),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedDestinationStore = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Row 4: Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Quantity',
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
                      controller: qtyController,
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

              // Row 5: Created by
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created by',
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
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    height: 45,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedUser,
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Super Admin',
                            child: Text('Super Admin'),
                          ),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            selectedUser = newValue!;
                          });
                        },
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
                      if (selectedDestinationStore == null) {
                        showScaffoldError(
                            context: context,
                            message: "Please select destination store");
                        return;
                      }

                      if (qtyController.text.isEmpty) {
                        showScaffoldError(
                            context: context, message: "Please enter quantity");
                        return;
                      }

                      final stockProvider =
                          Provider.of<StockProvider>(context, listen: false);
                      final authModel =
                          Provider.of<AuthModel>(context, listen: false);

                      final destStoreId = selectedDestinationStore!.id!;
                      final qty = double.parse(qtyController.text.trim());

                      debugPrint('🚀 SUBMITTING STOCK MOVE:');
                      debugPrint('   STOCK ID: ${widget.stock.stockId}');
                      debugPrint('   DEST STORE ID: $destStoreId');
                      debugPrint(
                          '   DEST STORE NAME: ${selectedDestinationStore!.name}');
                      debugPrint('   QUANTITY: $qty');

                      showLoadingOverlay(context, message: 'Moving Stock...');

                      try {
                        final success = await stockProvider.moveStockAPI(
                          stockId: widget.stock.stockId!,
                          destStoreId: destStoreId,
                          quantity: qty,
                          accessToken: authModel.token!,
                        );

                        hideLoadingOverlay();

                        if (success) {
                          showScaffold(
                              context: context,
                              message: "Stock moved successfully");
                          Navigator.pop(context);
                        } else {
                          showScaffoldError(
                              context: context,
                              message: "Failed to move stock");
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
