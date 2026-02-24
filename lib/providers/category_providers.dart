import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/view_category.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/local_models.dart';

import '../resources/app_url.dart';

class CategoryProvider extends ChangeNotifier {
  bool isLoading = false;
  bool _isCategoriesLoaded =
      false; // Add this flag to track if categories are loaded
  DateTime? _lastSuccessfulCategoryFetchAt;
  static const Duration _categoryCacheValidity = Duration(minutes: 2);
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
    bool sellableOnly = true,
    bool force = false,
  }) async {
    final bool isUnfilteredRequest = filterName == null && filterParent == null;
    final bool hasInMemoryCategories =
        categoryList != null && categoryList!.isNotEmpty;
    final bool cacheIsFresh = _lastSuccessfulCategoryFetchAt != null &&
        DateTime.now().difference(_lastSuccessfulCategoryFetchAt!) <
            _categoryCacheValidity;

    // If categories are already loaded and no filtering is applied, return early
    // BUT also check if categoryList is not empty to avoid empty list issues
    if (!force &&
        _isCategoriesLoaded &&
        isUnfilteredRequest &&
        hasInMemoryCategories &&
        cacheIsFresh) {
      debugPrint(
          "🏷️ [CategoryProvider] Using cached categories: ${categoryList!.length}");
      return;
    }

    bool loadedFromHiveCache = false;

    // If filtering is applied, we need to make a new API call regardless
    if (filterName != null || filterParent != null) {
      debugPrint(
          "🏷️ [CategoryProvider] Making API call for filtering: filterName=$filterName");
      // Don't reset the loaded flag for filtered results, just make the call
    } else {
      debugPrint(
          "🏷️ [CategoryProvider] Making initial API call for categories");

      // Try to load from Hive first for non-filtered requests
      if (categoryList == null || categoryList!.isEmpty) {
        final cachedCategories = await loadCategoriesFromHive();
        if (cachedCategories.isNotEmpty) {
          categoryList = cachedCategories;
          _originalCategoryList = List.from(categoryList!);
          _isCategoriesLoaded = true;
          loadedFromHiveCache = true;
          notifyListeners();
          debugPrint("🏷️ [CategoryProvider] Using categories from Hive cache");
        }
      }
    }

    if (loadedFromHiveCache) {
      debugPrint(
          "🏷️ [CategoryProvider] Refreshing categories from API in background");
    } else {
      isLoading = true;
      notifyListeners();
    }

    // Get API key for store_id
    final prefs = await SharedPreferences.getInstance();
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    // Choose the appropriate URL based on the sellableOnly flag
    final urlString = sellableOnly
        ? APPUrl.getSellableCategoryListUrl
        : APPUrl.getRawCategoryListUrl;

    final baseUri = Uri.parse(urlString);
    final finalQueryParameters =
        Map<String, dynamic>.from(baseUri.queryParameters)
          ..addAll(queryParameters);
    final uri = baseUri.replace(queryParameters: finalQueryParameters);

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

        // Store the original unfiltered list only when no filtering is applied
        if (filterName == null && filterParent == null) {
          _originalCategoryList = List.from(categoryList!);
          _isCategoriesLoaded = true;
          _lastSuccessfulCategoryFetchAt = DateTime.now();

          // Save to Hive for future offline use
          if (categoryList != null && categoryList!.isNotEmpty) {
            await saveCategoriesToHive(categoryList!);
          }
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
      if (categoryList == null || categoryList!.isEmpty) {
        _isCategoriesLoaded =
            false; // Reset flag on error only when no fallback
      }
      notifyListeners();
      debugPrint('Error fetching categories: $error');
      if (loadedFromHiveCache) {
        return;
      }
      rethrow;
    }
  }

  // Add a method to force refresh categories (useful for manual refresh)
  Future<void> refreshCategories() async {
    _isCategoriesLoaded = false;
    categoryList?.clear();
    _originalCategoryList?.clear();

    // Clear Hive cache for fresh data
    await clearCategoriesFromHive();

    await listAllCategory();
  }

  // Add a method to check if categories are properly loaded
  bool get hasValidCategories =>
      categoryList != null && categoryList!.isNotEmpty;

  // Add a getter to check if categories are loaded
  bool get isCategoriesLoaded => _isCategoriesLoaded;

  // Add a setter to update the categories loaded flag
  set isCategoriesLoaded(bool value) {
    _isCategoriesLoaded = value;
    notifyListeners();
  }

  // Method to ensure categories are available for UI components like sidebar
  Future<void> ensureCategoriesLoaded() async {
    if (!_isCategoriesLoaded || categoryList == null || categoryList!.isEmpty) {
      debugPrint(
          "🏷️ [CategoryProvider] ensureCategoriesLoaded - loading categories");
      await listAllCategory();
    } else {
      debugPrint(
          "🏷️ [CategoryProvider] ensureCategoriesLoaded - categories already available: ${categoryList!.length}");
    }
  }

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
    // Get API key for store_id
    final prefs = await SharedPreferences.getInstance();
    final int? activeStoreId = prefs.getInt('active_store_id');

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
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final baseUri = Uri.parse(APPUrl.getSellableCategoryListUrl);
    final finalQueryParameters =
        Map<String, dynamic>.from(baseUri.queryParameters)
          ..addAll(queryParameters);
    final uri = baseUri.replace(queryParameters: finalQueryParameters);
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
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Add store_id to query parameters
    final Map<String, String> queryParams = {};
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final updatedUrl = url.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response = await http.get(updatedUrl, headers: {
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

  // Hive storage methods for categories
  Future<void> saveCategoriesToHive(List<Category> categories) async {
    try {
      final categoriesBox = await Hive.openBox<HiveCategory>('categories');

      // Clear existing categories
      await categoriesBox.clear();

      // Save new categories
      for (Category category in categories) {
        final hiveCategory = HiveCategory.fromCategory(category);
        await categoriesBox.put(category.categoryId, hiveCategory);
      }

      debugPrint(
          "🏷️ [CategoryProvider] Saved ${categories.length} categories to Hive");
    } catch (e) {
      debugPrint("🏷️ [CategoryProvider] Error saving categories to Hive: $e");
    }
  }

  Future<List<Category>> loadCategoriesFromHive() async {
    try {
      if (!Hive.isBoxOpen('categories')) {
        await Hive.openBox<HiveCategory>('categories');
      }

      final categoriesBox = Hive.box<HiveCategory>('categories');
      final hiveCategories = categoriesBox.values.toList();

      // Convert Hive categories back to app model
      final categories = hiveCategories
          .map((hiveCategory) => hiveCategory.toCategory())
          .toList();

      debugPrint(
          "🏷️ [CategoryProvider] Loaded ${categories.length} categories from Hive");
      return categories;
    } catch (e) {
      debugPrint(
          "🏷️ [CategoryProvider] Error loading categories from Hive: $e");
      return [];
    }
  }

  Future<void> clearCategoriesFromHive() async {
    try {
      if (Hive.isBoxOpen('categories')) {
        await Hive.box<HiveCategory>('categories').clear();
        debugPrint("🏷️ [CategoryProvider] Cleared categories from Hive");
      }
    } catch (e) {
      debugPrint(
          "🏷️ [CategoryProvider] Error clearing categories from Hive: $e");
    }
  }

  /// Clears ALL category data for multi-tenant isolation.
  /// Call this during logout or when switching API keys (tenants)
  /// to prevent data leakage between different tenants.
  Future<void> clearAllCategories() async {
    debugPrint("🧹 CLEARING ALL CATEGORY DATA FOR TENANT ISOLATION");

    try {
      // Clear Hive storage
      await clearCategoriesFromHive();

      // Clear in-memory lists
      categoryList?.clear();
      searchCategoryList?.clear();
      filteredcategoryList?.clear();
      categoryListWithoutQuery?.clear();
      _originalCategoryList?.clear();

      // Reset state
      _isCategoriesLoaded = false;
      viewCategory = null;
      categoryText = '';
      parentCategory = '0';
      editCategoryId = 0;
      propCategory = 0;
      categoryCount = 0;
      currentPage = 1;
      totalPages = 1;
      propValues = null;
      _selectedCategoryIndex = 0;

      notifyListeners();
      debugPrint("✅ ALL CATEGORY DATA CLEARED SUCCESSFULLY");
    } catch (e) {
      debugPrint("❌ Error clearing category data: $e");
      rethrow;
    }
  }
}
