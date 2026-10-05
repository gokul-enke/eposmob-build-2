part of 'legacy_purchase_form_view.dart';

extension LegacyFormSection1 on LegacyPurchaseFormView {
  Widget _formSection1(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        SizedBox(
          height: size.height * .17,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: true,
                isTextField: true,
                title: 'add_purchase.select_category'.tr,
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
                child: DropdownButtonHideUnderline(
                  child: _dropdown1(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: size.height * .17,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BuildTextTile(
                isStarRed: true,
                isTextField: true,
                title: 'add_purchase.product_label'.tr,
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
                child: DropdownButtonHideUnderline(
                  child: _dropdown2(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
