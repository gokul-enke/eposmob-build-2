part of 'legacy_purchase_form_view.dart';

extension LegacyFormform on LegacyPurchaseFormView {
  Widget _form(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formSection1(context),
          _formSection2(context),
          _formSection3(context),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: true,
                isTextField: true,
                title: 'add_purchase.select_store'.tr,
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
                child: DropdownButtonFormField<GetStoreModelData>(
                  decoration: const InputDecoration(
                    border: InputBorder.none, // Remove the underline
                  ),
                  value: storeSelected,
                  hint: Text(
                    'add_purchase.select_store'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                  items: storeList!.map((GetStoreModelData store) {
                    return DropdownMenuItem<GetStoreModelData>(
                        value: store,
                        child: Text(
                          store.name ?? '',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.27,
                            ColorManager.textColor.withOpacity(.5),
                          ),
                        ));
                  }).toList(),
                  onChanged: (GetStoreModelData? storeModelData) {
                    if (storeModelData != null) {
                      // Update the selected category in the provider
                      controller.change(() {
                        storeSelected = storeModelData;
                        storeController.text = "${storeModelData.id ?? 1}";
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 45),
          _formSection4(context),
          const SizedBox(height: 25),
          const Divider(
            thickness: 0.5,
          ),
          BuildTextTile(
            title: 'add_purchase.purchase_items'.tr,
            textStyle: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black,
            ),
          ),
          const Divider(
            thickness: 0.5,
          ),
          BuildBoxShadowContainer(
              // height: size.height, //120,
              width: size.width,
              margin: const EdgeInsets.only(top: 20),
              circleRadius: 7,
              offsetValue: const Offset(1, 1),
              child: _table1(context)),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: CustomRoundButton(
              title: 'add_purchase.btn_finish'.tr,
              fct: () async {
                await controller.finish();
              },
              height: 50,
              width: size.width * 0.19,
              fontSize: FontSize.s12,
            ),
          ),
        ],
      ),
    );
  }
}
