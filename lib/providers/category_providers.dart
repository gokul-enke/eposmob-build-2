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
import 'category_list_scope.dart';

class _ScopeCache {
  List<Category> items = [];
  int? storeId;
  DateTime? fetchedAt;

  bool isValidForStore(int? activeStoreId) {
    return storeId == activeStoreId && items.isNotEmpty;
  }

  void clear() {
    items = [];
    storeId = null;
    fetchedAt = null;
  }
}

class CategoryProvider extends ChangeNotifier {
  static const int _managementPageSize = 20;
  static const String _hiveBoxSellable = 'categories';
  static const String _hiveBoxAll = 'categories_all';
  static const String _hiveBoxPurchasable = 'categories_purchasable';

  bool isLoading = false;
  bool _isCategoriesLoaded = false;

  final Map<CategoryListScope, _ScopeCache> _scopeCaches = {
    for (final scope in CategoryListScope.values) scope: _ScopeCache(),
  };

  final Map<CategoryListScope, Future<void>?> _inFlightLoads = {};

  // Legacy fields kept for existing UI bindings.
  List<Category>? categoryList = [];
  List<Category>? searchCategoryList = [];
  List<Category>? filteredcategoryList = [];
  List<Category>? categoryListWithoutQuery = [];
  List<Category>? _originalCategoryList = [];
  List<Category>? _managementFilteredAll = [];
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

  int _selectedCategoryIndex = -1;

  int get selectedCategoryIndex => _selectedCategoryIndex;

  List<Category>? get category => categoryList;
  List<Category>? get searchCategory => searchCategoryList;

  List<Category> get sellableCategories =>
      List<Category>.from(_scopeCaches[CategoryListScope.sellable]!.items);

  List<Category> get allCategories =>
      List<Category>.from(_scopeCaches[CategoryListScope.all]!.items);

  List<Category> get purchasableCategories =>
      List<Category>.from(_scopeCaches[CategoryListScope.purchasable]!.items);

  List<Category> categoriesFor(CategoryListScope scope) {
    return List<Category>.from(_scopeCaches[scope]!.items);
  }

  bool isScopeLoaded(CategoryListScope scope, {int? storeId}) {
    final cache = _scopeCaches[scope]!;
    if (storeId != null) {
      return cache.isValidForStore(storeId);
    }
    return cache.items.isNotEmpty;
  }

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
  //          *********************** SCOPED CATEGORY LIST API ***************************************************

  String _urlForScope(CategoryListScope scope) {
    return switch (scope) {
      CategoryListScope.sellable => APPUrl.getSellableCategoryListUrl,
      CategoryListScope.purchasable => APPUrl.getPurchasableCategoryListUrl,
      CategoryListScope.all => APPUrl.getRawCategoryListUrl,
    };
  }

  String _hiveBoxNameForScope(CategoryListScope scope) {
    return switch (scope) {
      CategoryListScope.sellable => _hiveBoxSellable,
      CategoryListScope.purchasable => _hiveBoxPurchasable,
      CategoryListScope.all => _hiveBoxAll,
    };
  }

  /// Load sellable + all + purchasable once (store bootstrap / store switch).
  Future<void> prefetchAllScopesForStore({bool force = false}) async {
    await Future.wait([
      ensureCategories(CategoryListScope.sellable, force: force),
      ensureCategories(CategoryListScope.all, force: force),
      ensureCategories(CategoryListScope.purchasable, force: force),
    ]);
  }

