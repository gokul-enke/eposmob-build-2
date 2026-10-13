part of '../pages/edit_category_page.dart';

/// Retains form inputs, initialization, validation and submission lifecycle.
mixin CategoryEditFormState<T extends StatefulWidget> on State<T> {
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
  bool _languagesRequested = false;

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

  Future<void> _fetchLanguages() async {
    if (_languagesRequested) return;
    _languagesRequested = true;

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    await languageProvider.fetchLanguages(accessToken: accessToken);
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
    _fetchLanguages();

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
      imageFilePathController.text =
          viewCategory?.categoryImage?.toString() ?? '';
      iconFilePathController.text =
          viewCategory?.categoryIcon?.toString() ?? '';
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

  Future<void> _handleSubmit(
      BuildContext context, CategoryProvider categoryProvider) async {
    idController.text = categoryProvider.getParentCategory;
    debugPrint("categoryIdController.text ${idController.text}");
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      // debugPrint("submit");
      debugPrint("categoryIdController.text ${idController.text}");
      debugPrint(
          "categoryNameArabicController.text ${categoryNameArabicController.text}");

      if (categorySlugController.text.isEmpty ||
          categoryNameController.text.isEmpty) {
        debugPrint("isEmptycategorySlugController");
        showScaffold(
          context: context,
          message: 'category.err_fill_required'.tr,
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
            .editCategory(
          categoryId: categoryProvider.getEditCategoryId,
          // categoryId: int.parse(
          //     categoryIDController.text),
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

            // Refresh category cache to include updated category
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
}
