import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:pos_machine/models/category_list.dart';
import '../models/get_product.dart';

part 'local_models.g.dart';

// Simple String adapter for complex models
@HiveType(typeId: 0)
class HiveStringValue {
  @HiveField(0)
  final String value;

  HiveStringValue(this.value);
}

@HiveType(typeId: 1)
class HiveLocalCartItem {
  @HiveField(0)
  final int productId;

  @HiveField(1)
  double? price;

  @HiveField(2)
  num quantity;

  @HiveField(3)
  double? mrp;

  // Store serialized product as JSON string
  @HiveField(4)
  final HiveStringValue serializedProduct;

  // Store serialized selected stock as JSON string
  @HiveField(5)
  final HiveStringValue? serializedSelectedStock;

  @HiveField(6)
  double? taxAmount;

  @HiveField(7)
  double? taxRate;

  @HiveField(8)
  num stockDeducted;

  @HiveField(9)
  String? comment;

  @HiveField(10)
  final HiveStringValue? serializedStockGroupIds;

  @HiveField(11)
  final HiveStringValue? serializedStockReservations;

  @HiveField(12)
  final bool isManualPriceOverride;

  @HiveField(13)
  final int? saleUnitId;

  @HiveField(14)
  final String? saleUnitName;

  @HiveField(15)
  final double? saleUnitConversionRate;

  @HiveField(16)
  final int? variantId;

  @HiveField(17)
  final HiveStringValue? serializedVariantAttributes;

  HiveLocalCartItem({
    required this.productId,
    this.quantity = 1,
    this.price,
    this.mrp,
    this.taxAmount,
    this.taxRate,
    required this.serializedProduct,
    this.serializedSelectedStock,
    this.stockDeducted = 0,
    this.comment,
    this.serializedStockGroupIds,
    this.serializedStockReservations,
    this.isManualPriceOverride = false,
    this.saleUnitId,
    this.saleUnitName,
    this.saleUnitConversionRate,
    this.variantId,
    this.serializedVariantAttributes,
  });
}

@HiveType(typeId: 2)
class HiveSavedOrder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orderNumber;

  @HiveField(2)
  final List<HiveLocalCartItem> items;

  @HiveField(3)
  final String? customerName;

  @HiveField(4)
  final String? customerPhone;

  @HiveField(5)
  final String? comment;

  @HiveField(6)
  final String createdAt;

  @HiveField(7)
  final double total;

  @HiveField(8)
  final String? deliveryMethod;

  // New fields for API compatibility
  @HiveField(9)
  final int? customerId;

  @HiveField(10)
  final String? paymentMethod;

  @HiveField(11)
  final String? paidAmount;

  @HiveField(12)
  final String? balanceAmount;

  @HiveField(13)
  final String? transactionId;

  @HiveField(14)
  final String? couponId;

  @HiveField(15)
  final String? deliveryMethodId;

  @HiveField(16)
  final String? carNumber;

  @HiveField(17)
  final String? status;

  @HiveField(18)
  final String? deliveryDate;

  @HiveField(19)
  final String? deliveryTime;

  @HiveField(20)
  final double? flatDiscount;

  @HiveField(21)
  final double? percentageDiscount;

  @HiveField(22)
  final bool? toCustomerCredit;

  // Table association for restaurant drafts (optional)
  @HiveField(23)
  final String? tableId;

  @HiveField(24)
  final String? alternatePhone;

  @HiveField(25)
  final String? address;

  @HiveField(26)
  final double? deliveryCharge;

  @HiveField(27)
  final String? customerVatNumber;

  @HiveField(28)
  final String? customerCrNumber;

  @HiveField(29)
  final String? customerType;

  HiveSavedOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.comment,
    required this.createdAt,
    required this.total,
    this.deliveryMethod,
    // New API-compatible fields
    this.customerId,
    this.paymentMethod,
    this.paidAmount,
    this.balanceAmount,
    this.transactionId,
    this.couponId,
    this.deliveryMethodId,
    this.carNumber,
    this.status,
    this.deliveryDate,
    this.deliveryTime,
    this.flatDiscount,
    this.percentageDiscount,
    this.toCustomerCredit,
    this.tableId,
    this.alternatePhone,
    this.address,
    this.deliveryCharge,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
  });
}

// Product Storage model (simplified for Hive)
@HiveType(typeId: 3)
class HiveProduct extends HiveObject {
  @HiveField(0)
  final int? productId;

  @HiveField(1)
  final int? categoryId;

  @HiveField(2)
  final String? productName;

  @HiveField(3)
  final String? barcode;

  @HiveField(4)
  final HiveStringValue serializedData;

  HiveProduct({
    this.productId,
    this.categoryId,
    this.productName,
    this.barcode,
    required this.serializedData,
  });
}

// Adapters for GetProduct model classes
@HiveType(typeId: 4)
class HiveGetProduct extends HiveObject {
  @HiveField(0)
  final int? productId;

  @HiveField(1)
  final int? categoryId;

  @HiveField(2)
  final String? productName;