  /// Ensure a scoped category bucket is loaded for the active store.
  Future<void> ensureCategories(
    CategoryListScope scope, {
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (!force && _scopeCaches[scope]!.isValidForStore(activeStoreId)) {
      debugPrint(
        '🏷️ [CategoryProvider] Using in-memory ${scope.name} categories: ${_scopeCaches[scope]!.items.length}',
      );
      _syncLegacyLists(scope);
      return;
    }

    final inFlight = _inFlightLoads[scope];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadFuture = _loadScopeFromNetwork(
      scope,
      activeStoreId: activeStoreId,
      force: force,
    );
    _inFlightLoads[scope] = loadFuture;
    try {
      await loadFuture;
    } finally {
      _inFlightLoads[scope] = null;
    }
  }

  Future<void> _loadScopeFromNetwork(
    CategoryListScope scope, {
    required int? activeStoreId,
    required bool force,
  }) async {
    if (!force &&
        (categoryList == null || categoryList!.isEmpty) &&
        scope == CategoryListScope.sellable) {
      final cached = await loadCategoriesFromHive(boxName: _hiveBoxSellable);
      if (cached.isNotEmpty) {
        _applyScopeItems(scope, cached, activeStoreId);
        _syncLegacyLists(scope);
        notifyListeners();
        debugPrint(
          '🏷️ [CategoryProvider] Hydrated sellable categories from Hive (${cached.length})',
        );
      }
    }

    isLoading = true;
    notifyListeners();

    try {
      final items = await _fetchAllPagesForScope(
        scope,
        storeId: activeStoreId,
      );
      _applyScopeItems(scope, items, activeStoreId);
      await saveCategoriesToHive(items, boxName: _hiveBoxNameForScope(scope));
      _syncLegacyLists(scope);
      debugPrint(
        '🏷️ [CategoryProvider] Loaded ${items.length} ${scope.name} categories from API',
      );
    } catch (error) {
      debugPrint(
        '🏷️ [CategoryProvider] Failed loading ${scope.name} categories: $error',
      );
      if (scope == CategoryListScope.purchasable) {
        debugPrint(
          '🏷️ [CategoryProvider] Purchasable endpoint failed — falling back to all categories',
        );
        if (_scopeCaches[CategoryListScope.all]!
            .isValidForStore(activeStoreId)) {
          _applyScopeItems(
            CategoryListScope.purchasable,
            allCategories,
            activeStoreId,
          );
        } else {
          await ensureCategories(CategoryListScope.all, force: true);
          _applyScopeItems(
            CategoryListScope.purchasable,
            allCategories,
            activeStoreId,
          );
        }
        _syncLegacyLists(CategoryListScope.purchasable);
      } else {
        rethrow;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyScopeItems(
    CategoryListScope scope,
    List<Category> items,
    int? storeId,
  ) {
    final cache = _scopeCaches[scope]!;
    cache.items = List<Category>.from(items);
    cache.storeId = storeId;
    cache.fetchedAt = DateTime.now();
  }

  void _syncLegacyLists([CategoryListScope? changedScope]) {
    final sellable = sellableCategories;
    categoryList = List<Category>.from(sellable);
    _originalCategoryList = List<Category>.from(sellable);
    filteredcategoryList = List<Category>.from(sellable);
    categoryListWithoutQuery = List<Category>.from(allCategories);
    _isCategoriesLoaded = sellable.isNotEmpty;

    if (changedScope == null ||
        changedScope == CategoryListScope.all ||
        searchCategoryList == null ||
        searchCategoryList!.isEmpty) {
      filterManagementCategories(page: currentPage);
    }
  }

  Future<List<Category>> _fetchAllPagesForScope(
    CategoryListScope scope, {
    required int? storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }

    final collected = <Category>[];
    var page = 1;
    var lastPage = 1;

    do {
      final pageResult = await _fetchCategoryPage(
        scope: scope,
        page: page,
        storeId: storeId,
        apiKey: apiKey,
      );
      collected.addAll(pageResult.items);
      lastPage = pageResult.lastPage;
      page++;
    } while (page <= lastPage);

    return collected;
  }

  Future<({List<Category> items, int lastPage})> _fetchCategoryPage({
    required CategoryListScope scope,
    required int page,
    required int? storeId,
    required String apiKey,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
    };
    if (storeId != null) {
      queryParameters['store_id'] = storeId.toString();
    }

    final baseUri = Uri.parse(_urlForScope(scope));
    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        ...queryParameters,
      },
    );

    debugPrint('🏷️ [CategoryProvider] GET $uri (scope=${scope.name})');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw HttpException(
        'Category list failed (${response.statusCode}) for scope ${scope.name}',
      );
    }

    final jsonData = json.decode(response.body);
    final model = CategoryListModel.fromJson(jsonData);
    final items = model.category ?? [];
    final lastPage = model.pagination?.lastPage ?? 1;
    return (items: items, lastPage: lastPage);
  }

  void applyBillingCategoryFilter({
    String? filterName,
    String? filterParent,
  }) {
    var filtered = List<Category>.from(sellableCategories);
    if (filterName != null && filterName.isNotEmpty) {
      final query = filterName.toLowerCase();
      filtered = filtered
          .where(
            (category) =>
                category.categoryName?.toLowerCase().contains(query) ?? false,
          )
          .toList();
    }
    if (filterParent != null && filterParent.isNotEmpty) {
      filtered = filtered
          .where(
            (category) => category.parent?.id?.toString() == filterParent,
          )
          .toList();
    }
    categoryList = filtered;
    notifyListeners();
  }

  void filterManagementCategories({
    String? filterName,
    String? filterParent,
    int page = 1,
  }) {
    var filtered = List<Category>.from(allCategories);

    if (filterName != null && filterName.isNotEmpty) {
      final query = filterName.toLowerCase();
      filtered = filtered
          .where(
            (category) =>
                (category.categoryName?.toLowerCase().contains(query) ?? false) ||
                (category.translations?.values.any((name) =>
                    name.toLowerCase().contains(query)) ?? false),
          )
          .toList();
    }

    if (filterParent != null && filterParent.isNotEmpty) {
      filtered = filtered
          .where(
            (category) => category.parent?.id?.toString() == filterParent,
          )
          .toList();
    }

    _managementFilteredAll = filtered;
    totalPages = filtered.isEmpty
        ? 1
        : ((filtered.length + _managementPageSize - 1) ~/ _managementPageSize);
    currentPage = page.clamp(1, totalPages);

    if (filtered.isEmpty) {
      searchCategoryList = [];
    } else {
      final startIndex = (currentPage - 1) * _managementPageSize;
      final endIndex =
          (startIndex + _managementPageSize).clamp(0, filtered.length);
      searchCategoryList = filtered.sublist(
        startIndex.clamp(0, filtered.length),
        endIndex,
      );
    }
    notifyListeners();
  }

  void invalidateCategories({CategoryListScope? scope}) {
    if (scope != null) {
      _scopeCaches[scope]!.clear();
    } else {
      for (final cache in _scopeCaches.values) {
        cache.clear();
      }
    }
    _isCategoriesLoaded = false;
  }

  /// Legacy entry point — maps to scoped cache + optional local billing filter.
  Future<void> listAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
    bool sellableOnly = true,
    bool scopeToActiveStore = true,
    bool force = false,
  }) async {
    final scope = sellableOnly
        ? CategoryListScope.sellable
        : CategoryListScope.all;
    await ensureCategories(scope, force: force);

    if (filterName != null || filterParent != null) {
      if (scope == CategoryListScope.sellable) {
        applyBillingCategoryFilter(
          filterName: filterName,
          filterParent: filterParent,
        );
      }
    }
  }

  Future<void> refreshCategories() async {
    await refreshManagementCategories();
  }

  /// Full category directory for management screens.
  Future<void> refreshManagementCategories({bool force = true}) async {
    await ensureCategories(CategoryListScope.all, force: force);
    filterManagementCategories(page: 1);
  }

  Future<void> upsertCategoryInCache(
    Category category, {
    bool isSellable = true,
    bool isPurchasable = true,
  }) async {
    final categoryId = category.categoryId;
    if (categoryId == null) return;

    for (final scope in CategoryListScope.values) {
      final cache = _scopeCaches[scope]!;
      cache.items.removeWhere((item) => item.categoryId == categoryId);

      if (scope == CategoryListScope.sellable && !isSellable) continue;
      if (scope == CategoryListScope.purchasable && !isPurchasable) continue;

      cache.items.insert(0, category);
    }

    _syncLegacyLists();
    await saveCategoriesToHive(
      sellableCategories,
      boxName: _hiveBoxSellable,
    );
    await saveCategoriesToHive(
      allCategories,
      boxName: _hiveBoxAll,
    );
    await saveCategoriesToHive(
      purchasableCategories,
      boxName: _hiveBoxPurchasable,
    );
    notifyListeners();
  }

  Future<void> _refreshAfterCategoryMutation(
    Map<String, dynamic> decoded, {
    required bool isSellable,
    required bool isPurchasable,
  }) async {
    invalidateCategories();
    await prefetchAllScopesForStore(force: true);

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return;

    final newCategory = Category.fromJson(data);
    final alreadyListed = allCategories.any(
      (category) => category.categoryId == newCategory.categoryId,
    );

    if (!alreadyListed) {
      debugPrint(
        '🏷️ [CategoryProvider] New category ${newCategory.categoryId} missing from list API — upserting locally',
      );
      await upsertCategoryInCache(
        newCategory,
        isSellable: isSellable,
        isPurchasable: isPurchasable,
      );
    }
  }

  bool get hasValidCategories => sellableCategories.isNotEmpty;

  bool get isCategoriesLoaded => _isCategoriesLoaded;

  set isCategoriesLoaded(bool value) {
    _isCategoriesLoaded = value;
    notifyListeners();
  }

  Future<void> ensureCategoriesLoaded() async {
    await ensureCategories(CategoryListScope.sellable);
  }

  void resetCategoryFilter() {
    if (_originalCategoryList != null && _originalCategoryList!.isNotEmpty) {
      categoryList = List.from(_originalCategoryList!);
      notifyListeners();
      return;
    }
    ensureCategories(CategoryListScope.sellable);
  }

  /// Legacy management search — local filter on the all-categories cache.
  Future<void> searchAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
    bool sellableOnly = true,
    bool scopeToActiveStore = true,
  }) async {
    final scope =
        sellableOnly ? CategoryListScope.sellable : CategoryListScope.all;
    await ensureCategories(scope);
    if (scope == CategoryListScope.all) {
      filterManagementCategories(
        filterName: filterName,
        filterParent: filterParent,
        page: page ?? 1,
      );
      return;
    }

    applyBillingCategoryFilter(
      filterName: filterName,
      filterParent: filterParent,
    );
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
    final queryParams = Map<String, String>.from(url.queryParameters);
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final updatedUrl = url.replace(queryParameters: queryParams);

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
    required String accessToken,
    bool isSellable = true,
    bool isPurchasable = true,
    String? description,
    List<int>? productPropertyIds,
    List<int>? taxIds,
    Map<String, String>? categoryLangNames}) async {
    // debugPrint("ADD CATEGORY  API parentCategory $parentCategory ");
    // debugPrint("ADD CATEGORY  API categoryName $categoryName ");
    // debugPrint("ADD CATEGORY  API slug $slug ");
    // debugPrint("ADD CATEGORY  API categoryNameEnglish $categoryNameEnglish ");
    // debugPrint("ADD CATEGORY  API categoryNameHindi $categoryNameHindi ");
    // debugPrint("ADD CATEGORY  API categoryNameArabic $categoryNameArabic ");

    final url = Uri.parse(APPUrl.addCategoryUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['X-Tenant'] = apiKey
      ..fields['name'] = categoryName
      ..fields['slug'] = slug
      ..fields['sort_order'] = '0'
      ..fields['is_sellable'] = isSellable ? '1' : '0'
      ..fields['is_purchasable'] = isPurchasable ? '1' : '0';

    if (activeStoreId != null) {
      request.fields['store_id'] = activeStoreId.toString();
    }

    if (parentCategory.trim().isNotEmpty && parentCategory.trim() != '0') {
      request.fields['parent_category'] = parentCategory.trim();
    }

    final resolvedDescription = description?.trim() ?? '';
    if (resolvedDescription.isNotEmpty) {
      request.fields['description'] = resolvedDescription;
    }

    // Always send at least one translation field to prevent the backend from throwing a foreach() error on a null category_lang_name.
    request.fields['category_lang_name[en]'] = categoryNameEnglish.trim().isNotEmpty
        ? categoryNameEnglish.trim()
        : categoryName.trim();

    if (categoryNameHindi.trim().isNotEmpty) {
      request.fields['category_lang_name[hi]'] = categoryNameHindi.trim();
    }
    if (categoryNameArabic.trim().isNotEmpty) {
      request.fields['category_lang_name[ar]'] = categoryNameArabic.trim();
    }

    if (categoryLangNames != null && categoryLangNames.isNotEmpty) {
      categoryLangNames.forEach((code, value) {
        final trimmedValue = value.trim();
        final trimmedCode = code.trim();
        if (trimmedCode.isNotEmpty && trimmedValue.isNotEmpty) {
          request.fields['category_lang_name[$trimmedCode]'] = trimmedValue;
        }
      });
    }

    if (productPropertyIds != null && productPropertyIds.isNotEmpty) {
      for (int index = 0; index < productPropertyIds.length; index++) {
        request.fields['product_properties[$index]'] =
            productPropertyIds[index].toString();
      }
    }

    if (taxIds != null && taxIds.isNotEmpty) {
      for (int index = 0; index < taxIds.length; index++) {
        request.fields['tax_ids[$index]'] = taxIds[index].toString();
      }
    }

    /*
    if (imagePath.trim().isNotEmpty) {
      final imageFile = File(imagePath);
      debugPrint("IMAGE PATH: $imagePath");          
      debugPrint("IMAGE FILE EXISTS: ${await imageFile.exists()}"); 
      if (await imageFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
      } else {
        request.fields['image'] = imagePath;
      }
    }

    if (iconPath.trim().isNotEmpty) {
      final iconFile = File(iconPath);
      if (await iconFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('icon', iconPath),
        );
      } else {
        request.fields['icon'] = iconPath;
      }
    }
    */

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 20),
          );
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("ADD CATEGORY STATUS: ${response.statusCode}");
      debugPrint("ADD CATEGORY RESPONSE: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        await _refreshAfterCategoryMutation(
          decoded,
          isSellable: isSellable,
          isPurchasable: isPurchasable,
        );
        return decoded;
      }

      final decodedBody = response.body.isNotEmpty
          ? json.decode(response.body)
          : {
              'status': 'error',
              'message': 'Failed to add category',
            };
      return decodedBody;
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
          .where((category) =>
              (category.categoryName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (category.translations?.values.any((name) =>
                  name.toLowerCase().contains(query.toLowerCase())) ?? false))
          .toList();
    } else {
      return categoryListWithoutQuery!;
    }
  }

  List<Category> searchCategoryPageCategories(String query) {
    // debugPrint("searchCategoryPageCategories $query");
    if (query.isNotEmpty) {
      return categoryListWithoutQuery!
          .where((category) =>
              (category.categoryName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (category.translations?.values.any((name) =>
                  name.toLowerCase().contains(query.toLowerCase())) ?? false))
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
      required String accessToken,
      bool isSellable = true,
      bool isPurchasable = true}) async {
    final url = Uri.parse("${APPUrl.editCategoryUrl}/$categoryId");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['X-Tenant'] = apiKey
      ..fields['name'] = categoryName
      ..fields['slug'] = slug
            ..fields['sort_order'] = '0';

    request.fields['is_sellable'] = isSellable ? '1' : '0';
    request.fields['is_purchasable'] = isPurchasable ? '1' : '0';
    if (parentCategory.trim().isNotEmpty && parentCategory.trim() != '0') {
      request.fields['parent_category'] = parentCategory.trim();
    }

    request.fields['category_lang_name[en]'] = categoryNameEnglish.trim().isNotEmpty
        ? categoryNameEnglish.trim()
        : categoryName.trim();

    if (categoryNameHindi.trim().isNotEmpty) {
      request.fields['category_lang_name[hi]'] = categoryNameHindi.trim();
    }
    if (categoryNameArabic.trim().isNotEmpty) {
      request.fields['category_lang_name[ar]'] = categoryNameArabic.trim();
    }

    /*
    if (imagePath.trim().isNotEmpty) {
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
      } else {
        // Already a URL from backend, send as field
        request.fields['category_image'] = imagePath;
      }
    }

    if (iconPath.trim().isNotEmpty) {
      final iconFile = File(iconPath);
      if (await iconFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('icon', iconPath),
        );
      } else {
        request.fields['category_icon'] = iconPath;
      }
    }
    */

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 20),
          );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("EDIT CATEGORY STATUS: ${response.statusCode}");
      debugPrint("EDIT CATEGORY RESPONSE: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        await _refreshAfterCategoryMutation(
          decoded,
          isSellable: isSellable,
          isPurchasable: isPurchasable,
        );
        return decoded;
      }

      final decodedBody = response.body.isNotEmpty
          ? json.decode(response.body)
          : {'status': 'error', 'message': 'Failed to edit category'};
      return decodedBody;
    } finally {}
  }

  Future<void> fetchPropValues({
    required int categoryId,
    required String accessToken,
  }) async {
    // debugPrint("FETCH PROP VALUES for category_id $categoryId");
    final baseUri =
        Uri.parse("${APPUrl.fetchCategoryProps}?category_id=$categoryId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Preserve existing params (category_id) and add store_id if available
    final queryParams = Map<String, String>.from(baseUri.queryParameters);
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }
    final url = baseUri.replace(queryParameters: queryParams);
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
  Future<void> saveCategoriesToHive(
    List<Category> categories, {
    String boxName = 'categories',
  }) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<HiveCategory>(boxName);
      }
      final categoriesBox = Hive.box<HiveCategory>(boxName);

      await categoriesBox.clear();

      for (Category category in categories) {
        final hiveCategory = HiveCategory.fromCategory(category);
        await categoriesBox.put(category.categoryId, hiveCategory);
      }

      debugPrint(
        '🏷️ [CategoryProvider] Saved ${categories.length} categories to Hive ($boxName)',
      );
    } catch (e) {
      debugPrint(
        '🏷️ [CategoryProvider] Error saving categories to Hive ($boxName): $e',
      );
    }
  }

  Future<List<Category>> loadCategoriesFromHive({
    String boxName = 'categories',
  }) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<HiveCategory>(boxName);
      }

      final categoriesBox = Hive.box<HiveCategory>(boxName);
      final hiveCategories = categoriesBox.values.toList();

      final categories = hiveCategories
          .map((hiveCategory) => hiveCategory.toCategory())
          .toList();

      debugPrint(
        '🏷️ [CategoryProvider] Loaded ${categories.length} categories from Hive ($boxName)',
      );
      return categories;
    } catch (e) {
      debugPrint(
        '🏷️ [CategoryProvider] Error loading categories from Hive ($boxName): $e',
      );
      return [];
    }
  }

  Future<void> clearCategoriesFromHive({String boxName = 'categories'}) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<HiveCategory>(boxName).clear();
        debugPrint('🏷️ [CategoryProvider] Cleared Hive box $boxName');
      }
    } catch (e) {
      debugPrint(
        '🏷️ [CategoryProvider] Error clearing Hive box $boxName: $e',
      );
    }
  }

  /// Clears ALL category data for multi-tenant isolation.
  /// Call this during logout or when switching API keys (tenants)
  /// to prevent data leakage between different tenants.
  Future<void> clearAllCategories() async {
    debugPrint('🧹 CLEARING ALL CATEGORY DATA FOR TENANT ISOLATION');

    try {
      for (final scope in CategoryListScope.values) {
        await clearCategoriesFromHive(boxName: _hiveBoxNameForScope(scope));
        _scopeCaches[scope]!.clear();
      }

      categoryList?.clear();
      searchCategoryList?.clear();
      filteredcategoryList?.clear();
      categoryListWithoutQuery?.clear();
      _originalCategoryList?.clear();
      _managementFilteredAll?.clear();

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
      _selectedCategoryIndex = -1;

      notifyListeners();
      debugPrint('✅ ALL CATEGORY DATA CLEARED SUCCESSFULLY');
    } catch (e) {
      debugPrint('❌ Error clearing category data: $e');
      rethrow;
    }
  }
}
