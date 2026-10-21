part of '../pages/add_category_page.dart';

/// Retains form inputs, initialization, validation and submission lifecycle.
mixin CategoryAddFormState<T extends StatefulWidget>
    on State<T>, CategoryFormMixin<T> {
  final TextEditingController idController = TextEditingController(text: "0");
  final TextEditingController categoryIDController =
      TextEditingController(text: "0");

  @override
  void dispose() {
    idController.dispose();
    categoryIDController.dispose();
    disposeCategoryForm();
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
    fetchLanguages();
    fetchTaxes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false)
          .ensureCategories(CategoryListScope.all);
    });
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
        debugPrint(
            "Category request access token present: ${accessToken?.isNotEmpty == true}");

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

        submitCategory(
          context: context,
          parentCategory: idController.text,
          categoryLangNames: categoryLangNames,
          isSellable: _isSellable,
          isPurchasable: _isPurchasable,
          imagePath: imageFilePathController.text,
          iconPath: iconFilePathController.text,
        ).then((value) async {
          if (value["status"] == "success") {
            if (!context.mounted) return;
            Navigator.pop(context);

            showScaffold(
              context: context,
              message: '${value["message"]}',
            );

            await categoryProvider.refreshCategories();

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
        _categoryNameError = 'category.err_name_required'.tr;
      });
      isValid = false;
    } else {
      setState(() {
        _categoryNameError = null;
      });
    }

    if (categorySlugController.text.isEmpty) {
      setState(() {
        _categorySlugError = 'category.err_slug_required'.tr;
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
        message: 'category.err_fill_all_required'.tr,
      );
    }

    return isValid;
  }
}
