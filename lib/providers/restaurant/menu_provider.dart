import 'package:flutter/foundation.dart';
import '../../models/restaurant/menu_item_model.dart';

class MenuProvider with ChangeNotifier {
  final List<CategoryModel> _categories = [];
  final List<MenuItemModel> _items = [];
  bool _loading = false;
  String? _error;

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<MenuItemModel> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadMenu({bool forceRefresh = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // TODO: Replace with API calls when ready
      await Future.delayed(const Duration(milliseconds: 400));
      if (forceRefresh || _categories.isEmpty || _items.isEmpty) {
        _categories
          ..clear()
          ..addAll(_mockCategories());
        _items
          ..clear()
          ..addAll(_mockItems());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<MenuItemModel> itemsByCategory(String categoryId) {
    return _items.where((i) => i.categoryId == categoryId).toList();
  }

  List<CategoryModel> _mockCategories() {
    return [
      CategoryModel(id: 'c1', name: 'Starters', displayOrder: 1),
      CategoryModel(id: 'c2', name: 'Mains', displayOrder: 2),
      CategoryModel(id: 'c3', name: 'Desserts', displayOrder: 3),
      CategoryModel(id: 'c4', name: 'Beverages', displayOrder: 4),
    ];
  }

  List<MenuItemModel> _mockItems() {
    final spiceGroup = ModifierGroup(
      id: 'mg1',
      name: 'Spice Level',
      isRequired: true,
      maxSelections: 1,
      options: [
        ModifierOption(id: 'm1', name: 'Mild', additionalPrice: 0, isDefault: true),
        ModifierOption(id: 'm2', name: 'Medium', additionalPrice: 0, isDefault: false),
        ModifierOption(id: 'm3', name: 'Spicy', additionalPrice: 0, isDefault: false),
      ],
    );

    final addOns = ModifierGroup(
      id: 'mg2',
      name: 'Add-ons',
      isRequired: false,
      maxSelections: 3,
      options: [
        ModifierOption(id: 'a1', name: 'Cheese', additionalPrice: 20, isDefault: false),
        ModifierOption(id: 'a2', name: 'Extra Sauce', additionalPrice: 10, isDefault: false),
      ],
    );

    return [
      MenuItemModel(
        id: 'i1',
        name: 'Tomato Soup',
        description: 'Fresh tomato soup with herbs',
        price: 120,
        categoryId: 'c1',
        categoryName: 'Starters',
        modifierGroups: [spiceGroup],
        allergens: ['Tomato'],
        preparationTime: 10,
        isAvailable: true,
        imageUrl: null,
        isVegetarian: true,
      ),
      MenuItemModel(
        id: 'i2',
        name: 'Grilled Chicken',
        description: 'Served with sautéed veggies',
        price: 320,
        categoryId: 'c2',
        categoryName: 'Mains',
        modifierGroups: [spiceGroup, addOns],
        allergens: [],
        preparationTime: 20,
        isAvailable: true,
        imageUrl: null,
        isVegetarian: false,
      ),
      MenuItemModel(
        id: 'i3',
        name: 'Cheesecake',
        description: 'Classic baked cheesecake',
        price: 180,
        categoryId: 'c3',
        categoryName: 'Desserts',
        modifierGroups: [],
        allergens: ['Dairy'],
        preparationTime: 0,
        isAvailable: true,
        imageUrl: null,
        isVegetarian: true,
      ),
      MenuItemModel(
        id: 'i4',
        name: 'Lemonade',
        description: 'Freshly squeezed',
        price: 90,
        categoryId: 'c4',
        categoryName: 'Beverages',
        modifierGroups: [],
        allergens: [],
        preparationTime: 2,
        isAvailable: true,
        imageUrl: null,
        isVegetarian: true,
      ),
    ];
  }
} 