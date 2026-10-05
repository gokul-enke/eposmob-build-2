part of 'legacy_purchase_form_view.dart';

extension LegacyFormSection2 on LegacyPurchaseFormView {
  Widget _formSection2(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              isStarRed: true,
              isTextField: true,
              title: 'add_purchase.quantity_label'.tr,
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
                key: ValueKey<int>(quantity),
                initialValue: quantity.toString(),
                // readOnly: true,
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
                          debugPrint("quantity $quantity");
                          controller.change(() {
                            quantity++;
                          });
                        },
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          size: 20,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          debugPrint("quantity $quantity");

                          if (quantity > 0) {
                            controller.change(() {
                              quantity--;
                            });
                          }
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
                    quantity = int.tryParse(value) ?? quantity;
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
        //   selectedItem: selectedProperty,
        //   size: size,
        //   isLeft: true,
        //   isStarRed: true,
        //   isStar: true,
        //   items: property,
        //   hintText: 'Choose Unit',
        //   title: 'Unit',
        //   onChanged: (String? newValue) {
        //     selectedProperty = newValue!;
        //   },
        // ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildTextTile(
              isStarRed: true,
              isTextField: true,
              title: 'add_purchase.unit_label'.tr,
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
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: InputBorder.none, // Remove the underline
                ),
                value: selectedProperty,
                hint: Text(
                  'add_purchase.choose_unit'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
                items: unitList!.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key, // Set the value for the dropdown item
                    child: Text(
                      entry.value,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ), // Display the value as the dropdown item
                  );
                }).toList(),
                onChanged: (String? value) {
                  selectedProperty = value;
                  debugPrint("selected Unit $selectedProperty");
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
