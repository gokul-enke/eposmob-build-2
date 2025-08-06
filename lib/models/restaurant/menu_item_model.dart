class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String categoryName;
  final List<ModifierGroup> modifierGroups;
  final List<String> allergens;
  final int preparationTime; // in minutes
  final bool isAvailable;
  final String? imageUrl;
  final bool isVegetarian;
  final double? discountPercentage;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    required this.modifierGroups,
    required this.allergens,
    required this.preparationTime,
    required this.isAvailable,
    this.imageUrl,
    required this.isVegetarian,
    this.discountPercentage,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      modifierGroups: (json['modifierGroups'] as List<dynamic>?)
          ?.map((e) => ModifierGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      allergens: (json['allergens'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      preparationTime: json['preparationTime'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
      isVegetarian: json['isVegetarian'] as bool? ?? false,
      discountPercentage: json['discountPercentage'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'modifierGroups': modifierGroups.map((e) => e.toJson()).toList(),
      'allergens': allergens,
      'preparationTime': preparationTime,
      'isAvailable': isAvailable,
      'imageUrl': imageUrl,
      'isVegetarian': isVegetarian,
      'discountPercentage': discountPercentage,
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? categoryName,
    List<ModifierGroup>? modifierGroups,
    List<String>? allergens,
    int? preparationTime,
    bool? isAvailable,
    String? imageUrl,
    bool? isVegetarian,
    double? discountPercentage,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      modifierGroups: modifierGroups ?? this.modifierGroups,
      allergens: allergens ?? this.allergens,
      preparationTime: preparationTime ?? this.preparationTime,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }
}

class ModifierGroup {
  final String id;
  final String name;
  final List<ModifierOption> options;
  final bool isRequired;
  final int maxSelections;

  ModifierGroup({
    required this.id,
    required this.name,
    required this.options,
    required this.isRequired,
    required this.maxSelections,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => ModifierOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      isRequired: json['isRequired'] as bool? ?? false,
      maxSelections: json['maxSelections'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'options': options.map((e) => e.toJson()).toList(),
      'isRequired': isRequired,
      'maxSelections': maxSelections,
    };
  }
}

class ModifierOption {
  final String id;
  final String name;
  final double additionalPrice;
  final bool isDefault;

  ModifierOption({
    required this.id,
    required this.name,
    required this.additionalPrice,
    required this.isDefault,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: json['id'] as String,
      name: json['name'] as String,
      additionalPrice: (json['additionalPrice'] as num).toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'additionalPrice': additionalPrice,
      'isDefault': isDefault,
    };
  }
}

class CategoryModel {
  final String id;
  final String name;
  final int displayOrder;
  final String? parentId;

  CategoryModel({
    required this.id,
    required this.name,
    required this.displayOrder,
    this.parentId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
      parentId: json['parentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayOrder': displayOrder,
      'parentId': parentId,
    };
  }
} 