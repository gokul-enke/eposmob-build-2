part of 'legacy_purchase_form_view.dart';

extension LegacyFormdropdown2 on LegacyPurchaseFormView {
  Widget _dropdown2(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return DropdownButton2<GetProduct>(
      isExpanded: true,
      hint: Text(
        'add_purchase.select_hint'.tr,
        style: buildCustomStyle(
          FontWeightManager.regular,
          FontSize.s14,
          0.27,
          Colors.black.withOpacity(0.6),
        ),
      ),
      items: productList!
          .map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item.productName ?? "",
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              )))
          .toList(),
      value: selectedValue,
      onChanged: (value) {
        controller.change(() {
          selectedValue = value;
          if (value != null) {
            productIDController.text = "${value.productId ?? 1}";
          }
        });
      },
      buttonStyleData: ButtonStyleData(
        height: size.height * .07,
        width: size.width / 3, //3.05,
        padding: const EdgeInsets.only(left: 14, right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          // border: Border.all(
          //   color: Colors.grey.withOpacity(0.4),
          // ),
          color: Colors.white,
        ),
        //  elevation: 1,
      ),
      dropdownStyleData: const DropdownStyleData(
        maxHeight: 300,
      ),
      menuItemStyleData: const MenuItemStyleData(
        height: 40,
      ),
      dropdownSearchData: DropdownSearchData(
        searchController: textEditingController,
        searchInnerWidgetHeight: 50,
        searchInnerWidget: Container(
          height: 50,
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 4,
            right: 8,
            left: 8,
          ),
          child: TextFormField(
            expands: true,
            maxLines: null,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
            controller: textEditingController,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.black.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
        searchMatchFn: (item, searchValue) {
          return item.value!.productName
              .toString()
              .toLowerCase()
              .contains(searchValue.toLowerCase());
        },
      ),
      //This to clear the search value when you close the menu
      onMenuStateChange: (isOpen) {
        if (!isOpen) {
          textEditingController.clear();
        }
      },
    );
  }
}
