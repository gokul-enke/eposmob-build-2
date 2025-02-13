import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/view_category.dart';

import '../resources/app_url.dart';

class CategoryProvider extends ChangeNotifier {
  bool isLoading = false;
  List<Category>? categoryList = [];
  List<Category>? searchCategoryList = [];
  List<Category>? filteredcategoryList = [];
  List<Category>? categoryListWithoutQuery = [];
  String categoryText = '';
  ViewCategory? viewCategory;
  String parentCategory = '0';
  int editCategoryId = 0;
  int propCategory = 0;
  int currentPage = 1;
  int totalPages = 1;

  CategoryProvider() {
    listAllCategory();
  }

  ViewCategory? get getViewCategory => viewCategory;
  String get getCategoryText => categoryText;
  int categoryCount = 0;
  String get getParentCategory => parentCategory;
  int get getEditCategoryId => editCategoryId;
  int get getPropCategoryId => propCategory;
  int get getCount => categoryCount;
  List<dynamic>? propValues;
  List? get categoryProperties => propValues;

  setCategoryItemCount(int value) {
    categoryCount = value;
    notifyListeners();
  }

  void resetPropValues() {
    propValues = null;
    notifyListeners();
  }

  setParentCategory(String value) {
    parentCategory = value;
    notifyListeners();
  }

  setCategoryIdforProp({required int categoryId}) {
    // debugPrintdebugPrint("SET CATEGORY ID FOR PROP $categoryId");
    propCategory = categoryId;
    notifyListeners();
  }

  setEditCategoryId({required int categoryId}) {
    editCategoryId = categoryId;
    notifyListeners();
  }

  int _selectedCategoryIndex = 0;

  int get selectedCategoryIndex => _selectedCategoryIndex;

  List<Category>? get category => categoryList;
  List<Category>? get searchCategory => searchCategoryList;
  List<Category>? get filteredcategory => filteredcategoryList!
      .where((category) => category.categoryId != 0)
      .toList();

  Category categoryDemo = Category(
    categoryId: 0,
    categorySlug: "ALL",
    categoryName: "ALL",
    productsCount: 0,
    categoryIcon: "https://via.placeholder.com/95",
    categoryImage: "https://via.placeholder.com/95",
  );
  int categoryId = 0;
  int get getCategoryId => categoryId;

  // List<int> selectedIndices = [];

  // CategoryProvider() {
  //   listAllCategory();
  // }
  //          *********************** LIST ALL CATEGORY  API ***************************************************

