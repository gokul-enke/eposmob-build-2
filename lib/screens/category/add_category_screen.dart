import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_err_view.dart';
import 'package:pos_machine/models/product_list_file.dart';
import 'package:pos_machine/providers/grid_provider.dart';

import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../components/build_text_fields.dart';
import '../../components/build_title.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/category_list.dart';

import '../../providers/auth_model.dart';
import '../../providers/category_providers.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/category_responsive.dart';

class AddCategoryPageScreen extends StatefulWidget {
  const AddCategoryPageScreen({super.key});

  @override
  State<AddCategoryPageScreen> createState() => _AddCategoryPageScreenState();
}

class _AddCategoryPageScreenState extends State<AddCategoryPageScreen> {
  final TextEditingController categoryNameEnglishController =
      TextEditingController();
  final TextEditingController categoryNameController = TextEditingController();
  final TextEditingController categoryNameArabicController =
      TextEditingController();
  final TextEditingController categoryNameHindiController =
      TextEditingController();
  final TextEditingController categorySlugController = TextEditingController();
  final TextEditingController idController = TextEditingController(text: "0");
  final TextEditingController categoryIDController =
      TextEditingController(text: "0");

  @override
  void dispose() {
    // Dispose of the controllers when the widget is disposed
    categoryNameEnglishController.dispose();
    categoryNameController.dispose();
    categoryNameArabicController.dispose();
    categoryNameHindiController.dispose();
    categorySlugController.dispose();
    idController.dispose();
    categoryIDController.dispose();
    super.dispose();
  }

  final imageTitleController = TextEditingController();
  final imageAltController = TextEditingController();
  int? selectedImageIndex;
  final imageFilePathController = TextEditingController();
  final iconTitleController = TextEditingController();
  final iconAltController = TextEditingController();
  int? selectedIconIndex;
  final iconFilePathController = TextEditingController();
  List<GetProductListFileModelData>? imageFiles = [];
  GetProductListFileModelData? selctedImageFile;
  String? _selectedImagePath;
  String? _selectedIconPath;
  bool _isSellable = true;
  bool _isPurchasable = true;
  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Provider.of<GridSelectionProvider>(context, listen: false)
        .getProductListFilesAPI(accessToken: accessToken ?? "")
        .then((value) {
          debugPrint("IMAGE FILES RESPONSE: $value");
      if (value["status"] == "success") {
        GetProductListFileModel getProductListFileModel =
            GetProductListFileModel.fromJson(value);
        imageFiles = getProductListFileModel.data;
        debugPrint("IMAGE FILES COUNT: ${imageFiles?.length}");
      } else {}
    });
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _imageError;
  String? _iconError;
  String? _categoryNameEnglishError;
  String? _categoryNameError;
  String? _categoryNameHindiError;
  String? _categoryNameArabicError;
  String? _categorySlugError;

  bool _isMobile(BuildContext context) => categoryIsPhone(context);

