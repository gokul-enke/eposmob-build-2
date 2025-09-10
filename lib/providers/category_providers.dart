import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/view_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';

class CategoryProvider extends ChangeNotifier {
  bool isLoading = false;
  bool _isCategoriesLoaded = false; // Add this flag to track if categories are loaded
  List<Category>? categoryList = [];
  List<Category>? searchCategoryList = [];
  List<Category>? filteredcategoryList = [];
  List<Category>? categoryListWithoutQuery = [];
  List<Category>? _originalCategoryList = []; // Store original unfiltered list
  String categoryText = '';
  ViewCategory? viewCategory;
  String parentCategory = '0';
  int editCategoryId = 0;
  int propCategory = 0;
  int currentPage = 1;
  int totalPages = 1;

  CategoryProvider() {
    // Remove the automatic API call from constructor
    // listAllCategory();
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
    // debugPrint("SET CATEGORY ID FOR PROP $categoryId");
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
    // If categories are already loaded and no filtering is applied, return early
    if (_isCategoriesLoaded && filterName == null && filterParent == null) {
      return;
    }

    // If filtering is applied, we need to make a new API call regardless
    if (filterName != null || filterParent != null) {
      // Reset the loaded flag for filtered results
      _isCategoriesLoaded = false;
    }

    isLoading = true;
    notifyListeners();

    // Ensure we always send a valid page number; default to 1 if not provided
    final int effectivePage = page ?? 1;
    final queryParameters = <String, String>{
      'page': effectivePage.toString(),
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterParent != null && filterParent.isNotEmpty) {
      queryParameters['filter_parent'] = filterParent;
    }

    final uri = Uri.parse(APPUrl.categoryListUrl)
        .replace(queryParameters: queryParameters);

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CategoryListModel categoryListModel =
            CategoryListModel.fromJson(jsonData);

        categoryList = categoryListModel.category;
        // Assuming categoryDemo is still relevant
        categoryList!.insert(0, categoryDemo);

        // Store the original unfiltered list only when no filtering is applied
        if (filterName == null && filterParent == null) {
          _originalCategoryList = List.from(categoryList!);
          _isCategoriesLoaded = true;
        }

        isLoading = false;
        notifyListeners();
      } else {
        isLoading = false;
        notifyListeners();
        throw Exception('Failed to load categories');
      }
    } catch (error) {
      isLoading = false;
      notifyListeners();
      // debugPrint('Error fetching categories: $error');
      rethrow;
    }
  }

  // Add a method to force refresh categories (useful for manual refresh)
  Future<void> refreshCategories() async {
    _isCategoriesLoaded = false;
    await listAllCategory();
  }

  // Add a getter to check if categories are loaded
  bool get isCategoriesLoaded => _isCategoriesLoaded;

  /// Resets the category filter without making an API call
  /// This method restores the original unfiltered category list
  void resetCategoryFilter() {
    // Restore the original unfiltered category list if available
    if (_originalCategoryList != null && _originalCategoryList!.isNotEmpty) {
      categoryList = List.from(_originalCategoryList!);
      notifyListeners();
    } else {
      // Fallback: reload categories if original list is not available
      _isCategoriesLoaded = false;
      listAllCategory();
    }
  }

  Future<void> searchAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
  }) async {
    // Ensure we always send a valid page number; default to 1 if not provided
    final int effectivePage = page ?? 1;
    final queryParameters = <String, String>{
      'page': effectivePage.toString(),
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterParent != null && filterParent.isNotEmpty) {
      queryParameters['filter_parent'] = filterParent;
    }

    final uri = Uri.parse(APPUrl.categoryListUrl)
        .replace(queryParameters: queryParameters);

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CategoryListModel categoryListModel =
            CategoryListModel.fromJson(jsonData);

        searchCategoryList = categoryListModel.category;
        searchCategoryList!.insert(0, categoryDemo);
        searchCategoryList = categoryListModel.category;

        // debugPrint("categoryListModel.pagination?.toString()");
        // debugPrint(categoryListModel.pagination?.toString());

        currentPage = categoryListModel.pagination?.currentPage ?? 1;
        totalPages = categoryListModel.pagination?.lastPage ?? 1;

        notifyListeners();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (error) {
      // debugPrint('Error fetching categories: $error');
      rethrow;
    }
  }

  //          *********************** VIEW  CATEGORY USING CATEGORY ID API ***************************************************

  Future<void> viewCategoryApi({required int categoryId}) async {
    // debugPrint("VIEW  CATEGORY ");

    final url = Uri.parse("${APPUrl.viewCategoryListUrl}?id=$categoryId");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
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
    // debugPrint("ADD CATEGORY  API parentCategory $parentCategory ");
    // debugPrint("ADD CATEGORY  API categoryName $categoryName ");
    // debugPrint("ADD CATEGORY  API slug $slug ");
    // debugPrint("ADD CATEGORY  API categoryNameEnglish $categoryNameEnglish ");
    // debugPrint("ADD CATEGORY  API categoryNameHindi $categoryNameHindi ");
    // debugPrint("ADD CATEGORY  API categoryNameArabic $categoryNameArabic ");

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

    // debugPrint(apiBodyData.toString());
    final url = Uri.parse(APPUrl.addCategoryUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        listAllCategory();
        notifyListeners();
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
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
    // debugPrint("searchCategoryPageCategories $query");
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
    // debugPrint("ADD CATEGORY  API parentCategory $parentCategory ");
    // debugPrint("ADD CATEGORY  API categoryName $categoryName ");
    // debugPrint("ADD CATEGORY  API slug $slug ");
    // debugPrint("ADD CATEGORY  API categoryNameEnglish $categoryNameEnglish ");
    // debugPrint("ADD CATEGORY  API categoryNameHindi $categoryNameHindi ");
    // debugPrint("ADD CATEGORY  API categoryNameArabic $categoryNameArabic ");

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

    // debugPrint(apiBodyData.toString());

    final url = Uri.parse("${APPUrl.editCategoryUrl}/$categoryId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        listAllCategory();
        notifyListeners();
        // debugPrint(json.decode(response.body).toString());
        // debugPrint(json.decode(response.body).toString());
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
    // debugPrint("FETCH PROP VALUES for category_id $categoryId");
    final url =
        Uri.parse("${APPUrl.fetchCategoryProps}?category_id=$categoryId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint("Response body: ${response.body}");
        final jsonData = json.decode(response.body);
        // debugPrint("Parsed JSON data: ${jsonData.toString()}");
        propValues = jsonData['success'];
        notifyListeners();
      } else {
        // debugPrint("Response body: ${response.body}");
        final jsonData = json.decode(response.body);
        // debugPrint("Parsed Null data: ${jsonData.toString()}");
        propValues = [];
        notifyListeners();
        // debugPrint("Failed to fetch data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      // debugPrint('Error fetching prop values: ${e.toString()}');
    }
  }
}
