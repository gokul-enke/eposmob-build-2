import 'dart:convert';
import 'package:flutter/foundation.dart';

GetProductModel getProductModelFromJson(String str) =>
    GetProductModel.fromJson(json.decode(str));

String getProductModelToJson(GetProductModel data) =>
    json.encode(data.toJson());

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) {
    final lowered = value.toLowerCase();
    return lowered == '1' || lowered == 'true';
  }
  return null;
}

class GetProductModel {
  final List<GetProduct>? product;
  final String? status; // this field seems to be missing in your JSON
  final Links? links; // links field is currently unused
  final Meta? meta; // Rename pagination to meta
  final Pagination? pagination;

  GetProductModel({
    this.product,
    this.status,
    this.links,
    this.meta, // Update constructor accordingly
    this.pagination,
  });

  factory GetProductModel.fromJson(Map<String, dynamic> json) {
    try {
      final productData = json["product"] ?? json["products"] ?? json["data"];
      if (productData == null) {
        debugPrint(
            "⚠️ [GetProductModel] No 'product', 'products', or 'data' key found in JSON.");
        debugPrint("🔑 [GetProductModel] Available keys: ${json.keys}");
      }
      return GetProductModel(
        product: productData == null
            ? []
            : List<GetProduct>.from(
                productData.map((x) => GetProduct.fromJson(x))),
        status: json["status"]?.toString(),
        links: json["links"] == null ? null : Links.fromJson(json["links"]),
        meta: json["meta"] == null ? null : Meta.fromJson(json["meta"]),
        pagination: json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
      );
    } catch (e, stack) {
      debugPrint("❌ GetProductModel.fromJson error: $e");
      debugPrint("🔗 StackTrace: $stack");
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        "product": product == null
            ? []
            : List<dynamic>.from(product!.map((x) => x.toJson())),
        "status": status, // Don't forget to serialize status back
        "links": links?.toJson(), // Serialize links if necessary
        "meta": meta?.toJson(), // Update for meta
        "pagination": pagination?.toJson(),
      };
}

class GetProduct {
  final int? productId;
  final int? categoryId;
  final String? productName;
  final String? productSlug;
  final String? barcode;
  final ProductCategory? category;
  final String? numberOfProductsAvailable;
  final String? rating;
  final String? unit;
  final String? currency;
  final dynamic description;
  final ProductPrice? price;
  final dynamic mrp;
  final List<ProductTax>? taxes; // Restore taxes list
  final String? purchasePrice;
  final List<Attachment>? attachment;
  bool isSelected = false;
  final dynamic names; // Change to dynamic
  final List<ProductProp>? productProps;
  final WeightInfo? weightInfo;
  final List<Stock>? stock;
  final String? sku;
  final dynamic offerPrice;
  final dynamic productLocation;
  final String? hsnCode; // Added HSN code field
  final int? reorderLevel; // Reorder threshold level
  final bool? sellable; // Whether product can be sold
  final bool? purchasable; // Whether product can be purchased

  GetProduct({
    this.productId,
    this.categoryId,
    this.productName,
    this.productSlug,
    this.barcode,
    this.category,
    this.numberOfProductsAvailable,
    this.rating,
    this.price,
    this.mrp,
    this.taxes, // Restore taxes list
    this.purchasePrice,
    this.unit,
    this.currency,
    this.description,
    this.attachment,
    this.names,
    this.productProps,
    this.weightInfo,
    this.stock,
    this.sku,
    this.offerPrice,
    this.productLocation,
    this.hsnCode, // Added HSN code field
    this.reorderLevel,
    this.sellable,
    this.purchasable,
  });

