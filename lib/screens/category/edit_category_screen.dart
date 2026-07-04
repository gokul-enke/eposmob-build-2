import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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
import '../../providers/category_list_scope.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class EditCategoryPageScreen extends StatefulWidget {
  const EditCategoryPageScreen({super.key});

  @override
  State<EditCategoryPageScreen> createState() => _EditCategoryPageScreenState();
}

class _EditCategoryPageScreenState extends State<EditCategoryPageScreen> {
  final imageTitleController = TextEditingController();
  final imageAltController = TextEditingController();
  int? selectedImageIndex;
  late TextEditingController imageFilePathController;
  final iconTitleController = TextEditingController();
  final iconAltController = TextEditingController();
  int? selectedIconIndex;
  late TextEditingController iconFilePathController;
  List<GetProductListFileModelData>? imageFiles = [];
  GetProductListFileModelData? selctedImageFile;
  String? _selectedImagePath;
  String? _selectedIconPath;
  bool _isSellable = true;
  bool _isPurchasable = true;

  void getData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Provider.of<GridSelectionProvider>(context, listen: false)
        .getProductListFilesAPI(accessToken: accessToken ?? "")
        .then((value) {
      if (value["status"] == "success") {
        GetProductListFileModel getProductListFileModel =
            GetProductListFileModel.fromJson(value);
        imageFiles = getProductListFileModel.data;
      } else {}
    });
  }

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController categoryNameEnglishController;
  late TextEditingController categoryNameController;
  late TextEditingController categoryNameArabicController;
  late TextEditingController categoryNameHindiController;
  late TextEditingController categorySlugController;
  late TextEditingController idController;
  late TextEditingController categoryIDController;
  late SideBarController sideBarController;

  @override
  void initState() {
    super.initState();

    getData();

    sideBarController = Get.put(SideBarController());
    idController = TextEditingController(text: "0");

    // Initialize controllers with default values to avoid null errors
    categoryNameEnglishController = TextEditingController();
    categoryNameController = TextEditingController();
    categoryNameArabicController = TextEditingController();
    categoryNameHindiController = TextEditingController();
    categorySlugController = TextEditingController();
    categoryIDController = TextEditingController();
    imageFilePathController = TextEditingController();
    iconFilePathController = TextEditingController();

    // Use Future.microtask to ensure widget tree is built
    Future.microtask(() {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      categoryProvider.ensureCategories(CategoryListScope.all);
      final viewCategory = categoryProvider.getViewCategory;

      // Set the initial values for the text controllers
      categoryNameEnglishController.text = viewCategory?.names?.en ?? '';
      categoryNameController.text = viewCategory?.name ?? '';
      categoryNameArabicController.text = viewCategory?.names?.ar ?? '';
      categoryNameHindiController.text = viewCategory?.names?.hi ?? '';
      categorySlugController.text = viewCategory?.name != null 
          ? viewCategory!.name!
              .toLowerCase() // Convert to lowercase
              .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
              .replaceAll(RegExp(r'[^a-z0-9-]'),
                  '') // Remove non-alphanumeric characters except hyphens
          : '';
      categoryIDController.text = viewCategory?.id?.toString() ?? '';
      imageFilePathController.text = viewCategory?.categoryImage?.toString() ?? '';
      iconFilePathController.text = viewCategory?.categoryIcon?.toString() ?? '';
      setState(() {
        _isSellable = viewCategory?.isSellable ?? true;
        _isPurchasable = viewCategory?.isPurchasable ?? true;
      });
      // selectedIconIndex = int.parse(viewCategory.categoryIcon!);
      // selectedImageIndex = int.parse(viewCategory.categoryImage!);

      if (viewCategory?.parentId != null) {
        String parentCategory = viewCategory!.parentId.toString();
        categoryProvider.setParentCategory(parentCategory);
        final categoryIndex = categoryProvider.allCategories.indexWhere(
            (category) => category.categoryId == viewCategory.parentId);
        if (categoryIndex >= 0) {
          final parent = categoryProvider.allCategories[categoryIndex];
          categoryProvider.selectCategory(
            categoryIndex,
            parent.categoryName ?? '',
            parent.productsCount ?? 0,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    categoryNameEnglishController.dispose();
    categoryNameController.dispose();
    categoryNameArabicController.dispose();
    categoryNameHindiController.dispose();
    categorySlugController.dispose();
    idController.dispose();
    categoryIDController.dispose();
    idController.clear();
    imageFilePathController.clear();
    iconFilePathController.clear();
    super.dispose();
  }

  void clearText() {
    categoryIDController.clear();
    categoryNameArabicController.clear();
    categoryNameController.clear();
    categoryNameEnglishController.clear();
    categoryNameHindiController.clear();
    categorySlugController.clear();
    idController.clear();
    imageFilePathController.clear();
    iconFilePathController.clear();
  }

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
                    text: 'All Categories',
                  ),
                  Text(
                    'Edit Category',
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
                           Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
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
                                          circleRadius: 7,
                                          alignment: Alignment.centerLeft,
                                          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                                          padding: const EdgeInsets.only(left: 15),
                                          height: 50,
                                          child: DropdownButtonFormField<Category>(
                                            decoration: const InputDecoration(border: InputBorder.none),
                                            isExpanded: true,
                                            value: categoryProvider.selectedCategoryIndex >= 0
                                                ? categoryList![categoryProvider.selectedCategoryIndex]
                                                : null,
                                            hint: Text('Select Category',
                                                style: buildCustomStyle(FontWeightManager.medium,
                                                    FontSize.s12, 0.27, ColorManager.textColor.withOpacity(.5))),
                                            items: categoryList!.map((Category category) {
                                              return DropdownMenuItem<Category>(
                                                value: category,
                                                child: Text(
                                                  category.categoryName == "ALL" ? 'New Category' : category.categoryName ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: buildCustomStyle(FontWeightManager.medium,
                                                      FontSize.s12, 0.27, ColorManager.textColor.withOpacity(.5)),
                                                ),
                                              );
                                            }).toSet().toList(),
                                            onChanged: (Category? selectedCategory) {
                                              if (selectedCategory != null) {
                                                categoryProvider.selectCategory(
                                                  categoryList.indexOf(selectedCategory),
                                                  selectedCategory.categoryName ?? '',
                                                  selectedCategory.productsCount ?? 0,
                                                );
                                                categoryIDController.text = "${selectedCategory.categoryId}";
                                                categoryProvider.setParentCategory("${selectedCategory.categoryId ?? 0}");
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildColumnWidgetForTextFields(
                                      onchanged: (value) {
                                        categoryNameEnglishController.text = value ?? '';
                                        categorySlugController.text = categoryNameController.text
                                            .toLowerCase()
                                            .replaceAll(RegExp(r'\s+'), '-')
                                            .replaceAll(RegExp(r'[^a-z0-9-]'), '');
                                      },
                                      isLeft: false,
                                      readOnly: false,
                                      controller: categoryNameController,
                                      size: size,
                                      title: 'Category Name',
                                      hintText: 'Category Name',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildColumnWidgetForTextFields(
                                      onchanged: (value) {},
                                      isLeft: false,
                                      readOnly: true,
                                      controller: categoryNameEnglishController,
                                      size: size,
                                      title: "Category Name - English (US)*",
                                      hintText: '',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: buildColumnWidgetForTextFields(
                                      onchanged: (value) {},
                                      isLeft: false,
                                      controller: categorySlugController,
                                      size: size,
                                      title: "Category Slug",
                                      hintText: 'Url Slug',
                                      readOnly: true,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildColumnWidgetForTextFields(
                                      onchanged: (value) {},
                                      isLeft: false,
                                      readOnly: false,
                                      controller: categoryNameHindiController,
                                      size: size,
                                      title: "Category Name - Hindi(IND)",
                                      hintText: 'Enter...',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildColumnWidgetForTextFields(
                                      onchanged: (value) {},
                                      isLeft: false,
                                      controller: categoryNameArabicController,
                                      size: size,
                                      title: "Category Name - Arabic(AR)",
                                      hintText: 'Enter...',
                                      readOnly: false,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Switch(
                                          value: _isSellable,
                                          onChanged: (val) => setState(() => _isSellable = val),
                                          activeColor: ColorManager.kPrimaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Sellable',
                                            style: buildCustomStyle(FontWeightManager.regular,
                                                FontSize.s14, 0.27, Colors.black.withOpacity(0.6))),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Switch(
                                          value: _isPurchasable,
                                          onChanged: (val) => setState(() => _isPurchasable = val),
                                          activeColor: ColorManager.kPrimaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Purchasable',
                                            style: buildCustomStyle(FontWeightManager.regular,
                                                FontSize.s14, 0.27, Colors.black.withOpacity(0.6))),
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
                                            const EdgeInsets.only(left: 20.0),
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
                                      title: "Submit",
                                      fct: () async {
                                        idController.text =
                                            categoryProvider.getParentCategory;
                                        debugPrint(
                                            "categoryIdController.text ${idController.text}");
                                        if (formKey.currentState!.validate()) {
                                          formKey.currentState!.save();
                                          // debugPrint("submit");
                                          debugPrint(
                                              "categoryIdController.text ${idController.text}");
                                          debugPrint(
                                              "categoryNameArabicController.text ${categoryNameArabicController.text}");

                                          if (categorySlugController
                                                  .text.isEmpty ||
                                              categoryNameController
                                                  .text.isEmpty) {
                                            debugPrint(
                                                "isEmptycategorySlugController");
                                            showScaffold(
                                              context: context,
                                              message:
                                                  'Please Fill the Required Fields',
                                            );
                                          } else {
                                            debugPrint(
                                                "categoryIdController ${categoryIDController.text}");
                                            showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator
                                                            .adaptive(),
                                                  );
                                                });

                                            String? accessToken =
                                                Provider.of<AuthModel>(context,
                                                        listen: false)
                                                    .token;
                                            debugPrint(
                                                "accessToken From AuthModel $accessToken");
                                            categoryProvider
                                                .editCategory(
                                              categoryId: categoryProvider
                                                  .getEditCategoryId,
                                              // categoryId: int.parse(
                                              //     categoryIDController.text),
                                              categoryName:
                                                  categoryNameController.text,
                                              slug: categorySlugController.text,
                                              parentCategory: idController.text,
                                              categoryNameEnglish:
                                                  categoryNameEnglishController
                                                      .text,
                                              categoryNameHindi:
                                                  categoryNameHindiController
                                                      .text,
                                              categoryNameArabic:
                                                  categoryNameArabicController
                                                      .text,
                                              imagePath:
                                                  imageFilePathController.text,
                                              iconPath:
                                                  iconFilePathController.text,
                                              accessToken: accessToken ?? "",
                                              isSellable: _isSellable,
                                              isPurchasable: _isPurchasable,
                                            )
                                                .then((value) {
                                              if (value["status"] ==
                                                  "success") {
                                                showScaffold(
                                                  context: context,
                                                  message:
                                                      '${value["message"]}',
                                                );

                                                // Refresh category cache to include updated category
                                                final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
                                                categoryProvider.refreshCategories();

                                                Navigator.pop(context);
                                                clearText();
                                                sideBarController.index.value =
                                                    12;
                                              } else {
                                                debugPrint(
                                                    "errors.password !=null");
                                                Navigator.pop(context);
                                                showScaffold(
                                                  context: context,
                                                  message:
                                                      '${value["message"]}',
                                                );
                                              }
                                            });
                                          }
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
                                      title: "Back",
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

  showDialogFunctionForCategoryImageDetails(BuildContext context,
      final List<GetProductListFileModelData>? attachment, Size size) {
    // debugPrint("showDialogFunctionForProductDetailsAnimated");
    return showDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "",
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Center(
              child: SizedBox(
                //  padding: const EdgeInsets.all(120.0),
                height: 600,
                width: 700,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      padding: const EdgeInsets.all(12),
                      //  height: 380,
                      border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.7)),
                      // width: 250, //MediaQuery.of(context).size.width * 0.7,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Select Image",
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s14,
                                        0.18,
                                        ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 15,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          BuildBoxShadowContainer(
                                            width: 15,
                                            height: 15,
                                            circleRadius: 10,
                                            color: ColorManager.kPrimaryColor,
                                            child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    CustomRoundButton(
                                      title: "Upload from Device",
                                      fct: () async {
                                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                                          type: FileType.image,
                                        );
                                        if (result != null) {
                                          this.setState(() {
                                            imageFilePathController.text = result.files.single.path ?? '';
                                            _selectedImagePath = result.files.single.path;
                                          });
                                          setState(() {});
                                        }
                                      },
                                      height: 40,
                                      width: size.width * 0.12,
                                      fontSize: FontSize.s12,
                                    ),
                                    const SizedBox(width: 16),
                                    if (_selectedImagePath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
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
                              SizedBox(
                                width: 700,
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
                                child: Row(
                                  children: [
                                    // Padding(
                                    //   padding: const EdgeInsets.only(left: 10.0),
                                    //   child: CustomRoundButton(
                                    //     title: "Create New Image",
                                    //     fct: () async {},
                                    //     height: 50,
                                    //     width: size.width * 0.19,
                                    //     fontSize: FontSize.s12,
                                    //   ),
                                    // ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 10.0),
                                      child: CustomRoundButton(
                                        title: "Cancel",
                                        boxColor: Colors.white,
                                        textColor: ColorManager.kPrimaryColor,
                                        fct: () async {
                                          Navigator.pop(context);
                                        },
                                        height: 50,
                                        width: size.width * 0.19,
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 10.0),
                                      child: CustomRoundButton(
                                        title: "Choose",
                                        boxColor: Colors.white,
                                        textColor: ColorManager.kPrimaryColor,
                                        fct: () async {
                                          Navigator.pop(context);
                                        },
                                        height: 50,
                                        width: size.width * 0.19,
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
            return Center(
              child: SizedBox(
                //  padding: const EdgeInsets.all(120.0),
                height: 600,
                width: 700,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      padding: const EdgeInsets.all(12),
                      //  height: 380,
                      border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.7)),
                      // width: 250, //MediaQuery.of(context).size.width * 0.7,
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Select Image",
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s14,
                                        0.18,
                                        ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 15,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          BuildBoxShadowContainer(
                                            width: 15,
                                            height: 15,
                                            circleRadius: 10,
                                            color: ColorManager.kPrimaryColor,
                                            child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    CustomRoundButton(
                                      title: "Upload from Device",
                                      fct: () async {
                                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                                          type: FileType.image,
                                        );
                                        if (result != null) {
                                          this.setState(() {
                                            iconFilePathController.text = result.files.single.path ?? '';
                                            _selectedIconPath = result.files.single.path;
                                          });
                                          setState(() {});
                                        }
                                      },
                                      height: 40,
                                      width: size.width * 0.12,
                                      fontSize: FontSize.s12,
                                    ),
                                    const SizedBox(width: 16),
                                    if (_selectedIconPath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
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
                              SizedBox(
                                width: 700,
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
                                child: Row(
                                  children: [
                                    // Padding(
                                    //   padding: const EdgeInsets.only(left: 10.0),
                                    //   child: CustomRoundButton(
                                    //     title: "Create New Image",
                                    //     fct: () async {},
                                    //     height: 50,
                                    //     width: size.width * 0.19,
                                    //     fontSize: FontSize.s12,
                                    //   ),
                                    // ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 10.0),
                                      child: CustomRoundButton(
                                        title: "Cancel",
                                        boxColor: Colors.white,
                                        textColor: ColorManager.kPrimaryColor,
                                        fct: () async {
                                          Navigator.pop(context);
                                        },
                                        height: 50,
                                        width: size.width * 0.19,
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 10.0),
                                      child: CustomRoundButton(
                                        title: "Choose",
                                        boxColor: Colors.white,
                                        textColor: ColorManager.kPrimaryColor,
                                        fct: () async {
                                          Navigator.pop(context);
                                        },
                                        height: 50,
                                        width: size.width * 0.19,
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
