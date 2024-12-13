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
  final String? categorySlug;
  final int? productsCount;
  final String? categoryImage;
  final String? categoryIcon;
  final ParentCategory? parent;

  Category({
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.productsCount,
    this.categoryImage,
    this.categoryIcon,
    this.parent,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        categoryId: json["id"],
        categoryName: json["name"],
        categorySlug: json["slug"],
        productsCount: 0, // Assuming productsCount is not provided in the API
        categoryImage: json["image_url"], // Updated to match the new API
        categoryIcon: json["icon_url"], // Updated to match the new API
        parent: json["parent"] == null
            ? null
            : ParentCategory.fromJson(json["parent"]),
      );

  Map<String, dynamic> toJson() => {
        "category_id": categoryId,
        "category_name": categoryName,
        "category_slug": categorySlug,
        "products_count": productsCount,
        "category_image": categoryImage,
        "category_icon": categoryIcon,
        "parent": parent?.toJson(),
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
