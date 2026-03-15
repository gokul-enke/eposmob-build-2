import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class EditStockDialogResult {
  final String retailPrice;
  final String mrp;
  final String purchasePrice;
  final String quantity;
  final String rack;

  const EditStockDialogResult({
    required this.retailPrice,
    required this.mrp,
    required this.purchasePrice,
    required this.quantity,
    required this.rack,
  });
}

Future<bool> showEditStockDialog({
  required BuildContext context,
  required int stockId,
  required String title,
  required String initialRetailPrice,
  required String initialMrp,
  required String initialPurchasePrice,
  required String initialQuantity,
  required String initialRack,
  Future<void> Function(EditStockDialogResult result)? onSuccess,
}) async {
  final parentContext = context;
  final retailPriceController = TextEditingController(text: initialRetailPrice);
  final mrpController = TextEditingController(text: initialMrp);
  final purchasePriceController =
      TextEditingController(text: initialPurchasePrice);
  final quantityController = TextEditingController(text: initialQuantity);
  final rackController = TextEditingController(text: initialRack);

  Map<String, String> rackMap = {};
  String? selectedRackId;
  bool rackLoading = true;
  bool isSubmitting = false;
  bool initialized = false;

  Future<void> loadRacks(StateSetter setDialogState) async {
    final purchaseProvider =
        Provider.of<PurchaseProvider>(parentContext, listen: false);
    final accessToken = Provider.of<AuthModel>(parentContext, listen: false).token;

    if (accessToken != null && accessToken.isNotEmpty) {
      await purchaseProvider.listMasterDataValues(accessToken, 'RACKS');
    }

    rackMap = Map<String, String>.from(
      purchaseProvider.getMasterDataValues ?? <String, String>{},
    );

    if (initialRack.trim().isNotEmpty && rackMap.isNotEmpty) {
      final match = rackMap.entries.where((entry) {
        return entry.key == initialRack ||
            entry.value.toLowerCase() == initialRack.toLowerCase();
      }).toList();

      if (match.isNotEmpty) {
        selectedRackId = match.first.key;
        rackController.text = match.first.value;
      }
    }

    if (parentContext.mounted) {
      setDialogState(() {
        rackLoading = false;
      });
    }
  }

  final bool result = await showDialog<bool>(
        context: parentContext,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (statefulContext, setDialogState) {
              if (!initialized) {
                initialized = true;
                loadRacks(setDialogState);
              }

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                backgroundColor: Colors.white,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(parentContext).size.width * 0.7,
                    maxHeight: MediaQuery.of(parentContext).size.height * 0.7,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s20,
                              0.20,
                              Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isSubmitting) const LinearProgressIndicator(),
                      if (isSubmitting) const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildEditableField(
                                      'Retail Price',
                                      retailPriceController,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildEditableField(
                                      'MRP',
                                      mrpController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildEditableField(
                                      'Purchase Price',
                                      purchasePriceController,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildEditableField(
                                      'Quantity',
                                      quantityController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rack',
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s14,
                                      0.20,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (rackLoading)
                                    const SizedBox(
                                      height: 45,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else if (rackMap.isEmpty)
                                    _buildEditableField('Rack', rackController)
                                  else
                                    BuildBoxShadowContainer(
                                      circleRadius: 7,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      height: 45,
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedRackId,
                                          isExpanded: true,
                                          hint: const Text('Select Rack'),
                                          items: rackMap.entries
                                              .map(
                                                (entry) =>
                                                    DropdownMenuItem<String>(
                                                  value: entry.key,
                                                  child: Text(entry.value),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: isSubmitting
                                              ? null
                                              : (newValue) {
                                                  if (newValue == null) return;
                                                  setDialogState(() {
                                                    selectedRackId = newValue;
                                                    rackController.text =
                                                        rackMap[newValue] ??
                                                            newValue;
                                                  });
                                                },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CustomRoundButton(
                            title: 'Cancel',
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            borderColor: ColorManager.kPrimaryColor,
                            fct: isSubmitting
                                ? () {}
                                : () => Navigator.pop(dialogContext, false),
                            height: 45,
                            width: 120,
                            fontSize: FontSize.s12,
                          ),
                          const SizedBox(width: 12),
                          CustomRoundButton(
                            title: 'Update',
                            boxColor: ColorManager.kPrimaryColor,
                            textColor: Colors.white,
                            isLoading: isSubmitting,
                            fct: () async {
                              if (isSubmitting) return;

                              debugPrint(
                                  '🛠️ [EditStockDialog] Update tapped for stockId=$stockId');

                              final accessToken =
                                  Provider.of<AuthModel>(parentContext,
                                          listen: false)
                                      .token;
                              if (accessToken == null || accessToken.isEmpty) {
                                showScaffoldError(
                                  context: parentContext,
                                  message: 'Authentication token is missing',
                                );
                                return;
                              }

                              setDialogState(() {
                                isSubmitting = true;
                              });

                              final payloadRack = (selectedRackId != null &&
                                      selectedRackId!.trim().isNotEmpty)
                                  ? selectedRackId!.trim()
                                  : rackController.text.trim();
                                final quantityInput =
                                  quantityController.text.trim();
                                final initialQuantityNormalized =
                                  initialQuantity.trim();
                                final String? payloadQuantity =
                                  (quantityInput.isEmpty ||
                                      quantityInput ==
                                        initialQuantityNormalized)
                                    ? null
                                    : quantityInput;

                              debugPrint(
                                  '🛠️ [EditStockDialog] Payload summary: retail=${retailPriceController.text.trim()}, mrp=${mrpController.text.trim()}, purchase=${purchasePriceController.text.trim()}, qtyIncluded=${payloadQuantity != null}, qtyValue=${payloadQuantity ?? "<omitted>"}, rack=$payloadRack');

                              final bool success =
                                  await Provider.of<StockProvider>(
                                parentContext,
                                listen: false,
                              ).updateStockDetails(
                                stockId: stockId,
                                retailPrice: retailPriceController.text.trim(),
                                mrp: mrpController.text.trim(),
                                purchasePrice:
                                    purchasePriceController.text.trim(),
                                quantity: payloadQuantity,
                                rack: payloadRack,
                                accessToken: accessToken,
                              );

                              if (!parentContext.mounted) return;

                              if (success) {
                                final localProductProvider =
                                    Provider.of<LocalProductProvider>(
                                  parentContext,
                                  listen: false,
                                );

                                debugPrint(
                                    '🔄 [EditStockDialog] Stock update succeeded. Refreshing products with refresh=true...');
                                await localProductProvider.fetchProductsFromAPI(
                                  refresh: true,
                                );
                                debugPrint(
                                    '✅ [EditStockDialog] Product refresh completed after stock update for stockId=$stockId');

                                GetProduct? refreshedProduct;
                                Stock? refreshedStock;

                                for (final product
                                    in localProductProvider.products) {
                                  final stocks = product.stock;
                                  if (stocks == null || stocks.isEmpty) {
                                    continue;
                                  }
                                  for (final stock in stocks) {
                                    if (stock.id == stockId) {
                                      refreshedProduct = product;
                                      refreshedStock = stock;
                                      break;
                                    }
                                  }
                                  if (refreshedStock != null) {
                                    break;
                                  }
                                }

                                final double reconciledPrice =
                                    double.tryParse(
                                          refreshedStock?.price ??
                                              retailPriceController.text.trim(),
                                        ) ??
                                        0.0;
                                final double reconciledMrp =
                                    double.tryParse(
                                          refreshedStock?.mrp ??
                                              mrpController.text.trim(),
                                        ) ??
                                        0.0;

                                debugPrint(
                                    '🧩 [EditStockDialog] Reconcile source: productFound=${refreshedProduct != null}, stockFound=${refreshedStock != null}, price=$reconciledPrice, mrp=$reconciledMrp');

                                localProductProvider
                                    .updateStockPricingInCartByStockId(
                                  stockId: stockId,
                                  newPrice: reconciledPrice,
                                  newMrp: reconciledMrp,
                                  updatedProduct: refreshedProduct,
                                  updatedStock: refreshedStock,
                                );

                                debugPrint(
                                    '🛒 [EditStockDialog] Cart/saved-order stock reconciliation requested for stockId=$stockId');

                                if (onSuccess != null) {
                                  await onSuccess(
                                    EditStockDialogResult(
                                      retailPrice:
                                          retailPriceController.text.trim(),
                                      mrp: mrpController.text.trim(),
                                      purchasePrice:
                                          purchasePriceController.text.trim(),
                                      quantity: quantityController.text.trim(),
                                      rack: rackController.text.trim(),
                                    ),
                                  );
                                }

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }

                                showScaffold(
                                  context: parentContext,
                                  message: 'Stock updated successfully',
                                );
                                debugPrint(
                                    '🏁 [EditStockDialog] Stock update flow completed for stockId=$stockId');
                                return;
                              }

                              debugPrint(
                                  '❌ [EditStockDialog] Stock update failed for stockId=$stockId');

                              showScaffoldError(
                                context: parentContext,
                                message: 'Failed to update stock',
                              );

                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                              }
                            },
                            height: 45,
                            width: 120,
                            fontSize: FontSize.s12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ) ??
      false;

  retailPriceController.dispose();
  mrpController.dispose();
  purchasePriceController.dispose();
  quantityController.dispose();
  rackController.dispose();

  return result;
}

Widget _buildEditableField(String label, TextEditingController controller) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.20,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          height: 45,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    ),
  );
}
