part of '../../pages/edit_category_page.dart';

/// Existing form rendering with its retained input and action bindings.
mixin CategoryEditFormView<T extends StatefulWidget>
    on State<T>, CategoryEditFormState<T>, CategoryEditMediaDialogs<T> {
  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categoryList = categoryProvider.allCategories;
    final size = MediaQuery.of(context).size;
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: horizontalMargin,
          vertical: isMobile ? 10 : 20,
        ),
        padding: EdgeInsets.all(isMobile ? 4 : 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            color: Colors.white),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 12.0 : 20.0,
            horizontal: isMobile ? 12.0 : 10.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBackButton(
                  onPressed: () {
                    sideBarController.index.value = 12;
                  },
                  text: 'category.all_categories'.tr,
                ),
                Text(
                  'category.edit_title'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.kTitleTextColor),
                ),
                const SizedBox(height: 20),
                BuildBoxShadowContainer(
                  circleRadius: 14,
                  blurRadius: 10,
                  offsetValue: const Offset(0, 3),
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...() {
                          final languageProvider =
                              Provider.of<LanguageProvider>(context);
                          final activeLanguages = languageProvider.languages;

                          final bool showHindi = activeLanguages.isNotEmpty &&
                              activeLanguages.any((lang) =>
                                  lang.code.toLowerCase() == 'hi' &&
                                  lang.active);
                          final bool showArabic = activeLanguages.isNotEmpty &&
                              activeLanguages.any((lang) =>
                                  lang.code.toLowerCase() == 'ar' &&
                                  lang.active);

                          final List<Widget> leftWidgets = [
                            if (categoryProvider.allCategories.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    isStarRed: false,
                                    isTextField: true,
                                    title: 'category.select_parent'.tr,
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: 50,
                                    child: DropdownButtonFormField<Category>(
                                      decoration: const InputDecoration(
                                          border: InputBorder.none),
                                      isExpanded: true,
                                      value: categoryProvider
                                                  .selectedCategoryIndex >=
                                              0
                                          ? categoryList![categoryProvider
                                              .selectedCategoryIndex]
                                          : null,
                                      hint: Text(
                                          'category.hint_select_category'.tr,
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5))),
                                      items: [
                                        DropdownMenuItem<Category>(
                                          value: null,
                                          child: Text(
                                            'category.none'.tr,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5)),
                                          ),
                                        ),
                                        ...categoryList
                                            .map((Category category) {
                                              return DropdownMenuItem<Category>(
                                                value: category,
                                                child: Text(
                                                  category.categoryName == "ALL"
                                                      ? 'category.new_category'
                                                          .tr
                                                      : category.categoryName ??
                                                          '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.27,
                                                      ColorManager.textColor
                                                          .withOpacity(.5)),
                                                ),
                                              );
                                            })
                                            .toSet()
                                            .toList(),
                                      ],
                                      onChanged: (Category? selectedCategory) {
                                        if (selectedCategory != null) {
                                          categoryProvider.selectCategory(
                                            categoryList
                                                .indexOf(selectedCategory),
                                            selectedCategory.categoryName ?? '',
                                            selectedCategory.productsCount ?? 0,
                                          );
                                          categoryIDController.text =
                                              "${selectedCategory.categoryId}";
                                          categoryProvider.setParentCategory(
                                              "${selectedCategory.categoryId ?? 0}");
                                        } else {
                                          categoryProvider.selectCategory(
                                              -1, '', 0);
                                          categoryIDController.text = "0";
                                          categoryProvider
                                              .setParentCategory("0");
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            buildColumnWidgetForTextFields(
                              onchanged: (value) {
                                categoryNameEnglishController.text =
                                    value ?? '';
                                categorySlugController.text =
                                    categoryNameController.text
                                        .toLowerCase()
                                        .replaceAll(RegExp(r'\s+'), '-')
                                        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
                              },
                              isLeft: false,
                              readOnly: false,
                              controller: categoryNameController,
                              size: size,
                              title: 'category.col_name'.tr,
                              hintText: 'category.col_name'.tr,
                            ),
                            buildColumnWidgetForTextFields(
                              onchanged: (value) {},
                              isLeft: false,
                              controller: categorySlugController,
                              size: size,
                              title: 'category.field_slug'.tr,
                              hintText: 'category.field_slug_hint'.tr,
                              readOnly: true,
                            ),
                          ];

                          final List<Widget> rightWidgets = [];
                          if (showHindi) {
                            rightWidgets.add(
                              buildColumnWidgetForTextFields(
                                onchanged: (value) {},
                                isLeft: false,
                                readOnly: false,
                                controller: categoryNameHindiController,
                                size: size,
                                title: 'category.field_name_hindi'.tr,
                                hintText: 'category.field_lang_hint'.tr,
                              ),
                            );
                          }
                          if (showArabic) {
                            rightWidgets.add(
                              buildColumnWidgetForTextFields(
                                onchanged: (value) {},
                                isLeft: false,
                                controller: categoryNameArabicController,
                                size: size,
                                title: 'category.field_name_arabic'.tr,
                                hintText: 'category.field_lang_hint'.tr,
                                readOnly: false,
                              ),
                            );
                          }

                          final int pairCount =
                              leftWidgets.length > rightWidgets.length
                                  ? leftWidgets.length
                                  : rightWidgets.length;

                          Widget fieldPair({
                            required Widget first,
                            required Widget second,
                          }) {
                            if (isMobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  first,
                                  const SizedBox(height: 16),
                                  second,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: first),
                                const SizedBox(width: 16),
                                Expanded(child: second),
                              ],
                            );
                          }

                          final List<Widget> pairedRows = [];
                          for (int i = 0; i < pairCount; i++) {
                            final Widget left = i < leftWidgets.length
                                ? leftWidgets[i]
                                : const SizedBox.shrink();
                            final Widget right = i < rightWidgets.length
                                ? rightWidgets[i]
                                : const SizedBox.shrink();
                            pairedRows.add(
                              fieldPair(first: left, second: right),
                            );
                            if (i < pairCount - 1) {
                              pairedRows.add(const SizedBox(height: 16));
                            }
                          }

                          return pairedRows;
                        }(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Switch(
                                    value: _isSellable,
                                    onChanged: (val) =>
                                        setState(() => _isSellable = val),
                                    activeColor: ColorManager.kPrimaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('category.label_sellable'.tr,
                                      style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Switch(
                                    value: _isPurchasable,
                                    onChanged: (val) =>
                                        setState(() => _isPurchasable = val),
                                    activeColor: ColorManager.kPrimaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('category.label_purchasable'.tr,
                                      style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6))),
                                ],
                              ),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),

                        /*
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: size.width / 3,
                                        child: BuildTextTile(
                                          title: 'category.category_image'.tr,
                                          textStyle: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s14,
                                            0.27,
                                            Colors.black.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 20.0),
                                        child: CustomRoundButton(
                                          title: 'general.select_image'.tr,
                                          fct: () async {
                                            showDialogFunctionForCategoryImageDetails(
                                                context,
                                                imageFiles ?? [],
                                                size);
                                          },
                                          height: 40,
                                          width: size.width * 0.1,
                                          fontSize: FontSize.s12,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 20.0, left: 20.0),
                                        child: BuildBoxShadowContainer(
                                            margin: const EdgeInsets.only(
                                                left: 5, right: 5),
                                            circleRadius: 5,
                                            height: 100,
                                            width: 150,
                                            child: imageFilePathController.text.startsWith('http')
                                                ? Image.network(
                                                    imageFilePathController.text,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                                  )
                                                : imageFilePathController.text.isNotEmpty
                                                    ? Image.file(
                                                        File(imageFilePathController.text),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : const Icon(Icons.image_outlined, color: Colors.grey)),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.only(left: 10),
                                        width: size.width / 3,
                                        child: BuildTextTile(
                                          title: 'category.category_icon'.tr,
                                          textStyle: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s14,
                                            0.27,
                                            Colors.black.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 20.0),
                                        child: CustomRoundButton(
                                          title: 'general.select_icon'.tr,
                                          fct: () async {
                                            showDialogFunctionForCategoryIconDetails(
                                                context,
                                                imageFiles ?? [],
                                                size);
                                          },
                                          height: 40,
                                          width: size.width * 0.1,
                                          fontSize: FontSize.s12,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: BuildBoxShadowContainer(
                                            margin: const EdgeInsets.only(
                                                left: 5, right: 5),
                                            circleRadius: 5,
                                            height: 100,
                                            width: 150,
                                            child: iconFilePathController.text.startsWith('http')
                                                ? Image.network(
                                                    iconFilePathController.text,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                                  )
                                                : iconFilePathController.text.isNotEmpty
                                                    ? Image.file(
                                                        File(iconFilePathController.text),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : const Icon(Icons.image_outlined, color: Colors.grey)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              */
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: CustomRoundButton(
                                title: 'category.btn_submit'.tr,
                                fct: () =>
                                    _handleSubmit(context, categoryProvider),
                                height: 50,
                                width: size.width * 0.19,
                                fontSize: FontSize.s12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: CustomRoundButton(
                                title: 'category.btn_back'.tr,
                                boxColor: Colors.white,
                                textColor: ColorManager.kPrimaryColor,
                                fct: () async {
                                  sideBarController.index.value = 12;
                                },
                                height: 50,
                                width: size.width * 0.19,
                                fontSize: FontSize.s12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