  @HiveField(3)
  final String? productSlug;

  @HiveField(4)
  final String? barcode;

  @HiveField(5)
  final HiveProductCategory? category;

  @HiveField(6)
  final String? numberOfProductsAvailable;

  @HiveField(7)
  final String? rating;

  @HiveField(8)
  final String? unit;

  @HiveField(9)
  final String? currency;

  @HiveField(10)
  final String? description;

  @HiveField(11)
  final HiveProductPrice? price;

  @HiveField(12)
  final String? mrp;

  @HiveField(13)
  final String? purchasePrice;

  @HiveField(14)
  final List<HiveAttachment>? attachment;

  @HiveField(15)
  final String? sku;

  @HiveField(16)
  bool isSelected = false;

  @HiveField(17)
  final String? offerPrice;

  @HiveField(18)
  final String? productLocation;

  @HiveField(19)
  final String? totalTaxRate; // Restore totalTaxRate field

  @HiveField(20)
  final List<HiveProductTax>? taxes;

  @HiveField(21)
  final String? itemCode;

  @HiveField(22)
  final String? minMarginPercentage;

  @HiveField(23)
  final String? minMarginPrice;

  HiveGetProduct({
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
    this.purchasePrice,
    this.unit,
    this.currency,
    this.description,
    this.attachment,
    this.sku,
    this.isSelected = false,
    this.offerPrice,
    this.productLocation,
    this.totalTaxRate,
    this.taxes,
    this.itemCode,
    this.minMarginPercentage,
    this.minMarginPrice,
  });

  // Convert from app model to Hive model
  factory HiveGetProduct.fromGetProduct(GetProduct product) {
    return HiveGetProduct(
      productId: product.productId,
      categoryId: product.categoryId,
      productName: product.productName,
      productSlug: product.productSlug,
      barcode: product.barcode,
      category: product.category != null
          ? HiveProductCategory.fromProductCategory(product.category!)
          : null,
      numberOfProductsAvailable: product.numberOfProductsAvailable,
      rating: product.rating,
      unit: product.unit,
      currency: product.currency,
      description: product.description?.toString(),
      price: product.price != null
          ? HiveProductPrice.fromProductPrice(product.price!)
          : null,
      mrp: product.mrp?.toString(),
      purchasePrice: product.purchasePrice,
      attachment: product.attachment
          ?.map((e) => HiveAttachment.fromAttachment(e))
          .toList(),
      sku: product.sku,
      isSelected: product.isSelected,
      offerPrice: product.offerPrice?.toString(),
      productLocation: product.productLocation?.toString(),
      totalTaxRate: product.totalTaxRate.toString(),
      taxes: product.taxes != null && product.taxes!.isNotEmpty
          ? product.taxes!.map((t) => HiveProductTax.fromProductTax(t)).toList()
          : [],
      itemCode: product.itemCode,
      minMarginPercentage: product.minMarginPercentage?.toString(),
      minMarginPrice: product.minMarginPrice?.toString(),
    );
  }

  // Convert back to app model
  GetProduct toGetProduct() {
    return GetProduct(
      productId: productId,
      categoryId: categoryId,
      productName: productName,
      productSlug: productSlug,
      barcode: barcode,
      category: category?.toProductCategory(),
      numberOfProductsAvailable: numberOfProductsAvailable,
      rating: rating,
      unit: unit,
      currency: currency,
      description: description,
      price: price?.toProductPrice(),
      mrp: mrp,
      purchasePrice: purchasePrice,
      attachment: attachment?.map((att) => att.toAttachment()).toList(),
      sku: sku,
      offerPrice: offerPrice,
      productLocation: productLocation,
      // Restore taxes!
      taxes: taxes?.map((t) => t.toProductTax()).toList() ?? [],
      itemCode: itemCode,
      minMarginPercentage: minMarginPercentage,
      minMarginPrice: minMarginPrice,
    )..isSelected = isSelected;
  }
}

// ... existing classes ...

// Document Configuration Storage model for Hive
@HiveType(typeId: 10)
class HiveDocumentConfig {
  @HiveField(0)
  final String? serializedData;

  HiveDocumentConfig(this.serializedData);

  // Convert from app model to Hive model
  factory HiveDocumentConfig.fromDocumentConfig(Map<String, dynamic> config) {
    return HiveDocumentConfig(json.encode(config));
  }

  // Convert back to app model (raw Map, not DocumentConfig to avoid circular dependency)
  Map<String, dynamic> toJson() {
    if (serializedData == null || serializedData!.isEmpty) {
      return {};
    }
    return json.decode(serializedData!) as Map<String, dynamic>;
  }
}

@HiveType(typeId: 11)
class HiveProductTax {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? code;

  @HiveField(3)
  final String? rate;

  @HiveField(4)
  final String? source;

  HiveProductTax({
    this.id,
    this.name,
    this.code,
    this.rate,
    this.source,
  });

  factory HiveProductTax.fromProductTax(ProductTax tax) {
    return HiveProductTax(
      id: tax.id,
      name: tax.name,
      code: tax.code,
      rate: tax.rate,
      source: tax.source,
    );
  }

