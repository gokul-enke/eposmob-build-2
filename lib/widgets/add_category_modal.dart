import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _productPropertyController =
      TextEditingController();
  final TextEditingController _arabicNameController = TextEditingController();
  final TextEditingController _parentSearchController = TextEditingController();

  Category? _selectedParent;
  String? _imagePath;
  String? _iconPath;
  bool _isSubmitting = false;
  bool _isArabicTranslating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _productPropertyController.dispose();
    _arabicNameController.dispose();
    _parentSearchController.dispose();
    super.dispose();
  }

  String _fileNameFromPath(String path) {
    if (path.isEmpty) return '';
    return path.split(Platform.pathSeparator).last;
  }

  Future<void> _pickImage({required bool isIcon}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Unable to read selected file path.',
      );
      return;
    }

    setState(() {
      if (isIcon) {
        _iconPath = selectedPath;
      } else {
        _imagePath = selectedPath;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      showScaffoldError(
        context: context,
        message: 'Please fill required fields.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      final accessToken = authModel.token ?? '';
      if (accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Authentication token missing. Please login again.',
        );
        return;
      }

      final propertyText = _productPropertyController.text.trim();
      final int? productProperty =
          propertyText.isEmpty ? null : int.tryParse(propertyText);

      if (propertyText.isNotEmpty && productProperty == null) {
        showScaffoldError(
          context: context,
          message: 'Product Property must be a number.',
        );
        return;
      }

      final response = await categoryProvider.addCategory(
        categoryName: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        parentCategory: (_selectedParent?.categoryId ?? 0).toString(),
        categoryNameEnglish: _nameController.text.trim(),
        categoryNameHindi: '',
        categoryNameArabic: _arabicNameController.text.trim(),
        imagePath: _imagePath ?? '',
        iconPath: _iconPath ?? '',
        accessToken: accessToken,
        description: _descriptionController.text.trim(),
        productPropertyIds:
            productProperty != null ? <int>[productProperty] : null,
      );

      if (!mounted) return;

      if (response is Map<String, dynamic> && response['status'] == 'success') {
        showScaffold(
          context: context,
          message: response['message']?.toString() ?? 'Category added successfully',
        );

        await categoryProvider.refreshManagementCategories();

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        showScaffoldError(
          context: context,
          message: response is Map<String, dynamic>
              ? (response['message']?.toString() ?? 'Failed to add category')
              : 'Failed to add category',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error adding category: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _translateArabicName() async {
    final baseText = _nameController.text.trim();
    if (baseText.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please enter Category Name before translating.',
      );
      return;
    }

    if (_isArabicTranslating) return;

    setState(() {
      _isArabicTranslating = true;
    });

    try {
      final accessToken = Provider.of<AuthModel>(context, listen: false).token ?? '';
      if (accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Authentication token missing. Please login again.',
        );
        return;
      }

      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      final translated = await languageProvider.translateText(
        accessToken: accessToken,
        targetLang: 'ar',
        text: baseText,
      );

      if (!mounted) return;

      if (translated != null && translated.isNotEmpty) {
        _arabicNameController.text = translated;
        showScaffold(
          context: context,
          message: 'Translated to Arabic',
        );
      } else {
        showScaffoldError(
          context: context,
          message: 'Translation failed. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Translation failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isArabicTranslating = false;
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

  Widget _buildFilePicker({required bool isIcon}) {
    final String? path = isIcon ? _iconPath : _imagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isIcon ? 'Icon' : 'Image',
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 44,
                child: Text(
                  path == null || path.isEmpty
                      ? 'No file selected'
                      : _fileNameFromPath(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
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
                onPressed: () => _pickImage(isIcon: isIcon),
                child: const Text('Choose File'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArabicNameFieldWithTranslate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Name (Arabic)',
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
                  controller: _arabicNameController,
                  textDirection: TextDirection.rtl,
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
                message: 'Translate',
                child: ElevatedButton(
                  onPressed: _isArabicTranslating ? null : _translateArabicName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: _isArabicTranslating
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

  Widget _buildParentCategoryDropdown(List<Category> parentCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parent Category',
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
          hintText: 'Select Parent Category (optional)',
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
                      'Create New Category',
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
                    'Name',
                    _nameController,
                    isRequired: true,
                  ),
                  right: _buildTextField(
                    'Slug',
                    _slugController,
                    isRequired: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTwoColumnRow(
                  left: _buildTextField(
                    'Description',
                    _descriptionController,
                    maxLines: 2,
                  ),
                  right: _buildTextField(
                    'Product Property ID',
                    _productPropertyController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTwoColumnRow(
                  left: _buildArabicNameFieldWithTranslate(),
                  right: _buildParentCategoryDropdown(parentCategories),
                ),
                const SizedBox(height: 12),
                _buildTwoColumnRow(
                  left: _buildFilePicker(isIcon: false),
                  right: _buildFilePicker(isIcon: true),
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
                          child: const Text('Cancel'),
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
                              : const Text('Create Category'),
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
