import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/screens/category/category_form_mixin.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> with CategoryFormMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _parentSearchController = TextEditingController();

  Category? _selectedParent;
  bool _isSubmitting = false;
  bool _isSellable = true;
  bool _isPurchasable = true;

  @override
  void initState() {
    super.initState();
    fetchTaxes();
    fetchLanguages();
  }

  @override
  void dispose() {
    _parentSearchController.dispose();
    disposeCategoryForm();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      showScaffoldError(
        context: context,
        message: 'general.fill_required_fields'.tr,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      /*
      // Commented out Product Property logic since the field is disabled in UI
      final propertyText = productPropertyController.text.trim();
      final int? productProperty =
          propertyText.isEmpty ? null : int.tryParse(propertyText);

      if (propertyText.isNotEmpty && productProperty == null) {
        showScaffoldError(
          context: context,
          message: 'category.product_property_number'.tr,
        );
        return;
      }
      */

      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      final Map<String, String> categoryLangNames = {};
      for (final language in languageProvider.languages) {
        final controller = languageNameControllers[language.id];
        final text = controller?.text.trim() ?? '';
        if (text.isNotEmpty) {
          categoryLangNames[language.code] = text;
        }
      }

      final response = await submitCategory(
        context: context,
        parentCategory: (_selectedParent?.categoryId ?? 0).toString(),
        categoryLangNames: categoryLangNames,
        isSellable: _isSellable,
        isPurchasable: _isPurchasable,
      );

      if (!mounted) return;

      if (response is Map<String, dynamic> && response['status'] == 'success') {
        showScaffold(
          context: context,
          message: response['message']?.toString() ??
              'general.category_added_successfully'.tr,
        );

        await categoryProvider.refreshManagementCategories();

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        showScaffoldError(
          context: context,
          message: response is Map<String, dynamic>
              ? (response['message']?.toString() ??
                  'general.failed_to_add_category'.tr)
              : 'general.failed_to_add_category'.tr,
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: '${'general.error_prefix'.tr} ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.only(left: 12, right: 12),
          height: maxLines > 1 ? null : 44,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  }
                : null,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageField(Language language, TextEditingController controller) {
    final isRtl = language.code.toLowerCase() == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'category.field_lang_name_prefix'.tr + ' (${language.name})',
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.only(left: 12, right: 12),
                height: 44,
                width: double.infinity,
                child: TextFormField(
                  controller: controller,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  cursorColor: ColorManager.kPrimaryColor,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 44,
              child: Tooltip(
                message: 'general.translate'.tr,
                child: ElevatedButton(
                  onPressed: languageTranslating[language.id] == true
                      ? null
                      : () => translateLanguage(language),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: languageTranslating[language.id] == true
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
          ],
        ),
      ],
    );
  }

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
            'category.no_taxes_available'.tr,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildParentCategoryDropdown(List<Category> parentCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'category.parent_category'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<Category>(
          title: '',
          hintText: 'category.select_parent_optional'.tr,
          value: _selectedParent,
          height: 44,
          margin: EdgeInsets.zero,
          items: parentCategories,
          onChanged: (Category? category) {
            setState(() {
              _selectedParent = category;
            });
          },
          displayText: (item) => item.categoryName ?? '',
          searchController: _parentSearchController,
        ),
      ],
    );
  }

  Widget _buildTwoColumnRow({
    required Widget left,
    required Widget right,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final parentCategories = (categoryProvider.category ?? <Category>[])
        .where((category) => category.categoryId != null)
        .toList(growable: false);

    final languageProvider = Provider.of<LanguageProvider>(context);
    final activeLanguages = languageProvider.languages;
    syncLanguageControllers(activeLanguages);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.48,
          maxHeight: size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'category.new_category'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTwoColumnRow(
                  left: _buildTextField(
                    'category.name'.tr,
                    categoryNameController,
                    isRequired: true,
                    onChanged: handleNameChanged,
                  ),
                  right: _buildTextField(
                    'category.slug'.tr,
                    categorySlugController,
                    isRequired: true,
                    readOnly: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTaxSelector(),
                const SizedBox(height: 12),
                /*
                // Commented out Product Property ID field since it's only in modal and not in main screen
                // right: _buildTextField(
                //   'Product Property ID',
                //   productPropertyController,
                //   keyboardType: TextInputType.number,
                // ),
                */
                _buildTwoColumnRow(
                  left: _buildTextField(
                    'category.description'.tr,
                    descriptionController,
                    maxLines: 2,
                  ),
                  right: _buildParentCategoryDropdown(parentCategories),
                ),
                const SizedBox(height: 12),
                ...() {
                  final List<Widget> languageFields = [];
                  for (final language in activeLanguages) {
                    if (language.code.toLowerCase() == 'en') continue;
                    if (!language.active) continue;

                    final controller = languageNameControllers[language.id]!;
                    languageFields.add(_buildLanguageField(language, controller));
                  }

                  final List<Widget> formItems = [];
                  formItems.addAll(languageFields);

                  final List<Widget> pairedRows = [];
                  for (int i = 0; i < formItems.length; i += 2) {
                    if (i + 1 < formItems.length) {
                      pairedRows.add(
                        _buildTwoColumnRow(
                          left: formItems[i],
                          right: formItems[i + 1],
                        ),
                      );
                    } else {
                      pairedRows.add(
                        _buildTwoColumnRow(
                          left: formItems[i],
                          right: const SizedBox.shrink(),
                        ),
                      );
                    }
                    if (i + 2 < formItems.length) {
                      pairedRows.add(const SizedBox(height: 12));
                    }
                  }
                  return pairedRows;
                }(),
                const SizedBox(height: 12),
                _buildTwoColumnRow(
                  left: Row(
                    children: [
                      Switch(
                        value: _isSellable,
                        onChanged: (val) => setState(() => _isSellable = val),
                        activeColor: ColorManager.kPrimaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'category.label_sellable'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  right: Row(
                    children: [
                      Switch(
                        value: _isPurchasable,
                        onChanged: (val) => setState(() => _isPurchasable = val),
                        activeColor: ColorManager.kPrimaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'category.label_purchasable'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ColorManager.kPrimaryColor,
                            elevation: 0,
                            side: BorderSide(
                              color: ColorManager.kPrimaryColor.withOpacity(0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text('category.btn_cancel'.tr),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.kPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('category.add'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// deleted duplicate class _TaxItem
