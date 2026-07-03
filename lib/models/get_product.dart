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

Map<String, dynamic> _parseVariantAttributes(dynamic raw) {
  if (raw == null) return const {};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List) {
    final result = <String, dynamic>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final nameKey = map.containsKey('name')
          ? 'name'
          : map.containsKey('attribute')
              ? 'attribute'
              : map.containsKey('attribute_name')
                  ? 'attribute_name'
                  : map.containsKey('key')
                      ? 'key'
                      : null;
      if (nameKey != null && map.containsKey('value')) {
        final key = map[nameKey]?.toString();
        if (key != null && key.isNotEmpty) {
          result[key] = map['value'];
        }
        continue;
      }
      for (final entry in map.entries) {
        final key = entry.key.toString();
        if (key == 'id') continue;
        result[key] = entry.value;
      }
    }
    return result;
  }
  return const {};
}

class GetProductModel {
  final List<GetProduct>? product;
  final String? status; // this field seems to be missing in your JSON
  final Links? links; // links field is currently unused
  final Meta? meta; // Rename pagination to meta
  final Pagination? pagination;
  final List<int>? deletedProductIds;

  GetProductModel({
    this.product,
    this.status,
    this.links,
    this.meta, // Update constructor accordingly
    this.pagination,
    this.deletedProductIds,
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
        deletedProductIds: json["deleted_product_ids"] is List
            ? (json["deleted_product_ids"] as List)
                .map((e) {
                  if (e is int) return e;
                  return int.tryParse(e.toString());
                })
                .whereType<int>()
                .toList()
            : null,
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
        "deleted_product_ids": deletedProductIds,
      };
}

class GetProduct {
  final int? productId;
  final int? categoryId;
  final String? productName;
  final String? productSlug;
  final String? barcode;
  final String? itemCode;
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
  final dynamic minMarginPercentage;
  final dynamic minMarginPrice;
  final List<Attachment>? attachment;
  bool isSelected = false;
  final dynamic names; // Change to dynamic
  final List<ProductProp>? productProps;
  final WeightInfo? weightInfo;
  final List<Stock>? stock;
  final List<SaleUnit>? saleUnits;
  final List<ProductVariant>? variants;
  final String? sku;
  final dynamic offerPrice;
  final dynamic productLocation;
  final String? hsnCode; // Added HSN code field
  final int? reorderLevel; // Reorder threshold level
  final bool? sellable; // Whether product can be sold
  final bool? purchasable; // Whether product can be purchased
  final int? sortOrder;
  final bool? isOnlineProduct;

  GetProduct({
    this.productId,
    this.categoryId,
    this.productName,
    this.productSlug,
    this.barcode,
    this.itemCode,
    this.category,
    this.numberOfProductsAvailable,
    this.rating,
    this.price,
    this.mrp,
    this.taxes, // Restore taxes list
    this.purchasePrice,
    this.minMarginPercentage,
    this.minMarginPrice,
    this.unit,
    this.currency,
    this.description,
    this.attachment,
    this.names,
    this.productProps,
    this.weightInfo,
    this.stock,
    this.saleUnits,
    this.variants,
    this.sku,
    this.offerPrice,
    this.productLocation,
    this.hsnCode, // Added HSN code field
    this.reorderLevel,
    this.sellable,
    this.purchasable,
    this.sortOrder,
    this.isOnlineProduct,
  });

