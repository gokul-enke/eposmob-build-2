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
                json["data"]["data"]!.map((x) => Category.fromJson(x))),
        status: json["status"],
        pagination:
            json["data"] == null ? null : Pagination.fromJson(json["data"]),
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

  Category({
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.productsCount,
    this.categoryImage,
    this.categoryIcon,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        categoryId: json["id"],
        categoryName: json["name"],
        categorySlug: json["slug"],
        productsCount: 0,
        categoryImage: json["category_image"],
        categoryIcon: json["category_icon"],
      );

  Map<String, dynamic> toJson() => {
        "category_id": categoryId,
        "category_name": categoryName,
        "category_slug": categorySlug,
        "products_count": productsCount,
        "category_image": categoryImage,
        "category_icon": categoryIcon,
      };
}
