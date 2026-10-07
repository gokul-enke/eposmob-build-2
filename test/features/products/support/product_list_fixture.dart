import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import '../../../test_support/app_settings_fakes.dart';
import '../../../test_support/app_translations.dart';

class ListCatalog extends LocalProductProvider {
  ListCatalog()
      : values = List.generate(
            45,
            (i) => GetProduct(
                productId: i + 1,
                productName: 'Catalog ${i + 1}',
                categoryId: i < 25 ? 1 : 2,
                barcode: '${1000 + i}',
                itemCode: 'CODE-${i + 1}',
                hsnCode: 'HSN-${i + 1}',
                price: ProductPrice(price: '10.000'),
                mrp: '12.000',
                purchasePrice: 'SECRET-COST',
                unit: 'PCS'));
  final List<GetProduct> values;
  final List<int> deletes = [];
  bool deleteResult = true;
  @override
  List<GetProduct> get products => values;
  @override
  Future<bool> deleteProductAPI(int id) async {
    deletes.add(id);
    if (deleteResult) {
      values.removeWhere((p) => p.productId == id);
      notifyListeners();
    }
    return deleteResult;
  }
}

class ListCategories extends CategoryProvider {
  @override
  bool get isCategoriesLoaded => true;
  @override
  List<Category>? get category => [
        Category(categoryId: 1, categoryName: 'Fresh'),
        Category(categoryId: 2, categoryName: 'General')
      ];
}

class ListRole extends RoleProvider {
  bool purchaseAccess = false;
  @override
  bool currentUserHasPermissionSync(String permission) => purchaseAccess;
  void setPurchaseAccess(bool access) {
    purchaseAccess = access;
    notifyListeners();
  }
}

class ProductListFixture {
  final catalog = ListCatalog();
  final categories = ListCategories();
  final settings = FakeAppSettingsProvider();
  final role = ListRole();
  Widget wrap(Widget page) => MultiProvider(
          providers: [
            ChangeNotifierProvider<LocalProductProvider>.value(value: catalog),
            ChangeNotifierProvider<CategoryProvider>.value(value: categories),
            ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
            ChangeNotifierProvider<RoleProvider>.value(value: role),
          ],
          child: GetMaterialApp(
              translations: EnglishTranslations(),
              locale: const Locale('en'),
              home: Scaffold(body: page)));
  void dispose() {
    catalog.dispose();
    categories.dispose();
    settings.dispose();
    role.dispose();
  }
}