  GetProduct copyWith({
    int? productId,
    int? categoryId,
    String? productName,
    String? productSlug,
    String? barcode,
    String? itemCode,
    ProductCategory? category,
    String? numberOfProductsAvailable,
    String? rating,
    String? unit,
    String? currency,
    dynamic description,
    ProductPrice? price,
    dynamic mrp,
    List<ProductTax>? taxes,
    String? purchasePrice,
    dynamic minMarginPercentage,
    dynamic minMarginPrice,
    List<Attachment>? attachment,
    dynamic names,
    List<ProductProp>? productProps,
    WeightInfo? weightInfo,
    List<Stock>? stock,
    List<SaleUnit>? saleUnits,
    List<ProductVariant>? variants,
    String? sku,
    dynamic offerPrice,
    dynamic productLocation,
    String? hsnCode,
    int? reorderLevel,
    bool? sellable,
    bool? purchasable,
    int? sortOrder,
    bool? isOnlineProduct,
  }) {
    return GetProduct(
      productId: productId ?? this.productId,
      categoryId: categoryId ?? this.categoryId,
      productName: productName ?? this.productName,
      productSlug: productSlug ?? this.productSlug,
      barcode: barcode ?? this.barcode,
      itemCode: itemCode ?? this.itemCode,
      category: category ?? this.category,
      numberOfProductsAvailable:
          numberOfProductsAvailable ?? this.numberOfProductsAvailable,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      taxes: taxes ?? this.taxes,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      minMarginPercentage: minMarginPercentage ?? this.minMarginPercentage,
      minMarginPrice: minMarginPrice ?? this.minMarginPrice,
      unit: unit ?? this.unit,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      attachment: attachment ?? this.attachment,
      names: names ?? this.names,
      productProps: productProps ?? this.productProps,
      weightInfo: weightInfo ?? this.weightInfo,
      stock: stock ?? this.stock,
      saleUnits: saleUnits ?? this.saleUnits,
      variants: variants ?? this.variants,
      sku: sku ?? this.sku,
      offerPrice: offerPrice ?? this.offerPrice,
      productLocation: productLocation ?? this.productLocation,
      hsnCode: hsnCode ?? this.hsnCode,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      sellable: sellable ?? this.sellable,
      purchasable: purchasable ?? this.purchasable,
      sortOrder: sortOrder ?? this.sortOrder,
      isOnlineProduct: isOnlineProduct ?? this.isOnlineProduct,
    )..isSelected = isSelected;
  }

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
        itemCode: json["item_code"],
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
        minMarginPercentage: json["min_margin_percentage"],
        minMarginPrice: json["min_margin_price"],
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
        saleUnits: json["sale_units"] == null
            ? []
            : List<SaleUnit>.from((json["sale_units"] as List).map(
                (x) => SaleUnit.fromJson(x as Map<String, dynamic>),
              )),
        variants: json["variants"] == null
            ? []
            : List<ProductVariant>.from((json["variants"] as List).map(
                (x) => ProductVariant.fromJson(x as Map<String, dynamic>),
              )),
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
        sortOrder: (() {
          final so = json["sort_order"];
          if (so == null) return null;
          if (so is int) return so;
          return int.tryParse(so.toString());
        })(),
        isOnlineProduct: _parseBool(json["is_online_product"]),
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

  bool get hasVariants => variants != null && variants!.isNotEmpty;

  List<ProductVariant> get activeVariants =>
      variants?.where((variant) => variant.active).toList() ?? const [];

