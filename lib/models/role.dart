// To parse this JSON data, do
//
//     final roleModel = roleModelFromJson(jsonString);

import 'dart:convert';

RoleModel roleModelFromJson(String str) => RoleModel.fromJson(json.decode(str));

String roleModelToJson(RoleModel data) => json.encode(data.toJson());

class RoleModel {
  final String? status;
  final String? message;
  final RoleModelData? data;

  RoleModel({
    this.status,
    this.message,
    this.data,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : RoleModelData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class RoleModelData {
  final List<Role> roles;
  final Pagination pagination;

  RoleModelData({
    required this.roles,
    required this.pagination,
  });

  factory RoleModelData.fromJson(Map<String, dynamic> json) => RoleModelData(
        roles: List<Role>.from(json["roles"].map((x) => Role.fromJson(x))),
        pagination: Pagination.fromJson(json["pagination"]),
      );

  Map<String, dynamic> toJson() => {
        "roles": List<dynamic>.from(roles.map((x) => x.toJson())),
        "pagination": pagination.toJson(),
      };
}

class Role {
  final int id;
  final String name;
  final String originalName;
  final String guardName;
  final int permissionsCount;
  final List<String> permissions;
  final int companyId;
  final String companyName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Role({
    required this.id,
    required this.name,
    required this.originalName,
    required this.guardName,
    required this.permissionsCount,
    required this.permissions,
    required this.companyId,
    required this.companyName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json["id"],
        name: json["name"],
        originalName: json["original_name"],
        guardName: json["guard_name"],
        permissionsCount: json["permissions_count"],
        permissions: List<String>.from(json["permissions"].map((x) => x)),
        companyId: json["company_id"],
        companyName: json["company_name"],
        createdAt: DateTime.parse(json["created_at"]),
        updatedAt: DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "original_name": originalName,
        "guard_name": guardName,
        "permissions_count": permissionsCount,
        "permissions": List<dynamic>.from(permissions.map((x) => x)),
        "company_id": companyId,
        "company_name": companyName,
        "created_at": createdAt.toIso8601String(),
        "updated_at": updatedAt.toIso8601String(),
      };
}

class Pagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;

  Pagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: json["current_page"],
        lastPage: json["last_page"],
        perPage: json["per_page"],
        total: json["total"],
        from: json["from"],
        to: json["to"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "last_page": lastPage,
        "per_page": perPage,
        "total": total,
        "from": from,
        "to": to,
      };
}
