// To parse this JSON data, do
//
//     final viewCategoryModel = viewCategoryModelFromJson(jsonString);

import 'dart:convert';

ViewCategoryModel viewCategoryModelFromJson(String str) =>
    ViewCategoryModel.fromJson(json.decode(str));

String viewCategoryModelToJson(ViewCategoryModel data) =>
    json.encode(data.toJson());

class ViewCategoryModel {
  final String? status;
  final String? message;
  final ViewCategory? data;

  ViewCategoryModel({
    this.status,
    this.message,
    this.data,
  });

  factory ViewCategoryModel.fromJson(Map<String, dynamic> json) =>
      ViewCategoryModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : ViewCategory.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class ViewCategory {
  final int? id;
  final int? parentId;
  final String? name;
  final String? slug;
  final String? sort;
  final String? categoryImage;
  final String? categoryIcon;
  final dynamic userId;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? categoryImageFullPath;
  final String? categoryIconFullPath;
  final CategoryNames? names;

  ViewCategory({
    this.id,
    this.parentId,
    this.name,
    this.slug,
    this.sort,
    this.categoryImage,
    this.categoryIcon,
    this.userId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.categoryIconFullPath,
    this.categoryImageFullPath,
    this.names,
  });

  factory ViewCategory.fromJson(Map<String, dynamic> json) => ViewCategory(
        id: json["id"],
        parentId: json["parent_id"],
        name: json["name"],
        slug: json["slug"],
        sort: json["sort"],
        categoryImage: json["category_image"],
        categoryIcon: json["category_icon"],
        userId: json["user_id"],
        status: json["status"],
        categoryIconFullPath: json["category_icon_full_path"],
        categoryImageFullPath: json["category_image_full_path"],
        names: json["names"] == null
            ? null
            : CategoryNames.fromJson(json["names"]),
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "parent_id": parentId,
        "name": name,
        "slug": slug,
        "sort": sort,
        "category_image_full_path": categoryImageFullPath,
        "category_icon_full_path": categoryIconFullPath,
        "category_image": categoryImage,
        "category_icon": categoryIcon,
        "user_id": userId,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "names": names?.toJson(),
      };
}

class CategoryNames {
  final String? en;
  final String? hi;
  final String? ar;

  CategoryNames({
    this.en,
    this.hi,
    this.ar,
  });

  factory CategoryNames.fromJson(Map<String, dynamic> json) => CategoryNames(
        en: json["en"],
        hi: json["hi"],
        ar: json["ar"],
      );

  Map<String, dynamic> toJson() => {
        "en": en,
        "hi": hi,
        "ar": ar,
      };
}