  factory GetProduct.fromJson(Map<String, dynamic> json) {
    try {
      return GetProduct(
        productId: (() {
          final pid = json["product_id"] ?? json["id"];
          if (pid == null) return null;
          if (pid is int) return pid;
          if (pid is String) return int.tryParse(pid);
          return null;
        })(),
        categoryId: (() {
          final cid = json["category_id"] ?? json["categoryId"];
          if (cid == null) return null;
          if (cid is int) return cid;
          if (cid is String) return int.tryParse(cid);
          return null;
        })(),
        productName: json["product_name"] ?? json["name"] ?? json["title"],
        productSlug: json["product_slug"] ?? json["slug"],
        barcode: json["barcode"],
        category: json["category"] == null
            ? null
            : ProductCategory.fromJson(json["category"]),
        numberOfProductsAvailable:
            json["number_of_products_available"]?.toString(),
        rating: json["rating"]?.toString(),
        unit: json["unit"],
        currency: json["currency"],
        description: json["description"],
        price: (() {
          final p = json["price"];
          if (p == null) {
            final bp = json["base_price"] ?? json["selling_price"];
            return bp != null ? ProductPrice(price: bp.toString()) : null;
          }
          if (p is Map<String, dynamic>) {
            return ProductPrice.fromJson(p);
          }
          if (p is String || p is num) {
            return ProductPrice(price: p.toString());
          }
          return null;
        })(),
        mrp: json["mrp"]?.toString() ?? "",
        taxes: json["taxes"] == null
            ? []
            : List<ProductTax>.from((json["taxes"] as List)
                .map((x) => ProductTax.fromJson(x as Map<String, dynamic>))),
        purchasePrice: json["purchase_price"]?.toString() ??
            json["purchase_rate"]?.toString(),
        attachment: json["attachment"] == null
            ? []
            : List<Attachment>.from((json["attachment"] as List)
                .map((x) => Attachment.fromJson(x as Map<String, dynamic>))),
        names: json["names"],
        productProps: json["product_props"] == null
            ? []
            : List<ProductProp>.from((json["product_props"] as List)
                .map((x) => ProductProp.fromJson(x as Map<String, dynamic>))),
        weightInfo: json["weight_info"] == null
            ? null
            : WeightInfo.fromJson(json["weight_info"]),
        stock: json["stock"] == null
            ? []
            : List<Stock>.from((json["stock"] as List)
                .map((x) => Stock.fromJson(x as Map<String, dynamic>))),
        sku: json["sku"],
        offerPrice: json["offer_price"]?.toString(),
        productLocation: json["product_location"],
        hsnCode: json["hsn_code"],
        reorderLevel: (() {
          final rl = json["reorder_level"];
          if (rl == null) return null;
          if (rl is int) return rl;
          if (rl is String) return int.tryParse(rl);
          return null;
        })(),
        sellable: _parseBool(json["sellable"]),
        purchasable: _parseBool(json["purchasable"]),
      );
    } catch (e, stack) {
      debugPrint("❌ GetProduct.fromJson error: $e");
      debugPrint("📄 JSON causing error: $json");
      debugPrint("🔗 StackTrace: $stack");
      rethrow;
    }
  }

  double get totalTaxRate {
    if (taxes == null || taxes!.isEmpty) return 0.0;
    return taxes!.fold(
        0.0, (sum, tax) => sum + (double.tryParse(tax.rate ?? "0") ?? 0.0));
  }

  Map<String, dynamic> toJson() => {
        "product_id": productId,
        "category_id": categoryId,
        "product_name": productName,
        "product_slug": productSlug,
        "barcode": barcode,
        "category": category?.toJson(),
        "number_of_products_available": numberOfProductsAvailable,
        "rating": rating,
        "price": price?.toJson(),
        "mrp": mrp,
        "taxes": taxes == null
            ? []
            : List<dynamic>.from(taxes!.map((x) => x.toJson())),
        "purchase_price": purchasePrice,
        "unit": unit,
        "currency": currency,
        "description": description,
        "attachment": attachment == null
            ? []
            : List<dynamic>.from(attachment!.map((x) => x.toJson())),
        "names": names, // Don't try to cast or convert, just pass it as is
        "product_props": productProps == null
            ? []
            : List<dynamic>.from(productProps!.map((x) => x.toJson())),
        "weight_info": weightInfo?.toJson(),
        "stock": stock == null
            ? []
            : List<dynamic>.from(stock!.map((x) => x.toJson())),
        "sku": sku,
        "offer_price": offerPrice,
        "product_location": productLocation,
        "hsn_code": hsnCode, // Added HSN code field
        "reorder_level": reorderLevel,
        "sellable": sellable,
        "purchasable": purchasable,
      };
}

class WeightInfo {
  final double? weight; // Can be null
  final double? totalPrice; // Can be null (but might come as a string)
  final bool? isWeighted; // Can be null

