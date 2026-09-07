import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/app_url.dart';

class CategoryTaxItem {
  final int id;
  final String name;
  const CategoryTaxItem({required this.id, required this.name});
}

mixin CategoryFormMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController categoryNameController = TextEditingController();
  final TextEditingController categoryNameEnglishController =
      TextEditingController();
  final TextEditingController categoryNameArabicController =
      TextEditingController();
  final TextEditingController categoryNameHindiController =
      TextEditingController();
  final TextEditingController categorySlugController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController productPropertyController =
      TextEditingController();

  final Map<int, bool> languageTranslating = {};
  final Map<int, TextEditingController> languageNameControllers = {};
  bool languagesRequested = false;

  // Tax selection state
  List<CategoryTaxItem> availableTaxes = [];
  final List<int> selectedTaxIds = [];
  bool taxesLoading = false;

  Future<void> fetchTaxes() async {
    if (!mounted) return;
    setState(() => taxesLoading = true);
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token ?? '';
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key') ?? '';

      if (token.isEmpty || apiKey.isEmpty) {
        return;
      }

      final response = await http.get(
        Uri.parse('${APPUrl.listTax}?active_only=true'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Tenant': apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final rawData = decoded['data'];
        final list = (rawData as List? ?? []);
        setState(() {
          availableTaxes = list
              .map((e) => CategoryTaxItem(
                    id: (e['id'] as num).toInt(),
                    name: e['name']?.toString() ?? '',
                  ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[TaxFetch] Exception: $e');
    } finally {
      if (mounted) {
        setState(() => taxesLoading = false);
      }
    }
  }

  Future<void> fetchLanguages() async {
    if (languagesRequested) return;
    languagesRequested = true;

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    await languageProvider.fetchLanguages(accessToken: accessToken);
  }

  void syncLanguageControllers(List<Language> languages) {
    for (final language in languages) {
      if (!languageNameControllers.containsKey(language.id)) {
        if (language.code.toLowerCase() == 'ar') {
          languageNameControllers[language.id] = categoryNameArabicController;
        } else if (language.code.toLowerCase() == 'hi') {
          languageNameControllers[language.id] = categoryNameHindiController;
        } else if (language.code.toLowerCase() == 'en') {
          languageNameControllers[language.id] = categoryNameEnglishController;
        } else {
          languageNameControllers[language.id] = TextEditingController();
        }
      }
      languageTranslating.putIfAbsent(language.id, () => false);
    }
  }

  Future<void> translateLanguage(Language language) async {
    final baseText = categoryNameController.text.trim();
    if (baseText.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'category.enter_name_before_translating'.tr,
      );
      return;
    }

    if (languageTranslating[language.id] == true) return;

    setState(() {
      languageTranslating[language.id] = true;
    });

    try {
      final accessToken =
          Provider.of<AuthModel>(context, listen: false).token ?? '';
      if (accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'general.auth_token_missing'.tr,
        );
        return;
      }

      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      final translated = await languageProvider.translateText(
        accessToken: accessToken,
        targetLang: language.code,
        text: baseText,
      );

      if (!mounted) return;

      if (translated != null && translated.isNotEmpty) {
        languageNameControllers[language.id]?.text = translated;
        showScaffold(
          context: context,
          message: 'category.translated_to'.trParams(
            {'language': language.name},
          ),
        );
      } else {
        showScaffoldError(
          context: context,
          message: 'category.translation_failed'.tr,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'category.translation_failed'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          languageTranslating[language.id] = false;
        });
      }
    }
  }

  void handleNameChanged(String? value) {
    categoryNameEnglishController.text = value ?? '';
    categorySlugController.text = categoryNameController.text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
  }

  void disposeCategoryForm() {
    categoryNameController.dispose();
    categoryNameEnglishController.dispose();
    categoryNameArabicController.dispose();
    categoryNameHindiController.dispose();
    categorySlugController.dispose();
    descriptionController.dispose();
    productPropertyController.dispose();
    for (final controller in languageNameControllers.values) {
      if (controller != categoryNameArabicController &&
          controller != categoryNameEnglishController &&
          controller != categoryNameHindiController) {
        controller.dispose();
      }
    }
  }

  Future<dynamic> submitCategory({
    required BuildContext context,
    required String parentCategory,
    required Map<String, String> categoryLangNames,
    bool isSellable = true,
    bool isPurchasable = true,
    String? imagePath,
    String? iconPath,
  }) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';

    final propertyText = productPropertyController.text.trim();
    final int? productProperty =
        propertyText.isEmpty ? null : int.tryParse(propertyText);

    return await categoryProvider.addCategory(
      categoryName: categoryNameController.text.trim(),
      slug: categorySlugController.text.trim(),
      parentCategory: parentCategory,
      categoryNameEnglish: categoryNameEnglishController.text.trim(),
      categoryNameHindi: categoryNameHindiController.text.trim(),
      categoryNameArabic: categoryNameArabicController.text.trim(),
      imagePath: imagePath ?? '',
      iconPath: iconPath ?? '',
      accessToken: accessToken,
      isSellable: isSellable,
      isPurchasable: isPurchasable,
      categoryLangNames: categoryLangNames,
      description: descriptionController.text.trim(),
      productPropertyIds:
          productProperty != null ? <int>[productProperty] : null,
      taxIds: selectedTaxIds.isEmpty ? null : List<int>.from(selectedTaxIds),
    );
  }
}
