part of 'legacy_purchase_form_view.dart';

extension LegacyFormSection4 on LegacyPurchaseFormView {
  Widget _formSection4(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: CustomRoundButton(
            title: 'add_purchase.btn_add'.tr,
            fct: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                await controller.submitItem();
              }
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: CustomRoundButton(
            title: 'add_purchase.btn_back'.tr,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: () async {
              onBack();
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
        ),
      ],
    );
  }
}