  WeightInfo({
    this.weight,
    this.totalPrice,
    this.isWeighted,
  });

  factory WeightInfo.fromJson(Map<String, dynamic> json) => WeightInfo(
        weight: json["weight"]?.toDouble(), // Convert to double if not null
        totalPrice: json["total_price"] != null
            ? double.tryParse(
                json["total_price"].toString()) // Convert to double safely
            : null,
        isWeighted: _parseBool(json["is_weighted"]),
      );

  Map<String, dynamic> toJson() => {
        "weight": weight,
        "total_price": totalPrice,
        "is_weighted": isWeighted,
      };
}

class Attachment {
  final int? id;
  final int? productId;
  final int? userId;
  final String? title;
  final int? isPrimary;
  final String? fileType;
  final String? filePath;
  final String? status;
  final String? alt;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  final dynamic file;

  Attachment({
    this.id,
    this.productId,
    this.userId,
    this.title,
    this.isPrimary,
    this.fileType,
    this.filePath,
    this.status,
    this.alt,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.file,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json["id"],
        productId: json["product_id"],
        userId: json["user_id"],
        title: json["title"],
        isPrimary: json["is_primary"],
        fileType: json["file_type"],
        filePath: json["file_path"],
        status: json["status"],
        alt: json["alt"],
        description: json["description"],
        createdAt: json["created_at"],
        updatedAt: json["updated_at"],
        file: json["file"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "user_id": userId,
        "title": title,
        "is_primary": isPrimary,
        "file_type": fileType,
        "file_path": filePath,
        "status": status,
        "alt": alt,
        "description": description,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "file": file,
      };
}

class ProductCategory {
  final String? name;
  final String? slug;

  ProductCategory({
    this.name,
    this.slug,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        name: json["name"],
        slug: json["slug"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "slug": slug,
      };
}

class ProductPrice {
  final dynamic oldPrice;
  final dynamic price;
  final dynamic percentage;
  final dynamic totalPrice;

  ProductPrice({
    this.oldPrice,
    this.price,
    this.percentage,
    this.totalPrice,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) => ProductPrice(
        oldPrice: json["old_price"] ?? json["original_price"],
        price: json["base_price"] ?? json["price"] ?? json["selling_price"],
        percentage: json["percentage"],
        totalPrice: json["total_price"],
      );

  Map<String, dynamic> toJson() => {
        "old_price": oldPrice,
        "base_price": price,
        "percentage": percentage,
        "total_price": totalPrice,
      };
}

class Names {
  final String? en;
  final String? hi;
  final String? ar;

  Names({
    this.en,
    this.hi,
    this.ar,
  });

  factory Names.fromJson(Map<String, dynamic> json) => Names(
      en: json["en"] ?? json["EN"],
        hi: json["hi"],
      ar: json["ar"] ?? json["AR"],
      );

  Map<String, dynamic> toJson() => {
        "en": en,
        "hi": hi,
        "ar": ar,
      };
}

class ProductProp {
  final int? id;
  final int? categoryId;
  final String? propsCode;
  final String? label;
  final String? masterValue;
  final String? type;
  final int? propsId;
  final String? stockApplicable;

  ProductProp({
    this.id,
    this.categoryId,
    this.propsCode,
    this.label,
    this.masterValue,
    this.type,
    this.propsId,
    this.stockApplicable,
  });

  factory ProductProp.fromJson(Map<String, dynamic> json) => ProductProp(
        id: json["id"],
        categoryId: json["category_id"],
        propsCode: json["props_code"],
        label: json["label"],
        masterValue: json["master_value"],
        type: json["type"],
        propsId: json["props_id"],
        stockApplicable: json["stock_applicable"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "category_id": categoryId,
        "props_code": propsCode,
        "label": label,
        "master_value": masterValue,
        "type": type,
        "props_id": propsId,
        "stock_applicable": stockApplicable,
      };
}

class Links {
  final String? first;
  final String? last;
  final String? prev;
  final String? next;

  Links({this.first, this.last, this.prev, this.next});

  factory Links.fromJson(Map<String, dynamic> json) => Links(
        first: json["first"],
        last: json["last"],
        prev: json["prev"],
        next: json["next"],
      );

  Map<String, dynamic> toJson() => {
        "first": first,
        "last": last,
        "prev": prev,
        "next": next,
      };
}

class Meta {
  final int? currentPage;
  final int? lastPage;
  final int? total;

  Meta({
    this.currentPage,
    this.lastPage,
    this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
        currentPage: json["current_page"],
        lastPage: json["last_page"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "last_page": lastPage,
        "total": total,
      };
}

class Stock {
  final int? id;
  final int? productId;
  final String? supplier;
  final num? quantity;
  final String? price;
  final String? sku;
  final String? mrp;
  final String? unit;
  final String? purchasePrice;
  final String? date;
  final String? expiryDate;
  final String? rack;
  final String? hsnCode; // Added HSN code field

  Stock({
    this.id,
    this.productId,
    this.supplier,
    this.quantity,
    this.price,
    this.sku,
    this.mrp,
    this.unit,
    this.purchasePrice,
    this.date,
    this.expiryDate,
    this.rack,
    this.hsnCode, // Added HSN code field
  });

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
        id: json["id"] is String ? int.tryParse(json["id"]) : json["id"],
        productId: json["product_id"] is String
            ? int.tryParse(json["product_id"])
            : json["product_id"],
        supplier: json["supplier"]?.toString(),
        quantity: (() {
          final q = json["quantity"];
          if (q == null) return null;
          if (q is num) return q;
          if (q is String) {
            // Try int first, then double
            final i = int.tryParse(q);
            if (i != null) return i;
            final d = double.tryParse(q);
            if (d != null) return d;
          }
          return null;
        })(),
        price: json["price"]?.toString(),
        sku: json["sku"]?.toString(),
        mrp: json["mrp"]?.toString(),
        unit: json["unit"]?.toString(),
        purchasePrice: json["purchase_price"]?.toString(),
        date: json["date"]?.toString(),
        expiryDate: json["expiry_date"]?.toString(),
        rack: json["rack"]?.toString(),
        hsnCode: json["hsn_code"]?.toString(), // Added HSN code field
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "supplier": supplier,
        "quantity": quantity,
        "price": price,
        "sku": sku,
        "mrp": mrp,
        "unit": unit,
        "purchase_price": purchasePrice,
        "date": date,
        "expiry_date": expiryDate,
        "rack": rack,
        "hsn_code": hsnCode, // Added HSN code field
      };
}

class Pagination {
  final int? currentPage;
  final int? lastPage;
  final int? perPage;
  final int? total;

  Pagination({
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: json["current_page"],
        lastPage: json["last_page"],
        perPage: json["per_page"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "last_page": lastPage,
        "per_page": perPage,
        "total": total,
      };
}

class ProductTax {
  final int? id;
  final String? name;
  final String? code;
  final String? rate;
  final String? source;

  ProductTax({
    this.id,
    this.name,
    this.code,
    this.rate,
    this.source,
  });

  factory ProductTax.fromJson(Map<String, dynamic> json) => ProductTax(
        id: json["id"],
        name: json["name"],
        code: json["code"],
        rate: json["rate"]?.toString(),
        source: json["source"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "code": code,
        "rate": rate,
        "source": source,
      };
}
