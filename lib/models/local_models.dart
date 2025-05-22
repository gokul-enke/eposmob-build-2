import 'package:hive/hive.dart';
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

  HiveLocalCartItem({
    required this.productId,
    this.quantity = 1,
    this.price,
    this.mrp,
    required this.serializedProduct,
    this.serializedSelectedStock,
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
  final List<HiveAttachment>? attachment;

  @HiveField(13)
  bool isSelected = false;

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
    this.unit,
    this.currency,
    this.description,
    this.attachment,
    this.isSelected = false,
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
      attachment: product.attachment
          ?.map((e) => HiveAttachment.fromAttachment(e))
          .toList(),
      isSelected: product.isSelected,
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
      attachment: attachment?.map((e) => e.toAttachment()).toList(),
    )..isSelected = isSelected;
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
    );
  }
}
