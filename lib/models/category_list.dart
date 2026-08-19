import 'dart:convert';

import 'package:pos_machine/models/pagination.dart';

CategoryListModel categoryListModelFromJson(String str) =>
    CategoryListModel.fromJson(json.decode(str));

String categoryListModelToJson(CategoryListModel data) =>
    json.encode(data.toJson());

class CategoryListModel {
  final List<Category>? category;
  final String? status;
  final Pagination? pagination;

  CategoryListModel({
    this.category,
    this.status,
    this.pagination,
  });

  factory CategoryListModel.fromJson(Map<String, dynamic> json) =>
      CategoryListModel(
        category: json["data"] == null
            ? []
            : List<Category>.from(
                json["data"].map((x) => Category.fromJson(x))),
        status: json["status"],
        pagination:
            json["meta"] == null ? null : Pagination.fromJson(json["meta"]),
      );

  Map<String, dynamic> toJson() => {
        "category": category == null
            ? []
            : List<dynamic>.from(category!.map((x) => x.toJson())),
        "status": status,
        "pagination": pagination?.toJson(),
      };
}

class Category {
  final int? categoryId;
  final String? categoryName;
  final Map<String, String>? translations;
  final String? categorySlug;
  final int? productsCount;
  final String? categoryImage;
  final String? categoryIcon;
  final ParentCategory? parent;
  final List<int> taxIds;

  Category({
    this.categoryId,
    this.categoryName,
    this.translations,
    this.categorySlug,
    this.productsCount,
    this.categoryImage,
    this.categoryIcon,
    this.parent,
    this.taxIds = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final translations = {
      for (var n in (json['names'] as List? ?? []))
        if (n['code'] != null && n['name'] != null)
          n['code'] as String: n['name'] as String
    };
    print('Category: ${json["name"]} | translations: $translations');

    final taxIdsList = <int>[];
    final categoryTaxes = json['category_taxes'];
    if (categoryTaxes is List) {
      for (final tax in categoryTaxes) {
        if (tax is Map<String, dynamic>) {
          final taxId = tax['tax_id'];
          if (taxId is int) {
            taxIdsList.add(taxId);
          } else if (taxId is String) {
            final parsed = int.tryParse(taxId);
            if (parsed != null) taxIdsList.add(parsed);
          }
        }
      }
    } else if (json['tax_ids'] is List) {
      for (final id in json['tax_ids']) {
        if (id is int) {
          taxIdsList.add(id);
        } else if (id is String) {
          final parsed = int.tryParse(id);
          if (parsed != null) taxIdsList.add(parsed);
        }
      }
    }

    return Category(
      categoryId: json["id"],
      categoryName: json["name"],
      translations: translations,
      categorySlug: json["slug"],
      productsCount: 0, // Assuming productsCount is not provided in the API
      categoryImage: json["image_url"], // Updated to match the new API
      categoryIcon: json["icon_url"], // Updated to match the new API
      parent: json["parent"] == null
          ? null
          : ParentCategory.fromJson(json["parent"]),
      taxIds: taxIdsList,
    );
  }

  Map<String, dynamic> toJson() => {
        "category_id": categoryId,
        "category_name": categoryName,
        "translations": translations,
        "category_slug": categorySlug,
        "products_count": productsCount,
        "category_image": categoryImage,
        "category_icon": categoryIcon,
        "parent": parent?.toJson(),
        "tax_ids": taxIds,
      };
}

class ParentCategory {
  final int? id;
  final String? name;

  ParentCategory({
    this.id,
    this.name,
  });

  factory ParentCategory.fromJson(Map<String, dynamic> json) => ParentCategory(
        id: json["id"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
      };
}
