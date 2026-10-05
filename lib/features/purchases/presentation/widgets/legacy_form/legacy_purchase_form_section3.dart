part of 'legacy_purchase_form_view.dart';

extension LegacyFormSection3 on LegacyPurchaseFormView {
  Widget _formSection3(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              isStarRed: false,
              isTextField: true,
              title: 'add_purchase.batch_number'.tr,
              textStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              height: size.height * .07,
              width: size.width / 3,
              child: TextFormField(
                key: ValueKey<int>(batchNumber),
                initialValue: batchNumber.toString(),
                //readOnly: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'add_purchase.field_required'.tr;
                  }
                  return null;
                },
                cursorColor: ColorManager.kPrimaryColor,
                decoration: InputDecoration(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          debugPrint("quantity $batchNumber");
                          controller.change(() {
                            batchNumber++;
                          });
                        },
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          size: 20,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          debugPrint("quantity $batchNumber");

                          controller.change(() {
                            batchNumber--;
                          });
                        },
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                        ),
                      )
                    ],
                  ),
                  border: InputBorder.none,
                  //   hintText: 'Quantity',
                  hintStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                // controller: TextEditingController(
                //     text: '$quantity'),
                onChanged: (value) {
                  controller.change(() {
                    batchNumber = int.tryParse(value) ?? batchNumber;
                  });
                },
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
            ),
          ],
        ),
        // BuildDropDownStatic(
        //   selectedItem: selectedSupplier,
        //   size: size,
        //   isLeft: true,
        //   isStarRed: true,
        //   isStar: true,
        //   items: supplier,
        //   hintText: 'Select Supplier',
        //   title: 'Supplier',
        //   onChanged: (String? newValue) {
        //     selectedSupplier = newValue!;
        //   },
        // ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              isStarRed: true,
              isTextField: true,
              title: 'add_purchase.select_supplier'.tr,
              textStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.only(left: 15),
              height: size.height * .07,
              width: size.width / 3,
              child: DropdownButtonFormField<GetSuppliersModelData>(
                decoration: const InputDecoration(
                  border: InputBorder.none, // Remove the underline
                ),
                value: supplier,
                hint: Text(
                  'add_purchase.select_supplier'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: supplierList!.map((GetSuppliersModelData supplier) {
                  return DropdownMenuItem<GetSuppliersModelData>(
                      value: supplier,
                      child: Text(
                        supplier.name ?? '',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ));
                }).toList(),
                onChanged: (GetSuppliersModelData? suppliersModelData) {
                  if (suppliersModelData != null) {
                    // Update the selected category in the provider
                    controller.change(() {
                      supplier = suppliersModelData;
                      supplierIdController.text =
                          "${suppliersModelData.id ?? 1}";
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
