part of 'legacy_purchase_form_view.dart';

extension LegacyFormdropdown1 on LegacyPurchaseFormView {
  Widget _dropdown1(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return DropdownButton2<Category>(
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
      items: categoryList!
          .map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item.categoryName ?? "",
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              )))
          .toList(),
      value: selectedValueCategory,
      onChanged: (Category? selectedCategory) async {
        if (selectedCategory == null) return;
        final products = await selectCategory(
            selectedCategory, categoryList!.indexOf(selectedCategory));
        controller.change(() {
          controller.productList = products;
          selectedValueCategory = selectedCategory;
          categoryIDController.text = '${selectedCategory.categoryId ?? 1}';
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
          return item.value!.categoryName
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