  Future<void> listAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterParent != null && filterParent.isNotEmpty) {
      queryParameters['filter_parent'] = filterParent;
    }

    final uri = Uri.parse(APPUrl.categoryListUrl)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CategoryListModel categoryListModel =
            CategoryListModel.fromJson(jsonData);

        categoryList = categoryListModel.category;
        // Assuming categoryDemo is still relevant
        categoryList!.insert(0, categoryDemo);

        notifyListeners();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (error) {
      // debugPrintdebugPrint('Error fetching categories: $error');
      rethrow;
    }
  }

  Future<void> searchAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterParent != null && filterParent.isNotEmpty) {
      queryParameters['filter_parent'] = filterParent;
    }

    final uri = Uri.parse(APPUrl.categoryListUrl)
        .replace(queryParameters: queryParameters);

    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CategoryListModel categoryListModel =
            CategoryListModel.fromJson(jsonData);

        searchCategoryList = categoryListModel.category;
        searchCategoryList!.insert(0, categoryDemo);
        searchCategoryList = categoryListModel.category;

        // debugPrintdebugPrint("categoryListModel.pagination?.toString()");
        // debugPrintdebugPrint(categoryListModel.pagination?.toString());

        currentPage = categoryListModel.pagination?.currentPage ?? 1;
        totalPages = categoryListModel.pagination?.lastPage ?? 1;

        notifyListeners();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (error) {
      // debugPrintdebugPrint('Error fetching categories: $error');
      rethrow;
    }
  }

  //          *********************** VIEW  CATEGORY USING CATEGORY ID API ***************************************************

  Future<void> viewCategoryApi({required int categoryId}) async {
    // debugPrintdebugPrint("VIEW  CATEGORY ");

    final url = Uri.parse("${APPUrl.viewCategoryListUrl}?id=$categoryId");
    try {
      final response =
          await http.get(url, headers: {'Content-Type': 'application/json'});
      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        ViewCategoryModel viewCategoryModel =
            ViewCategoryModel.fromJson(jsonData);

        viewCategory = viewCategoryModel.data;

        notifyListeners();
      } else {}
    } finally {}
  }

  //          *********************** ADD CATEGORY  API ***************************************************

  Future<dynamic> addCategory(
      {required String categoryName,
      required String slug,
      required String parentCategory,
      required String categoryNameEnglish,
      required String categoryNameHindi,
      required String categoryNameArabic,
      required String imagePath,
      required String iconPath,
      required String accessToken}) async {
    // debugPrintdebugPrint("ADD CATEGORY  API parentCategory $parentCategory ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryName $categoryName ");
    // debugPrintdebugPrint("ADD CATEGORY  API slug $slug ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameEnglish $categoryNameEnglish ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameHindi $categoryNameHindi ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameArabic $categoryNameArabic ");

    final Map<String, dynamic> apiBodyData = {
      'name': categoryName,
      'slug': slug,
      'parent_category': parentCategory,
      'category_lang_name[en]': categoryNameEnglish,
      'category_lang_name[hi]': categoryNameHindi,
      'category_lang_name[ar]': categoryNameArabic,
      'image': imagePath,
      'icon': iconPath
    };

    // debugPrintdebugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addCategoryUrl);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        listAllCategory();
        notifyListeners();
        // debugPrintdebugPrint(json.decode(response.body).toString());
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  //          *********************** SELECT CATEGORY  FUNCTION ***************************************************
  void selectCategory(int index, String categoryName, int categoryCounts) {
    _selectedCategoryIndex = index;
    notifyListeners();
    categoryText = categoryName;
    categoryCount = categoryCounts;
    notifyListeners();
  }

  //          ***********************SET THE SELECTED CATEGORY INDEX FUNCTION ***************************************************
  void setSelectCategoryIndex(int index) {
    _selectedCategoryIndex = index;
    notifyListeners();
  }

  //          *********************** FUNCTION FOR SEARCH BY CATEGORY  ***************************************************
  List<Category> searchCategories(String query) {
    if (query.isNotEmpty) {
      return categoryList!
          .where((category) => category.categoryName!
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    } else {
      return categoryListWithoutQuery!;
    }
  }

  List<Category> searchCategoryPageCategories(String query) {
    // debugPrintdebugPrint("searchCategoryPageCategories $query");
    if (query.isNotEmpty) {
      return categoryListWithoutQuery!
          .where((category) => category.categoryName!
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    } else {
      return categoryListWithoutQuery!;
    }
  }

  //          *********************** FUNCTION FOR UPDATE BY CATEGORY  ***************************************************
  // Add this method to update the filtered categories
  void updateFilteredCategories(List<Category> filteredCategories) {
    categoryList = filteredCategories;
    notifyListeners();
  }

  void updateCategoryPageFilteredCategories(List<Category> filteredCategories) {
    filteredcategoryList = filteredCategories;
    notifyListeners();
  }

  //          *********************** EDIT CATEGORY  API ***************************************************
  Future<dynamic> editCategory(
      {required int categoryId,
      required String categoryName,
      required String slug,
      required String parentCategory,
      required String categoryNameEnglish,
      required String categoryNameHindi,
      required String categoryNameArabic,
      required String imagePath,
      required String iconPath,
      required String accessToken}) async {
    // debugPrintdebugPrint("ADD CATEGORY  API parentCategory $parentCategory ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryName $categoryName ");
    // debugPrintdebugPrint("ADD CATEGORY  API slug $slug ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameEnglish $categoryNameEnglish ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameHindi $categoryNameHindi ");
    // debugPrintdebugPrint("ADD CATEGORY  API categoryNameArabic $categoryNameArabic ");

    final Map<String, dynamic> apiBodyData = {
      'name': categoryName,
      'slug': slug,
      'parent_category': parentCategory,
      'category_lang_name[en]': categoryNameEnglish,
      'category_lang_name[hi]': categoryNameHindi,
      'category_lang_name[ar]': categoryNameArabic,
      'category_image': imagePath,
      'category_icon': iconPath
    };

    // debugPrintdebugPrint(apiBodyData.toString());

    final url = Uri.parse("${APPUrl.editCategoryUrl}/$categoryId");
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        listAllCategory();
        notifyListeners();
        // debugPrintdebugPrint(json.decode(response.body).toString());
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  Future<void> fetchPropValues({
    required int categoryId,
    required String accessToken,
  }) async {
    // debugPrintdebugPrint("FETCH PROP VALUES for category_id $categoryId");
    final url =
        Uri.parse("${APPUrl.fetchCategoryProps}?category_id=$categoryId");

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrintdebugPrint('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint("Response body: ${response.body}");
        final jsonData = json.decode(response.body);
        // debugPrintdebugPrint("Parsed JSON data: ${jsonData.toString()}");
        propValues = jsonData['success'];
        notifyListeners();
      } else {
        // debugPrintdebugPrint("Response body: ${response.body}");
        final jsonData = json.decode(response.body);
        // debugPrintdebugPrint("Parsed Null data: ${jsonData.toString()}");
        propValues = [];
        notifyListeners();
        // debugPrintdebugPrint("Failed to fetch data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      // debugPrintdebugPrint('Error fetching prop values: ${e.toString()}');
    }
  }
}