  Map<String, dynamic> toJson() => {
        "product_id": productId,
        "category_id": categoryId,
        "product_name": productName,
        "product_slug": productSlug,
        "barcode": barcode,
        "item_code": itemCode,
        "category": category?.toJson(),
        "number_of_products_available": numberOfProductsAvailable,
        "rating": rating,
        "price": price?.toJson(),
        "mrp": mrp,
        "taxes": taxes == null
            ? []
            : List<dynamic>.from(taxes!.map((x) => x.toJson())),
        "purchase_price": purchasePrice,
        "min_margin_percentage": minMarginPercentage,
        "min_margin_price": minMarginPrice,
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
        "sale_units": saleUnits == null
            ? []
            : List<dynamic>.from(saleUnits!.map((x) => x.toJson())),
        "variants": variants == null
            ? []
            : List<dynamic>.from(variants!.map((x) => x.toJson())),
        "sku": sku,
        "offer_price": offerPrice,
        "product_location": productLocation,
        "hsn_code": hsnCode, // Added HSN code field
        "reorder_level": reorderLevel,
        "sellable": sellable,
        "purchasable": purchasable,
        "sort_order": sortOrder,
        "is_online_product": isOnlineProduct,
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

class SaleUnit {
  final int? id;
  final int? unitId;
  final String? unitName;
  final String? conversionRate;
  final String? barcode;
  final double? price;

  /// Backend-resolved selling price for this unit on the default in-stock batch
  /// (already encodes the batch-override -> master -> base*conversion fallback).
  final double? resolvedPrice;

  SaleUnit({
    this.id,
    this.unitId,
    this.unitName,
    this.conversionRate,
    this.barcode,
    this.price,
    this.resolvedPrice,
  });

  /// Conversion rate as a positive number, or null when it cannot be parsed.
  double? get conversionRateValue {
    final parsed = double.tryParse(conversionRate?.trim() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  factory SaleUnit.fromJson(Map<String, dynamic> json) => SaleUnit(
        id: json["id"] is String ? int.tryParse(json["id"]) : json["id"],
        unitId: json["unit_id"] is String
            ? int.tryParse(json["unit_id"])
            : json["unit_id"],
        unitName: json["unit_name"]?.toString(),
        conversionRate: json["conversion_rate"]?.toString(),
        barcode: json["barcode"]?.toString(),
        price: _parseNullableDouble(json["price"]),
        resolvedPrice: _parseNullableDouble(json["resolved_price"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "unit_id": unitId,
        "unit_name": unitName,
        "conversion_rate": conversionRate,
        "barcode": barcode,
        "price": price,
        "resolved_price": resolvedPrice,
      };
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Parses batch `unit_prices` into a `{ sale_unit_id: price }` map.
///
/// Backends may send this as an object (`{"100": 1000.0}`) or as a list of
/// `{ "sale_unit_id": 100, "price": 1000.0 }` entries; both are supported.
Map<int, double>? _parseUnitPriceOverrides(dynamic value) {
  if (value == null) return null;
  final result = <int, double>{};

  void put(dynamic key, dynamic price) {
    final parsedKey = key is int ? key : int.tryParse(key?.toString() ?? '');
    final parsedPrice = _parseNullableDouble(price);
    if (parsedKey != null && parsedPrice != null) {
      result[parsedKey] = parsedPrice;
    }
  }

  if (value is Map) {
    value.forEach(put);
  } else if (value is List) {
    for (final entry in value) {
      if (entry is Map) {
        put(
          entry["sale_unit_id"] ?? entry["id"] ?? entry["unit_id"],
          entry["price"] ?? entry["unit_price"] ?? entry["value"],
        );
      }
    }
  }

  return result.isEmpty ? null : result;
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
  final int? storeId;
  final String? storeName;
  final String? supplier;
  final num? quantity;
  final String? price;
  final String? sku;
  final String? mrp;
  final String? unit;
  final String? taxRate;
  final String? purchasePrice;
  final String? date;
  final String? expiryDate;
  final String? pkgMfg;
  final String? rack;
  final String? hsnCode; // Added HSN code field
  final String? purchaseUnitId;
  final num? purchaseQty;
  final String? wholesalePrice;
  final int? wholesaleMinUnit;
  final bool? taxInclude;
  final bool? taxIncludePurchase;
  final List<dynamic>? unitPrices;

  /// Per-batch sale-unit price overrides keyed by `sale_unit_id`.
  /// Values are the price for ONE of that sale unit (e.g. price per Dozen).
  final Map<int, double>? unitPriceOverrides;

  /// Batch-specific override for the given [saleUnitId], or null when absent.
  double? unitPriceOverrideFor(int? saleUnitId) {
    if (saleUnitId == null) return null;
    return unitPriceOverrides?[saleUnitId];
  }

  Stock({
    this.id,
    this.productId,
    this.storeId,
    this.storeName,
    this.supplier,
    this.quantity,
    this.price,
    this.sku,
    this.mrp,
    this.unit,
    this.taxRate,
    this.purchasePrice,
    this.date,
    this.expiryDate,
    this.pkgMfg,
    this.rack,
    this.hsnCode, // Added HSN code field
    this.purchaseUnitId,
    this.purchaseQty,
    this.wholesalePrice,
    this.wholesaleMinUnit,
    this.taxInclude,
    this.taxIncludePurchase,
    this.unitPrices,
    this.unitPriceOverrides,
  });

  Stock copyWith({
    int? id,
    int? productId,
    int? storeId,
    String? storeName,
    String? supplier,
    num? quantity,
    String? price,
    String? sku,
    String? mrp,
    String? unit,
    String? taxRate,
    String? purchasePrice,
    String? date,
    String? expiryDate,
    String? pkgMfg,
    String? rack,
    String? hsnCode,
    String? purchaseUnitId,
    num? purchaseQty,
    String? wholesalePrice,
    int? wholesaleMinUnit,
    bool? taxInclude,
    bool? taxIncludePurchase,
    List<dynamic>? unitPrices,
    Map<int, double>? unitPriceOverrides,
  }) {
    return Stock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      supplier: supplier ?? this.supplier,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      mrp: mrp ?? this.mrp,
      unit: unit ?? this.unit,
      taxRate: taxRate ?? this.taxRate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      pkgMfg: pkgMfg ?? this.pkgMfg,
      rack: rack ?? this.rack,
      hsnCode: hsnCode ?? this.hsnCode,
      purchaseUnitId: purchaseUnitId ?? this.purchaseUnitId,
      purchaseQty: purchaseQty ?? this.purchaseQty,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinUnit: wholesaleMinUnit ?? this.wholesaleMinUnit,
      taxInclude: taxInclude ?? this.taxInclude,
      taxIncludePurchase: taxIncludePurchase ?? this.taxIncludePurchase,
      unitPrices: unitPrices ?? this.unitPrices,
      unitPriceOverrides: unitPriceOverrides ?? this.unitPriceOverrides,
    );
  }

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
        id: json["id"] is String ? int.tryParse(json["id"]) : json["id"],
        productId: json["product_id"] is String
            ? int.tryParse(json["product_id"])
            : json["product_id"],
        storeId: json["store_id"] is String
            ? int.tryParse(json["store_id"])
            : json["store_id"] ?? json["storeId"],
        storeName: json["store_name"]?.toString() ??
            json["store"]?.toString() ??
            json["storeName"]?.toString(),
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
        taxRate: json["tax_rate"]?.toString(),
        purchasePrice: json["purchase_price"]?.toString(),
        date: json["date"]?.toString(),
        expiryDate: json["expiry_date"]?.toString(),
        pkgMfg: json["pkg_mfg"]?.toString(),
        rack: json["rack"]?.toString(),
        hsnCode: json["hsn_code"]?.toString(), // Added HSN code field
        purchaseUnitId: json["purchase_unit_id"]?.toString(),
        purchaseQty: (() {
          final value = json["purchase_qty"];
          if (value == null) return null;
          if (value is num) return value;
          return num.tryParse(value.toString());
        })(),
        wholesalePrice: json["wholesale_price"]?.toString(),
        wholesaleMinUnit: (() {
          final value = json["wholesale_min_unit"];
          if (value == null) return null;
          if (value is int) return value;
          return int.tryParse(value.toString());
        })(),
        taxInclude: _parseBool(json["tax_include"]),
        taxIncludePurchase: _parseBool(json["tax_include_purchase"]),
        unitPrices: json["unit_prices"] is List
            ? List<dynamic>.from(json["unit_prices"])
            : null,
        unitPriceOverrides: _parseUnitPriceOverrides(json["unit_prices"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "product_id": productId,
        "store_id": storeId,
        "store_name": storeName,
        "supplier": supplier,
        "quantity": quantity,
        "price": price,
        "sku": sku,
        "mrp": mrp,
        "unit": unit,
        "tax_rate": taxRate,
        "purchase_price": purchasePrice,
        "date": date,
        "expiry_date": expiryDate,
        "pkg_mfg": pkgMfg,
        "rack": rack,
        "hsn_code": hsnCode, // Added HSN code field
        "purchase_unit_id": purchaseUnitId,
        "purchase_qty": purchaseQty,
        "wholesale_price": wholesalePrice,
        "wholesale_min_unit": wholesaleMinUnit,
        "tax_include": taxInclude,
        "tax_include_purchase": taxIncludePurchase,
        "unit_prices": unitPrices,
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

class ProductVariant {
  final int id;
  final String? sku;
  final String? barcode;
  final double? price;
  final double? mrp;
  final double? purchasePrice;
  final num? quantity;
  final bool active;
  final Map<String, dynamic> attributes;

  ProductVariant({
    required this.id,
    this.sku,
    this.barcode,
    this.price,
    this.mrp,
    this.purchasePrice,
    this.quantity,
    this.active = true,
    this.attributes = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: (() {
          final raw = json['id'];
          if (raw is int) return raw;
          if (raw is String) return int.tryParse(raw) ?? 0;
          return 0;
        })(),
        sku: json['sku']?.toString(),
        barcode: json['barcode']?.toString(),
        price: (() {
          final value = json['price'];
          if (value == null) return null;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        })(),
        mrp: (() {
          final value = json['mrp'];
          if (value == null) return null;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        })(),
        purchasePrice: (() {
          final value = json['purchase_price'];
          if (value == null) return null;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        })(),
        quantity: (() {
          final q = json['quantity'];
          if (q == null) return null;
          if (q is num) return q;
          if (q is String) {
            final i = int.tryParse(q);
            if (i != null) return i;
            final d = double.tryParse(q);
            if (d != null) return d;
          }
          return null;
        })(),
        active: _parseBool(json['active']) ?? true,
        attributes: _parseVariantAttributes(json['attributes']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'barcode': barcode,
        'price': price,
        'mrp': mrp,
        'purchase_price': purchasePrice,
        'quantity': quantity,
        'active': active,
        'attributes': attributes,
      };

  String get formattedAttributes =>
      attributes.values.map((value) => value.toString()).join(' | ');

  String displayName(String productName) {
    final attrs = formattedAttributes;
    return attrs.isEmpty ? productName : '$productName ($attrs)';
  }

  double effectivePrice(double productPrice) =>
      (price != null && price! > 0) ? price! : productPrice;
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
