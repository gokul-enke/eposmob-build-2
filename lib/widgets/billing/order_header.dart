import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class OrderHeader extends StatelessWidget {
  final Size size;
  final TextEditingController barcodeController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController selectedProductIdController;
  final TextEditingController selectedProductNameController;
  final GlobalKey autocompleteProductKey;
  final FocusNode barcodeNode;
  final Function(String?) onBarcodeChanged;
  final VoidCallback onAddItem;
  final VoidCallback onClearProductDetails;
  final bool isLoadingAddItem;

  const OrderHeader({
    Key? key,
    required this.size,
    required this.barcodeController,
    required this.quantityController,
    required this.unitPriceController,
    required this.selectedProductIdController,
    required this.selectedProductNameController,
    required this.autocompleteProductKey,
    required this.barcodeNode,
    required this.onBarcodeChanged,
    required this.onAddItem,
    required this.onClearProductDetails,
    required this.isLoadingAddItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        if (appSettingsProvider.appSettings == null) {
          return Container();
        }
        return SizedBox(
          height: size.height * 0.10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  children: [
                    appSettingsProvider.appSettings!.barcodeSales
                        ? Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: buildColumnWidgetForTextFields(
                                autofocus: appSettingsProvider
                                    .appSettings!.barcodeSales,
                                controller: barcodeController,
                                focusNode: barcodeNode,
                                readOnly: selectedProductNameController
                                    .text.isNotEmpty,
                                onchanged: onBarcodeChanged,
                                size: size,
                                hintText: 'Barcode',
                              ),
                            ),
                          )
                        : Container(),
                    appSettingsProvider.appSettings!.barcodeSales &&
                            selectedProductNameController.text.isNotEmpty
                        ? Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: buildColumnWidgetForTextFields(
                                readOnly: true,
                                controller: selectedProductNameController,
                                onchanged: (query) {},
                                size: size,
                                hintText: 'Quantity',
                              ),
                            ),
                          )
                        : Expanded(
                            flex: 4,
                            child: ProductAutocomplete(
                              autocompleteProductKey: autocompleteProductKey,
                              autofocus: !appSettingsProvider
                                  .appSettings!.barcodeSales,
                              size: size,
                              onSelected: (selectedProduct, selectedStock) {
                                selectedProductIdController.text =
                                    selectedProduct.productId.toString();
                                unitPriceController.text =
                                    selectedProduct.price?.price ?? '';
                                quantityController.text = '1';
                                selectedProductNameController.text =
                                    selectedProduct.productName ?? '';
                                barcodeController.text =
                                    selectedProduct.barcode ?? '';
                              },
                              productList: productProvider.productList!,
                            ),
                          ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: buildColumnWidgetForTextFields(
                          controller: quantityController,
                          onchanged: (query) {},
                          size: size,
                          hintText: 'Quantity',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            if (unitPriceController.text == 'KG' ||
                                unitPriceController.text == 'LT')
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}$')),
                            if (unitPriceController.text != 'LT' &&
                                unitPriceController.text != 'KG')
                              FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: buildColumnWidgetForTextFields(
                          controller: unitPriceController,
                          onchanged: (query) {},
                          size: size,
                          hintText: 'Unit Price',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomRoundButton(
                                title: "Add Item",
                                boxColor: ColorManager.kButtonGreen,
                                borderColor: ColorManager.kButtonGreen,
                                isLoading: isLoadingAddItem,
                                fct: onAddItem,
                                fontSize: FontSize.s14,
                                height: size.height * .07,
                                width: size.width / 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          BuildBoxShadowContainer(
                            height: size.height * .07,
                            width: 50,
                            circleRadius: 5,
                            child: InkWell(
                              onTap: onClearProductDetails,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Center(
                                      child: WebsafeSvg.asset(
                                        ImageAssets.oderlistCloseIcon,
                                        width: 27,
                                        color: ColorManager.kButtonRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