  ProductTax toProductTax() {
    return ProductTax(
      id: id,
      name: name,
      code: code,
      rate: rate,
      source: source,
    );
  }
}

@HiveType(typeId: 5)
class HiveProductCategory extends HiveObject {
  @HiveField(0)
  final String? name;

  @HiveField(1)
  final String? slug;

  HiveProductCategory({
    this.name,
    this.slug,
  });

  factory HiveProductCategory.fromProductCategory(ProductCategory category) {
    return HiveProductCategory(
      name: category.name,
      slug: category.slug,
    );
  }

  ProductCategory toProductCategory() {
    return ProductCategory(
      name: name,
      slug: slug,
    );
  }
}

@HiveType(typeId: 6)
class HiveProductPrice extends HiveObject {
  @HiveField(0)
  final String? oldPrice;

  @HiveField(1)
  final String? price;

  @HiveField(2)
  final String? percentage;

  @HiveField(3)
  final String? totalPrice;

  HiveProductPrice({
    this.oldPrice,
    this.price,
    this.percentage,
    this.totalPrice,
  });

  factory HiveProductPrice.fromProductPrice(ProductPrice productPrice) {
    return HiveProductPrice(
      oldPrice: productPrice.oldPrice?.toString(),
      price: productPrice.price?.toString(),
      percentage: productPrice.percentage?.toString(),
      totalPrice: productPrice.totalPrice?.toString(),
    );
  }

  ProductPrice toProductPrice() {
    return ProductPrice(
      oldPrice: oldPrice,
      price: price,
      percentage: percentage,
      totalPrice: totalPrice,
    );
  }
}

@HiveType(typeId: 7)
class HiveAttachment extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final int? productId;

  @HiveField(2)
  final int? userId;

  @HiveField(3)
  final String? title;

  @HiveField(4)
  final int? isPrimary;

  @HiveField(5)
  final String? fileType;

  @HiveField(6)
  final String? filePath;

  @HiveField(7)
  final String? status;

  @HiveField(8)
  final String? alt;

  @HiveField(9)
  final String? description;

  @HiveField(10)
  final String? createdAt;

  @HiveField(11)
  final String? updatedAt;

  @HiveField(12)
  final String? file;

  HiveAttachment({
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

  factory HiveAttachment.fromAttachment(Attachment attachment) {
    return HiveAttachment(
      id: attachment.id,
      productId: attachment.productId,
      userId: attachment.userId,
      title: attachment.title,
      isPrimary: attachment.isPrimary,
      fileType: attachment.fileType,
      filePath: attachment.filePath,
      status: attachment.status,
      alt: attachment.alt,
      description: attachment.description,
      createdAt: attachment.createdAt,
      updatedAt: attachment.updatedAt,
      file: attachment.file?.toString(),
    );
  }

  Attachment toAttachment() {
    return Attachment(
      id: id,
      productId: productId,
      userId: userId,
      title: title,
      isPrimary: isPrimary,
      fileType: fileType,
      filePath: filePath,
      status: status,
      alt: alt,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      file: file,
    );
  }
}

// Category Storage model for Hive
@HiveType(typeId: 8)
class HiveCategory extends HiveObject {
  @HiveField(0)
  final int? categoryId;

  @HiveField(1)
  final String? categoryName;

  @HiveField(2)
  final String? categorySlug;

  @HiveField(3)
  final int? productsCount;

  @HiveField(4)
  final String? categoryImage;

  @HiveField(5)
  final String? categoryIcon;

  @HiveField(6)
  final HiveParentCategory? parent;

  HiveCategory({
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.productsCount,
    this.categoryImage,
    this.categoryIcon,
    this.parent,
  });

  // Convert from app model to Hive model
  factory HiveCategory.fromCategory(Category category) {
    return HiveCategory(
      categoryId: category.categoryId,
      categoryName: category.categoryName,
      categorySlug: category.categorySlug,
      productsCount: category.productsCount,
      categoryImage: category.categoryImage,
      categoryIcon: category.categoryIcon,
      parent: category.parent != null
          ? HiveParentCategory.fromParentCategory(category.parent!)
          : null,
    );
  }

  // Convert back to app model
  Category toCategory() {
    return Category(
      categoryId: categoryId,
      categoryName: categoryName,
      categorySlug: categorySlug,
      productsCount: productsCount,
      categoryImage: categoryImage,
      categoryIcon: categoryIcon,
      parent: parent?.toParentCategory(),
    );
  }
}

@HiveType(typeId: 9)
class HiveParentCategory extends HiveObject {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String? name;

  HiveParentCategory({
    this.id,
    this.name,
  });

  factory HiveParentCategory.fromParentCategory(ParentCategory parentCategory) {
    return HiveParentCategory(
      id: parentCategory.id,
      name: parentCategory.name,
    );
  }

  ParentCategory toParentCategory() {
    return ParentCategory(
      id: id,
      name: name,
    );
  }
}