  Future<void> _handleSubmit(
    BuildContext context,
    CategoryProvider categoryProvider,
    SideBarController sideBarController,
    VoidCallback clearText,
  ) async {
    idController.text = categoryProvider.getParentCategory;
    debugPrint("categoryIdController.text ${idController.text}");
    if (_validateForm(context)) {
      debugPrint("categoryIdController.text ${idController.text}");
      debugPrint(
          "categoryNameArabicController.text ${categoryNameArabicController.text}");

      if (categorySlugController.text.isEmpty ||
          categoryNameController.text.isEmpty) {
        debugPrint("isEmptycategorySlugController");
        showScaffoldError(
          context: context,
          message: 'Please Fill the Required Fields',
        );
      } else {
        debugPrint("categoryIdController ${categoryIDController.text}");
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            });

        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        debugPrint("accessToken From AuthModel $accessToken");
        categoryProvider
            .addCategory(
                categoryName: categoryNameController.text,
                slug: categorySlugController.text,
                parentCategory: idController.text,
                categoryNameEnglish: categoryNameEnglishController.text,
                categoryNameHindi: categoryNameHindiController.text,
                categoryNameArabic: categoryNameArabicController.text,
                imagePath: imageFilePathController.text,
                iconPath: iconFilePathController.text,
                accessToken: accessToken ?? "",
        isSellable: _isSellable,
        isPurchasable: _isPurchasable,
    )
            .then((value) {
          if (value["status"] == "success") {
            showScaffold(
              context: context,
              message: '${value["message"]}',
            );

            final categoryProvider =
                Provider.of<CategoryProvider>(context, listen: false);
            categoryProvider.refreshCategories();

            Navigator.pop(context);
            clearText();
            sideBarController.index.value = 12;
          } else {
            debugPrint("errors.password !=null");
            Navigator.pop(context);
            showScaffold(
              context: context,
              message: '${value["message"]}',
            );
          }
        });
      }
    }
  }

  bool _validateForm(BuildContext context) {
    bool isValid = true;

    if (_formKey.currentState != null) {
      isValid = _formKey.currentState!.validate() && isValid;
    }

    if (categoryNameController.text.isEmpty) {
      setState(() {
        _categoryNameError = "Category Name is required";
      });
      isValid = false;
    } else {
      setState(() {
        _categoryNameError = null;
      });
    }

    if (categorySlugController.text.isEmpty) {
      setState(() {
        _categorySlugError = "Category Slug is required";
      });
      isValid = false;
    } else {
      setState(() {
        _categorySlugError = null;
      });
    }

    if (!isValid) {
      showScaffoldError(
        context: context,
        message: 'Please fill all required fields',
      );
    }

    return isValid;
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
    List<Category>? categoryList = categoryProvider.category;

    void clearText() {
      categoryIDController.clear();
      categoryNameArabicController.clear();
      categoryNameController.clear();
      categoryNameEnglishController.clear();
      categoryNameHindiController.clear();
      categorySlugController.clear();
    }

    final bool isMobile = _isMobile(context);
    final double horizontalMargin = categoryHorizontalMargin(size.width);
    final double fieldGap = isMobile ? 14.0 : 20.0;

    Widget buildActionButtons(double maxWidth) {
      final double buttonWidth =
          isMobile ? maxWidth : size.width * 0.19;

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomRoundButton(
              title: "Submit",
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
              title: "Back",
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
              title: "Submit",
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
              title: "Back",
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
                    text: 'All Categories',
                  ),
                  const SizedBox(height: 12),
                  const CategoryPageHeader(
                    title: 'Add New Category',
                    subtitle:
                        'Fill in the details below to create a new product category.',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                              fieldPair(
                                first: BuildErrorText(
                                          errorText: _categoryNameError != null
                                              ? _categoryNameError!
                                              : "",
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                  start: 10.0),
                                          child:
                                              buildColumnWidgetForTextFields(
                                            onchanged: ((value) {
                                              categoryNameEnglishController
                                                  .text = value ?? '';
                                              categorySlugController.text =
                                                  categoryNameController.text
                                                      .toLowerCase()
                                                      .replaceAll(
                                                          RegExp(r'\s+'), '-')
                                                      .replaceAll(
                                                          RegExp(
                                                              r'[^a-z0-9-]'),
                                                          '');
                                            }),
                                            isLeft: false,
                                            isStarRed: true,
                                            readOnly: false,
                                            controller: categoryNameController,
                                            size: size,
                                            width: fieldWidth,
                                            title: 'Category Name',
                                            hintText: 'Category Name',
                                          ),
                                        ),
                                second: buildColumnWidgetForTextFields(
                                          onchanged: (value) {},
                                          isLeft: false,
                                          readOnly: true,
                                          controller:
                                              categoryNameEnglishController,
                                          size: size,
                                          width: fieldWidth,
                                          title: "Category Name - English (US)*",
                                          hintText: '',
                                        ),
                              ),
                              SizedBox(height: fieldGap),
                              fieldPair(
                                first: _buildParentCategoryField(
                                            categoryProvider,
                                            categoryList,
                                            fieldWidth),
                                second: buildColumnWidgetForTextFields(
                                          onchanged: (value) {},
                                          isLeft: false,
                                          readOnly: false,
                                          controller:
                                              categoryNameHindiController,
                                          size: size,
                                          width: fieldWidth,
                                          title: "Category Name - Hindi(IND)",
                                          hintText: 'Enter...',
                                        ),
                              ),
                              SizedBox(height: fieldGap),
                              fieldPair(
                                first: BuildErrorText(
                                          errorText: _categorySlugError != null
                                              ? _categorySlugError!
                                              : "",
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                  start: 10.0),
                                          child: buildColumnWidgetForTextFields(
                                            onchanged: (value) {},
                                            isLeft: false,
                                            controller: categorySlugController,
                                            size: size,
                                            width: fieldWidth,
                                            isStarRed: true,
                                            title: "Category Slug",
                                            hintText: 'Url Slug',
                                            readOnly: true,
                                          ),
                                        ),
                                second: buildColumnWidgetForTextFields(
                                          onchanged: (value) {},
                                          isLeft: false,
                                          controller:
                                              categoryNameArabicController,
                                          size: size,
                                          width: fieldWidth,
                                          title: "Category Name - Arabic(AR)",
                                          hintText: 'Enter...',
                                          readOnly: false,
                                        ),
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
                                          title: "Category Image : ",
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
                                          title: "Select Image",
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
                                          title: "Category Icon : ",
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
                                          title: "Select Icon",
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
                                        onChanged: (val) => setState(() => _isSellable = val),
                                        activeColor: ColorManager.kPrimaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sellable',
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
                                      onChanged: (val) => setState(() => _isPurchasable = val),
                                      activeColor: ColorManager.kPrimaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Purchasable',
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
          title: "Select Parent Category",
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
              'Select Category',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            items: categoryList!
                .map((Category category) {
                  return DropdownMenuItem<Category>(
                      value: category,
                      child: category.categoryName == "ALL"
                          ? Text(
                              ' New Category',
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
            onChanged: (Category? selectedCategory) {
              if (selectedCategory != null) {
                categoryProvider.selectCategory(
                  categoryList.indexOf(selectedCategory),
                  selectedCategory.categoryName ?? '',
                  selectedCategory.productsCount ?? 0,
                );
                debugPrint("onChanged ${selectedCategory.categoryId}");
                categoryIDController.text = "${selectedCategory.categoryId}";
                debugPrint(
                    "categoryIdController ${categoryIDController.text}");
                categoryProvider.setParentCategory(
                    "${selectedCategory.categoryId ?? 0}");
              }
            },
          ),
        ),
      ],
    );
  }

  showDialogFunctionForCategoryImageDetails(BuildContext context,
      final List<GetProductListFileModelData>? attachment, Size size) {
    // debugPrint("showDialogFunctionForProductDetailsAnimated");
    return showDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "",
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final isPhone = categoryIsPhone(context);
            final dialogWidth = categoryDialogWidth(context);
            final dialogHeight = categoryDialogHeight(context);
            final uploadButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.12;
            final actionButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.19;

            return Center(
              child: SizedBox(
                height: dialogHeight,
                width: dialogWidth,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 14,
                      padding: EdgeInsets.all(isPhone ? 12 : 16),
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.12)),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Select Image",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s16,
                                          0.18,
                                          ColorManager.kTitleTextColor,
                                        ),
                                      ),
                                    ),
                                    CategoryDialogCloseButton(
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: "Upload from Device",
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  imageFilePathController.text =
                                                      result.files.single.path ??
                                                          '';
                                                  _selectedImagePath =
                                                      result.files.single.path;
                                                  _imageError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          if (_selectedImagePath != null) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedImagePath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          CustomRoundButton(
                                            title: "Upload from Device",
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  imageFilePathController.text =
                                                      result.files.single.path ??
                                                          '';
                                                  _selectedImagePath =
                                                      result.files.single.path;
                                                  _imageError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(width: 16),
                                          if (_selectedImagePath != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedImagePath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              if (isPhone && attachment != null)
                                ...attachment.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final image = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: BuildBoxShadowContainer(
                                      circleRadius: 10,
                                      border: Border.all(
                                          color:
                                              Colors.grey.withOpacity(0.12)),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: selectedImageIndex,
                                            onChanged: (int? value) {
                                              setState(() {
                                                selectedImageIndex =
                                                    value ?? 0;
                                              });
                                              debugPrint(
                                                  "showDialog $index $selectedImageIndex");
                                              imageFilePathController.text =
                                                  image.id.toString();
                                              imageAltController.text =
                                                  image.alt ?? "";
                                              imageTitleController.text =
                                                  image.title ?? "";
                                            },
                                          ),
                                          Expanded(
                                            child: Text(
                                              "${image.title}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          BuildBoxShadowContainer(
                                            margin: const EdgeInsetsDirectional
                                                .only(start: 5, end: 5),
                                            circleRadius: 5,
                                            height: 48,
                                            width: 48,
                                            child: Image.network(
                                              image.s3Url ?? "",
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              if (!isPhone)
                              SizedBox(
                                width: dialogWidth,
                                child: Table(
                                  columnWidths: const {
                                    0: FractionColumnWidth(0.01),
                                    1: FractionColumnWidth(0.01),
                                    2: FractionColumnWidth(0.1),
                                    3: FractionColumnWidth(0.06),
                                    4: FractionColumnWidth(0.06),
                                    5: FractionColumnWidth(0.05),
                                  },
                                  border: const TableBorder.symmetric(
                                      outside: BorderSide(
                                          color: ColorManager.tableBOrderColor,
                                          width: 0.3),
                                      inside: BorderSide(
                                          color: ColorManager.tableBOrderColor,
                                          width: 0.8)),
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    TableRow(
                                        decoration: const BoxDecoration(
                                            color: ColorManager.tableBGColor),
                                        children: [
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Select",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Image Title",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Preview",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                        ]),

                                    // Map your order data to table rows here
                                    // ...imageFiles!.map((image) {
                                    if (attachment != null)
                                      ...attachment
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final image = entry.value;
                                        return TableRow(
                                          children: [
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child: Radio<int>(
                                                      value: index,
                                                      groupValue:
                                                          selectedImageIndex,
                                                      onChanged: (int? value) {
                                                        // Set the selected image index
                                                        setState(() {
                                                          selectedImageIndex =
                                                              value ?? 0;
                                                        });

                                                        debugPrint(
                                                            "showDialog $index $selectedImageIndex");
                                                        imageFilePathController
                                                                .text =
                                                            image.id.toString();
                                                        imageAltController
                                                                .text =
                                                            image.alt ?? "";
                                                        imageTitleController
                                                                .text =
                                                            image.title ?? "";
                                                        // Perform any other action if needed
                                                      },
                                                    ),
                                                  ),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child: Text(
                                                      "${image.title}",
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child:
                                                        BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child:
                                                                Image.network(
                                                              image.s3Url ?? "",
                                                              fit: BoxFit.cover,
                                                            )),
                                                  ),
                                                )),
                                          ],
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: "Cancel",
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(height: 10),
                                          CustomRoundButton(
                                            title: "Choose",
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: "Cancel",
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: "Choose",
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
              ),
            );
          });
        });
  }

  showDialogFunctionForCategoryIconDetails(BuildContext context,
      final List<GetProductListFileModelData>? attachment, Size size) {
    // debugPrint("showDialogFunctionForCategoryIconDetails");
    return showDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "",
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final isPhone = categoryIsPhone(context);
            final dialogWidth = categoryDialogWidth(context);
            final dialogHeight = categoryDialogHeight(context);
            final uploadButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.12;
            final actionButtonWidth =
                isPhone ? dialogWidth - 32 : size.width * 0.19;

            return Center(
              child: SizedBox(
                height: dialogHeight,
                width: dialogWidth,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 14,
                      padding: EdgeInsets.all(isPhone ? 12 : 16),
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.12)),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Select Icon",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s16,
                                          0.18,
                                          ColorManager.kTitleTextColor,
                                        ),
                                      ),
                                    ),
                                    CategoryDialogCloseButton(
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: "Upload from Device",
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  iconFilePathController.text =
                                                      result.files.single.path ??
                                                          '';
                                                  _selectedIconPath =
                                                      result.files.single.path;
                                                  _iconError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          if (_selectedIconPath != null) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedIconPath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          CustomRoundButton(
                                            title: "Upload from Device",
                                            fct: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                              );
                                              if (result != null) {
                                                this.setState(() {
                                                  iconFilePathController.text =
                                                      result.files.single.path ??
                                                          '';
                                                  _selectedIconPath =
                                                      result.files.single.path;
                                                  _iconError = null;
                                                });
                                                setState(() {});
                                              }
                                            },
                                            height: 44,
                                            width: uploadButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(width: 16),
                                          if (_selectedIconPath != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_selectedIconPath!),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              if (isPhone && attachment != null)
                                ...attachment.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final image = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: BuildBoxShadowContainer(
                                      circleRadius: 10,
                                      border: Border.all(
                                          color:
                                              Colors.grey.withOpacity(0.12)),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: selectedIconIndex,
                                            onChanged: (int? value) {
                                              setState(() {
                                                selectedIconIndex =
                                                    value ?? 0;
                                              });
                                              debugPrint(
                                                  "showDialog $index $selectedIconIndex");
                                              iconFilePathController.text =
                                                  image.id.toString();
                                              iconAltController.text =
                                                  image.alt ?? "";
                                              iconTitleController.text =
                                                  image.title ?? "";
                                            },
                                          ),
                                          Expanded(
                                            child: Text(
                                              "${image.title}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          BuildBoxShadowContainer(
                                            margin: const EdgeInsetsDirectional
                                                .only(start: 5, end: 5),
                                            circleRadius: 5,
                                            height: 48,
                                            width: 48,
                                            child: Image.network(
                                              image.s3Url ?? "",
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              if (!isPhone)
                              SizedBox(
                                width: dialogWidth,
                                child: Table(
                                  columnWidths: const {
                                    0: FractionColumnWidth(0.01),
                                    1: FractionColumnWidth(0.01),
                                    2: FractionColumnWidth(0.1),
                                    3: FractionColumnWidth(0.06),
                                    4: FractionColumnWidth(0.06),
                                    5: FractionColumnWidth(0.05),
                                  },
                                  border: const TableBorder.symmetric(
                                      outside: BorderSide(
                                          color: ColorManager.tableBOrderColor,
                                          width: 0.3),
                                      inside: BorderSide(
                                          color: ColorManager.tableBOrderColor,
                                          width: 0.8)),
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    TableRow(
                                        decoration: const BoxDecoration(
                                            color: ColorManager.tableBGColor),
                                        children: [
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Select",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Image Title",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Preview",
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.18,
                                                    ColorManager.kPrimaryColor,
                                                  ),
                                                )),
                                              )),
                                        ]),

                                    // Map your order data to table rows here
                                    // ...imageFiles!.map((image) {
                                    if (attachment != null)
                                      ...attachment
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final image = entry.value;
                                        return TableRow(
                                          children: [
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child: Radio<int>(
                                                      value: index,
                                                      groupValue:
                                                          selectedIconIndex,
                                                      onChanged: (int? value) {
                                                        // Set the selected image index
                                                        setState(() {
                                                          selectedIconIndex =
                                                              value ?? 0;
                                                        });

                                                        debugPrint(
                                                            "showDialog $index $selectedIconIndex");
                                                        iconFilePathController
                                                                .text =
                                                            image.id.toString();
                                                        iconAltController.text =
                                                            image.alt ?? "";
                                                        iconTitleController
                                                                .text =
                                                            image.title ?? "";
                                                        // Perform any other action if needed
                                                      },
                                                    ),
                                                  ),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child: Text(
                                                      "${image.title}",
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                )),
                                            TableCell(
                                                verticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      15.0),
                                                  child: Center(
                                                    child:
                                                        BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child:
                                                                Image.network(
                                                              image.s3Url ?? "",
                                                              fit: BoxFit.cover,
                                                            )),
                                                  ),
                                                )),
                                          ],
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          CustomRoundButton(
                                            title: "Cancel",
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                          const SizedBox(height: 10),
                                          CustomRoundButton(
                                            title: "Choose",
                                            boxColor: Colors.white,
                                            textColor:
                                                ColorManager.kPrimaryColor,
                                            fct: () async {
                                              Navigator.pop(context);
                                            },
                                            height: 50,
                                            width: actionButtonWidth,
                                            fontSize: FontSize.s12,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: "Cancel",
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .only(start: 10.0),
                                            child: CustomRoundButton(
                                              title: "Choose",
                                              boxColor: Colors.white,
                                              textColor:
                                                  ColorManager.kPrimaryColor,
                                              fct: () async {
                                                Navigator.pop(context);
                                              },
                                              height: 50,
                                              width: actionButtonWidth,
                                              fontSize: FontSize.s12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
              ),
            );
          });
        });
  }
}
