part of 'purchase_view.dart';

extension LegacyPurchaseListSection1 on LegacyPurchaseListView {
  // Builds the header section
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'purchase.page_title'.tr,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: 'purchase.btn_create_new'.tr,
          fct: () {
            PurchaseNavigation.openLegacyCreate();
          },
          fontSize: 12,
          height: 45,
          width: 200,
        ),
      ],
    );
  }

  // Builds the search filters section
  Widget _buildSearchFilters(Size size, List<GetStoreModelData>? storeList,
      List<GetSuppliersModelData>? supplierList) {
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPurchaserNameField(size),
              _buildProductNameField(size),
              _buildStoreDropdown(size, storeList),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSupplierDropdown(size, supplierList),
              _buildDateField(size),
              _buildSearchButtons(size),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaserNameField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'purchase.filter_name'.tr,
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          buildColumnWidgetForTextFields(
            height: 45,
            width: 120,
            controller: purchaserNameController,
            size: size,
            hintText: 'purchase.hint_purchaser_name'.tr,
            onchanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildProductNameField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('purchase.filter_product'.tr,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          buildColumnWidgetForTextFields(
            height: 45,
            width: 120,
            controller: productNameController,
            size: size,
            hintText: 'purchase.hint_product_name'.tr,
            onchanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDropdown(Size size, List<GetStoreModelData>? storeList) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('purchase.filter_store'.tr,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          SizedBox(
            height: 45,
            width: 150,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              child: DropdownButtonFormField<GetStoreModelData>(
                decoration: const InputDecoration(border: InputBorder.none),
                value: storeSelected,
                hint: Text(
                  'purchase.hint_select_store'.tr,
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5)),
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
                          ColorManager.textColor.withOpacity(.5)),
                    ),
                  );
                }).toList(),
                onChanged: (GetStoreModelData? storeModelData) {
                  if (storeModelData != null) {
                    controller.change(() {
                      storeSelected = storeModelData;
                      storeController.text = "${storeModelData.id ?? 1}";
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierDropdown(
      Size size, List<GetSuppliersModelData>? supplierList) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('purchase.filter_supplier'.tr,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          SizedBox(
            height: 45,
            width: 150,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              child: DropdownButtonFormField<GetSuppliersModelData>(
                decoration: const InputDecoration(border: InputBorder.none),
                value: supplier,
                hint: Text(
                  'purchase.hint_select_supplier'.tr,
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5)),
                ),
                items: supplierList!.map((GetSuppliersModelData supplier) {
                  return DropdownMenuItem<GetSuppliersModelData>(
                    value: supplier,
                    child: Text(supplier.name ?? '',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        )),
                  );
                }).toList(),
                onChanged: (GetSuppliersModelData? suppliersModelData) {
                  controller.change(() {
                    supplier = suppliersModelData;
                    supplierIdController.text =
                        "${suppliersModelData?.id ?? 1}";
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('purchase.filter_date'.tr,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          BuildBoxShadowContainer(
            circleRadius: 7,
            height: 45,
            width: 150,
            child: Center(
              child: CalendarPickerTableCell(
                onDateSelected: (DateTime date) {
                  selectedDate = date;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the buttons for search and reset
  Widget _buildSearchButtons(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15.0, top: 35),
          child: Column(
            children: [
              CustomRoundButton(
                title: 'purchase.btn_search'.tr,
                fct: () {
                  controller.load(1);
                },
                height: 45,
                width: size.width * 0.09,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 35),
          child: Column(
            children: [
              CustomRoundButton(
                title: 'general.reset'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: resetSearch,
                height: 45,
                width: size.width * 0.09,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build the purchase list table
}
