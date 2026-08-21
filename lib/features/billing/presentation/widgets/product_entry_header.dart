import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:pos_machine/widgets/product_autocomplete_list_mobile.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:websafe_svg/websafe_svg.dart';

class ProductEntryHeader extends StatelessWidget {
  final Size size;
  final TextEditingController barcodeController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController selectedProductIdController;
  final GridSelectionProvider productProvider;
  final GlobalKey autocompleteProductKey;
  final void Function(String) onProcessBarcode;
  final VoidCallback onClearProductFields;
  final VoidCallback focusTextField;

  const ProductEntryHeader({
    super.key,
    required this.size,
    required this.barcodeController,
    required this.quantityController,
    required this.unitPriceController,
    required this.selectedProductIdController,
    required this.productProvider,
    required this.autocompleteProductKey,
    required this.onProcessBarcode,
    required this.onClearProductFields,
    required this.focusTextField,
  });

  @override
  Widget build(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    return Consumer<AppSettingsProvider>(
        builder: (context, appSettingsProvider, child) {
      if (appSettingsProvider.appSettings == null) {
        return const SizedBox.shrink();
      }
      final bool isMobileLayout = size.width < 700;
      final double containerHeight =
          isMobileLayout ? size.height * 0.18 : size.height * 0.10;
      return SizedBox(
        height: containerHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: isMobileLayout
                  ? Column(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            listTileTheme: const ListTileThemeData(
                              tileColor: Colors.transparent,
                              selectedTileColor: Colors.transparent,
                              textColor: Colors.black87,
                              iconColor: Colors.black54,
                            ),
                            expansionTileTheme: const ExpansionTileThemeData(
                              backgroundColor: Colors.transparent,
                              collapsedBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.transparent)),
                              collapsedShape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.transparent)),
                              tilePadding: EdgeInsets.zero,
                            ),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 8),
                            backgroundColor: Colors.transparent,
                            collapsedBackgroundColor: Colors.transparent,
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(color: Colors.transparent),
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              side: BorderSide(color: Colors.transparent),
                            ),
                            title: Row(
                              children: [
                                appSettingsProvider.appSettings!.barcodeSales
                                    ? Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0),
                                          child: buildColumnWidgetForTextFields(
                                            autofocus: appSettingsProvider
                                                .appSettings!.barcodeSales,
                                            controller: barcodeController,
                                            focusNode:
                                                billingProvider.barcodeNode,
                                            keyboardType: TextInputType.number,
                                            readOnly: billingProvider
                                                .selectedProductNameController
                                                .text
                                                .isNotEmpty,
                                            onSubmitted: (query) {
                                              if (query != null &&
                                                  query.isNotEmpty) {
                                                onProcessBarcode(query);
                                              }
                                            },
                                            size: size,
                                            hintText: 'billing.barcode_hint'.tr,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                appSettingsProvider.appSettings!.barcodeSales &&
                                        billingProvider
                                            .selectedProductNameController
                                            .text
                                            .isNotEmpty
                                    ? Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0),
                                          child: buildColumnWidgetForTextFields(
                                            readOnly: true,
                                            controller: billingProvider
                                                .selectedProductNameController,
                                            onchanged: (query) {},
                                            size: size,
                                            hintText:
                                                'billing.product_name_hint'.tr,
                                          ),
                                        ),
                                      )
                                    : Expanded(
                                        flex: 4,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            MobileProductAutocomplete(
                                              autocompleteProductKey:
                                                  autocompleteProductKey,
                                              autofocus: !appSettingsProvider
                                                  .appSettings!.barcodeSales,
                                              size: size,
                                              onSelected: (GetProduct
                                                      selectedProduct,
                                                  Stock? selectedStock) async {
                                                double defaultPrice = 0.0;
                                                if (selectedStock != null) {
                                                  defaultPrice =
                                                      double.tryParse(
                                                              selectedStock
                                                                      .price ??
                                                                  "0") ??
                                                          0.0;
                                                } else {
                                                  defaultPrice =
                                                      double.tryParse(
                                                              selectedProduct
                                                                      .price
                                                                      ?.price ??
                                                                  "0") ??
                                                          0.0;
                                                }

                                                selectedProductIdController
                                                        .text =
                                                    selectedProduct.productId
                                                        .toString();
                                                unitPriceController.text =
                                                    defaultPrice.toString();
                                                quantityController.text = '1';
                                                billingProvider
                                                    .selectedProductNameController
                                                    .text = selectedProduct
                                                        .productName ??
                                                    '';
                                                barcodeController.text =
                                                    selectedProduct.barcode ??
                                                        '';
                                              },
                                              productList:
                                                  productProvider.productList!,
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(width: 6),
                                // + (add) icon button
                                SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: ElevatedButton(
                                    onPressed: billingProvider.isLoadingAddItem
                                        ? null
                                        : () async {
                                            billingProvider
                                                .setLoadingAddItem(true);
                                            try {
                                              final localProductProvider =
                                                  Provider.of<
                                                          LocalProductProvider>(
                                                      context,
                                                      listen: false);

                                              final selectedProduct =
                                                  localProductProvider
                                                      .selectedProduct;

                                              if (selectedProduct != null) {
                                                final customPrice =
                                                    double.tryParse(
                                                        unitPriceController
                                                            .text);
                                                final customQuantity =
                                                    num.tryParse(
                                                        quantityController
                                                            .text);

                                                await ProductCartHelper
                                                    .handleProductSelection(
                                                  context: context,
                                                  product: selectedProduct,
                                                  quantity: customQuantity,
                                                  customPrice:
                                                      customPrice != null &&
                                                              customPrice > 0
                                                          ? customPrice
                                                          : null,
                                                );

                                                onClearProductFields();
                                                focusTextField();
                                              } else {
                                                showScaffoldError(
                                                  context: context,
                                                  message:
                                                      "billing.no_product_selected"
                                                          .tr,
                                                );
                                              }
                                            } catch (_) {
                                              showScaffoldError(
                                                context: context,
                                                message:
                                                    "billing.failed_add_item"
                                                        .tr,
                                              );
                                            } finally {
                                              billingProvider
                                                  .setLoadingAddItem(false);
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor:
                                          ColorManager.kButtonGreen,
                                      shape: const CircleBorder(),
                                      elevation: 0,
                                    ),
                                    child: billingProvider.isLoadingAddItem
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.add,
                                            color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // x (clear) icon button
                                SizedBox(
                                  height: 36,
                                  width: 36,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      onClearProductFields();
                                      Provider.of<LocalProductProvider>(context,
                                              listen: false)
                                          .resetSelectedProduct();
                                      focusTextField();
                                      showScaffold(
                                        context: context,
                                        message: 'billing.product_cleared'.tr,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: const CircleBorder(),
                                      side: BorderSide(
                                          color: Colors.red.shade300),
                                      backgroundColor: Colors.red.shade50,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: ColorManager.kButtonRed,
                                        size: 16),
                                  ),
                                ),
                              ],
                            ),
                            // Expanded content: Quantity & Unit Price
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: buildColumnWidgetForTextFields(
                                        controller: quantityController,
                                        onchanged: (query) {},
                                        size: size,
                                        hintText: 'billing.quantity_hint'.tr,
                                        focusNode:
                                            billingProvider.quantityFocusNode,
                                        keyboardType: TextInputType.number,
                                        onTap: () {
                                          Provider.of<KeyboardProvider>(context,
                                                  listen: false)
                                              .show(
                                            'number',
                                            quantityController,
                                            replaceOnFirstInput: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: buildColumnWidgetForTextFields(
                                        controller: unitPriceController,
                                        onchanged: (query) {},
                                        size: size,
                                        focusNode:
                                            billingProvider.unitPriceFocusNode,
                                        hintText: 'billing.unit_price_hint'.tr,
                                        keyboardType: TextInputType.number,
                                        onTap: () {
                                          Provider.of<KeyboardProvider>(context,
                                                  listen: false)
                                              .show(
                                            'number',
                                            unitPriceController,
                                            replaceOnFirstInput: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        appSettingsProvider.appSettings!.barcodeSales
                            ? Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: buildColumnWidgetForTextFields(
                                    autofocus: appSettingsProvider
                                        .appSettings!.barcodeSales,
                                    controller: barcodeController,
                                    focusNode: billingProvider.barcodeNode,
                                    keyboardType: TextInputType.number,
                                    readOnly: billingProvider
                                        .selectedProductNameController
                                        .text
                                        .isNotEmpty,
                                    onSubmitted: (query) {
                                      if (query != null && query.isNotEmpty) {
                                        onProcessBarcode(query);
                                      }
                                    },
                                    size: size,
                                    hintText: 'billing.barcode_hint'.tr,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        appSettingsProvider.appSettings!.barcodeSales &&
                                billingProvider.selectedProductNameController
                                    .text.isNotEmpty
                            ? Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: buildColumnWidgetForTextFields(
                                    readOnly: true,
                                    controller: billingProvider
                                        .selectedProductNameController,
                                    onchanged: (query) {},
                                    size: size,
                                    hintText: 'billing.product_name_hint'.tr,
                                  ),
                                ),
                              )
                            : Expanded(
                                flex: 4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ProductAutocomplete(
                                      autocompleteProductKey:
                                          autocompleteProductKey,
                                      autofocus: !appSettingsProvider
                                          .appSettings!.barcodeSales,
                                      size: size,
                                      onSelected: (GetProduct selectedProduct,
                                          Stock? selectedStock) async {
                                        double defaultPrice = 0.0;
                                        if (selectedStock != null) {
                                          defaultPrice = double.tryParse(
                                                  selectedStock.price ?? "0") ??
                                              0.0;
                                        } else {
                                          defaultPrice = double.tryParse(
                                                  selectedProduct
                                                          .price?.price ??
                                                      "0") ??
                                              0.0;
                                        }

                                        selectedProductIdController.text =
                                            selectedProduct.productId
                                                .toString();
                                        unitPriceController.text =
                                            defaultPrice.toString();
                                        quantityController.text = '1';
                                        billingProvider
                                                .selectedProductNameController
                                                .text =
                                            selectedProduct.productName ?? '';
                                        barcodeController.text =
                                            selectedProduct.barcode ?? '';
                                      },
                                      productList: productProvider.productList!,
                                    ),
                                  ],
                                ),
                              ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              controller: quantityController,
                              onchanged: (query) {},
                              size: size,
                              hintText: 'billing.quantity_hint'.tr,
                              focusNode: billingProvider.quantityFocusNode,
                              keyboardType: TextInputType.number,
                              onTap: () {
                                Provider.of<KeyboardProvider>(context,
                                        listen: false)
                                    .show(
                                  'number',
                                  quantityController,
                                  replaceOnFirstInput: true,
                                );
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              controller: unitPriceController,
                              onchanged: (query) {},
                              size: size,
                              focusNode: billingProvider.unitPriceFocusNode,
                              hintText: 'billing.unit_price_hint'.tr,
                              keyboardType: TextInputType.number,
                              onTap: () {
                                Provider.of<KeyboardProvider>(context,
                                        listen: false)
                                    .show(
                                  'number',
                                  unitPriceController,
                                  replaceOnFirstInput: true,
                                );
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Center(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomRoundButton(
                                    title: 'billing.add_item'.tr,
                                    boxColor: ColorManager.kButtonGreen,
                                    borderColor: ColorManager.kButtonGreen,
                                    isLoading: billingProvider.isLoadingAddItem,
                                    fct: () async {
                                      billingProvider.setLoadingAddItem(true);
                                      try {
                                        final localProductProvider =
                                            Provider.of<LocalProductProvider>(
                                                context,
                                                listen: false);

                                        final selectedProduct =
                                            localProductProvider
                                                .selectedProduct;

                                        if (selectedProduct != null) {
                                          final customPrice = double.tryParse(
                                              unitPriceController.text);
                                          final customQuantity = num.tryParse(
                                              quantityController.text);

                                          await ProductCartHelper
                                              .handleProductSelection(
                                            context: context,
                                            product: selectedProduct,
                                            quantity: customQuantity,
                                            customPrice: customPrice != null &&
                                                    customPrice > 0
                                                ? customPrice
                                                : null,
                                          );

                                          onClearProductFields();
                                          focusTextField();
                                        } else {
                                          showScaffoldError(
                                            context: context,
                                            message:
                                                "billing.no_product_selected"
                                                    .tr,
                                          );
                                        }
                                      } catch (_) {
                                        showScaffoldError(
                                          context: context,
                                          message: "billing.failed_add_item".tr,
                                        );
                                      } finally {
                                        billingProvider
                                            .setLoadingAddItem(false);
                                      }
                                    },
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
                                  onTap: () {
                                    onClearProductFields();
                                    Provider.of<LocalProductProvider>(context,
                                            listen: false)
                                        .resetSelectedProduct();
                                    focusTextField();
                                    showScaffold(
                                      context: context,
                                      message: 'billing.product_cleared'.tr,
                                    );
                                  },
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Center(
                                          child: WebsafeSvg.asset(
                                            ImageAssets.oderlistCloseIcon,
                                            width: 27,
                                            colorFilter: const ColorFilter.mode(
                                                ColorManager.kButtonRed,
                                                BlendMode.srcIn),
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
    });
  }
}
