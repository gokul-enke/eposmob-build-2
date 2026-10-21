part of '../../pages/add_category_page.dart';

/// Existing form rendering with its retained input and action bindings.
mixin CategoryAddFormView<T extends StatefulWidget>
    on
        State<T>,
        CategoryAddFormState<T>,
        CategoryAddMediaDialogs<T>,
        CategoryFormMixin<T> {
  bool _isMobile(BuildContext context) => categoryIsPhone(context);

  Widget _buildTaxSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'category.select_taxes'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        if (taxesLoading)
          const SizedBox(
            height: 36,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (availableTaxes.isEmpty)
          Text(
            'category.no_taxes'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.27,
              Colors.black38,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: availableTaxes.map((tax) {
              final selected = selectedTaxIds.contains(tax.id);
              return FilterChip(
                label: Text(
                  tax.name,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    selected
                        ? Colors.white
                        : ColorManager.textColor.withOpacity(0.8),
                  ),
                ),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      selectedTaxIds.add(tax.id);
                    } else {
                      selectedTaxIds.remove(tax.id);
                    }
                  });
                },
                selectedColor: ColorManager.kPrimaryColor,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: selected
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey<FormState> formKey = GlobalKey<FormState>();
    SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;

    // Access the CategoryProvider
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );

    // Access the category list
    List<Category>? categoryList = categoryProvider.allCategories;

    void clearText() {
      categoryIDController.clear();
      categoryNameArabicController.clear();
      categoryNameController.clear();
      categoryNameEnglishController.clear();
      categoryNameHindiController.clear();
      categorySlugController.clear();
      for (final controller in languageNameControllers.values) {
        if (controller != categoryNameArabicController &&
            controller != categoryNameEnglishController &&
            controller != categoryNameHindiController) {
          controller.clear();
        }
      }
    }

    final bool isMobile = _isMobile(context);
    final double horizontalMargin = categoryHorizontalMargin(size.width);
    final double fieldGap = isMobile ? 14.0 : 20.0;

    Widget buildActionButtons(double maxWidth) {
      final double buttonWidth = isMobile ? maxWidth : size.width * 0.19;

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomRoundButton(
              title: 'category.btn_submit'.tr,
              fct: () => _handleSubmit(
                context,
                categoryProvider,
                sideBarController,
                clearText,
              ),
              height: 50,
              width: double.infinity,
              fontSize: FontSize.s12,
            ),
            const SizedBox(height: 10),
            CustomRoundButton(
              title: 'category.btn_back'.tr,
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: () async {
                sideBarController.index.value = 12;
              },
              height: 50,
              width: double.infinity,
              fontSize: FontSize.s12,
            ),
          ],
        );
      }

      return Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10.0),
            child: CustomRoundButton(
              title: 'category.btn_submit'.tr,
              fct: () => _handleSubmit(
                context,
                categoryProvider,
                sideBarController,
                clearText,
              ),
              height: 50,
              width: buttonWidth,
              fontSize: FontSize.s12,
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10.0),
            child: CustomRoundButton(
              title: 'category.btn_back'.tr,
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: () async {
                sideBarController.index.value = 12;
              },
              height: 50,
              width: buttonWidth,
              fontSize: FontSize.s12,
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: horizontalMargin,
          vertical: categoryVerticalMargin(size.width),
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
                const SizedBox(height: 12),
                CategoryPageHeader(
                  title: 'category.add_title'.tr,
                  subtitle: 'category.add_subtitle'.tr,
                ),
                SizedBox(height: isMobile ? 16 : 20),
                CategoryFormCard(
                  child: Form(
                    key: formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double fieldWidth = categoryFieldWidth(
                          constraints.maxWidth,
                        );

                        Widget fieldPair({
                          required Widget first,
                          required Widget second,
                        }) {
                          if (isMobile) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                first,
                                SizedBox(height: fieldGap),
                                second,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: first),
                              SizedBox(width: fieldGap),
                              Expanded(child: second),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...() {
                              final languageProvider =
                                  Provider.of<LanguageProvider>(context);
                              final activeLanguages =
                                  languageProvider.languages;

                              syncLanguageControllers(activeLanguages);

                              final List<Widget> leftWidgets = [
                                BuildErrorText(
                                  errorText: _categoryNameError != null
                                      ? _categoryNameError!
                                      : "",
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 10.0),
                                  child: buildColumnWidgetForTextFields(
                                    onchanged: handleNameChanged,
                                    isLeft: false,
                                    isStarRed: true,
                                    readOnly: false,
                                    controller: categoryNameController,
                                    size: size,
                                    width: fieldWidth,
                                    title: 'category.col_name'.tr,
                                    hintText: 'category.col_name'.tr,
                                  ),
                                ),
                                if (categoryProvider.allCategories.isNotEmpty)
                                  _buildParentCategoryField(categoryProvider,
                                      categoryList, fieldWidth),
                                BuildErrorText(
                                  errorText: _categorySlugError != null
                                      ? _categorySlugError!
                                      : "",
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 10.0),
                                  child: buildColumnWidgetForTextFields(
                                    onchanged: (value) {},
                                    isLeft: false,
                                    controller: categorySlugController,
                                    size: size,
                                    width: fieldWidth,
                                    isStarRed: true,
                                    title: 'category.field_slug'.tr,
                                    hintText: 'category.field_slug_hint'.tr,
                                    readOnly: true,
                                  ),
                                ),
                                _buildTaxSelector(),
                              ];

                              final List<Widget> rightWidgets = [];

                              for (final language in activeLanguages) {
                                if (language.code.toLowerCase() == 'en')
                                  continue; // skip English
                                if (!language.active) continue; // skip inactive

                                final controller =
                                    languageNameControllers[language.id]!;

                                rightWidgets.add(
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: buildColumnWidgetForTextFields(
                                          onchanged: (value) {},
                                          isLeft: false,
                                          controller: controller,
                                          size: size,
                                          width: fieldWidth,
                                          title:
                                              '${'category.field_lang_name_prefix'.tr} ${language.name}(${language.code.toUpperCase()})',
                                          hintText:
                                              'category.field_lang_hint'.tr,
                                          readOnly: false,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: SizedBox(
                                          height: 44,
                                          width: 44,
                                          child: Tooltip(
                                            message:
                                                '${'category.tooltip_translate_prefix'.tr} ${language.name}',
                                            child: ElevatedButton(
                                              onPressed: languageTranslating[
                                                          language.id] ==
                                                      true
                                                  ? null
                                                  : () => translateLanguage(
                                                      language),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    ColorManager.kPrimaryColor,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(7),
                                                ),
                                              ),
                                              child: languageTranslating[
                                                          language.id] ==
                                                      true
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors.white),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.translate,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final int pairCount =
                                  leftWidgets.length > rightWidgets.length
                                      ? leftWidgets.length
                                      : rightWidgets.length;

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
                                  pairedRows.add(SizedBox(height: fieldGap));
                                }
                              }

                              return pairedRows;
                            }(),
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
                                            const EdgeInsets.only(left: 0.0),
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
                                      if (_imageError != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            _imageError!,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 20.0, left: 0.0),
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
                                      if (_iconError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8.0, left: 20),
                                          child: Text(
                                            _iconError!,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12),
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
                            SizedBox(height: fieldGap),
                            fieldPair(
                              first: Row(
                                children: [
                                  Switch(
                                    value: _isSellable,
                                    onChanged: (val) =>
                                        setState(() => _isSellable = val),
                                    activeColor: ColorManager.kPrimaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'category.label_sellable'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              second: Row(
                                children: [
                                  Switch(
                                    value: _isPurchasable,
                                    onChanged: (val) =>
                                        setState(() => _isPurchasable = val),
                                    activeColor: ColorManager.kPrimaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'category.label_purchasable'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),
                            buildActionButtons(constraints.maxWidth),
                            const SizedBox(height: 25),
                          ],
                        );
                      },
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

  Widget _buildParentCategoryField(CategoryProvider categoryProvider,
      List<Category>? categoryList, double fieldWidth) {
    return Column(
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
          circleRadius: 10,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          padding: const EdgeInsetsDirectional.only(start: 15),
          height: 45,
          width: fieldWidth,
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          child: DropdownButtonFormField<Category>(
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            isExpanded: true,
            value: categoryProvider.selectedCategoryIndex >= 0
                ? categoryList![categoryProvider.selectedCategoryIndex]
                : null,
            hint: Text(
              'category.hint_select_category'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
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
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
              ),
              ...categoryList!
                  .map((Category category) {
                    return DropdownMenuItem<Category>(
                        value: category,
                        child: category.categoryName == "ALL"
                            ? Text(
                                ' ${'category.new_category'.tr}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              )
                            : Text(
                                category.categoryName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ));
                  })
                  .toSet()
                  .toList(),
            ],
            onChanged: (Category? selectedCategory) {
              if (selectedCategory != null) {
                categoryProvider.selectCategory(
                  categoryList.indexOf(selectedCategory),
                  selectedCategory.categoryName ?? '',
                  selectedCategory.productsCount ?? 0,
                );
                debugPrint("onChanged ${selectedCategory.categoryId}");
                categoryIDController.text = "${selectedCategory.categoryId}";
                debugPrint("categoryIdController ${categoryIDController.text}");
                categoryProvider
                    .setParentCategory("${selectedCategory.categoryId ?? 0}");
              } else {
                categoryProvider.selectCategory(-1, '', 0);
                categoryIDController.text = "0";
                categoryProvider.setParentCategory("0");
              }
            },
          ),
        ),
      ],
    );
  }
}
