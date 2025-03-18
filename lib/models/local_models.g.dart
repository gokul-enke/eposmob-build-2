// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveStringValueAdapter extends TypeAdapter<HiveStringValue> {
  @override
  final int typeId = 0;

  @override
  HiveStringValue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveStringValue(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HiveStringValue obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveStringValueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveLocalCartItemAdapter extends TypeAdapter<HiveLocalCartItem> {
  @override
  final int typeId = 1;

  @override
  HiveLocalCartItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveLocalCartItem(
      productId: fields[0] as int,
      quantity: fields[2] as num,
      price: fields[1] as double?,
      serializedProduct: fields[3] as HiveStringValue,
    );
  }

  @override
  void write(BinaryWriter writer, HiveLocalCartItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.serializedProduct);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveLocalCartItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveSavedOrderAdapter extends TypeAdapter<HiveSavedOrder> {
  @override
  final int typeId = 2;

  @override
  HiveSavedOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveSavedOrder(
      id: fields[0] as String,
      orderNumber: fields[1] as String,
      items: (fields[2] as List).cast<HiveLocalCartItem>(),
      customerName: fields[3] as String?,
      customerPhone: fields[4] as String?,
      comment: fields[5] as String?,
      createdAt: fields[6] as String,
      total: fields[7] as double,
      deliveryMethod: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveSavedOrder obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderNumber)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.customerPhone)
      ..writeByte(5)
      ..write(obj.comment)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.total)
      ..writeByte(8)
      ..write(obj.deliveryMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveSavedOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveProductAdapter extends TypeAdapter<HiveProduct> {
  @override
  final int typeId = 3;

  @override
  HiveProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveProduct(
      productId: fields[0] as int?,
      categoryId: fields[1] as int?,
      productName: fields[2] as String?,
      barcode: fields[3] as String?,
      serializedData: fields[4] as HiveStringValue,
    );
  }

  @override
  void write(BinaryWriter writer, HiveProduct obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.serializedData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveGetProductAdapter extends TypeAdapter<HiveGetProduct> {
  @override
  final int typeId = 4;

  @override
  HiveGetProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveGetProduct(
      productId: fields[0] as int?,
      categoryId: fields[1] as int?,
      productName: fields[2] as String?,
      productSlug: fields[3] as String?,
      barcode: fields[4] as String?,
      category: fields[5] as HiveProductCategory?,
      numberOfProductsAvailble: fields[6] as String?,
      rating: fields[7] as String?,
      price: fields[11] as HiveProductPrice?,
      unit: fields[8] as String?,
      currency: fields[9] as String?,
      description: fields[10] as String?,
      attachment: (fields[12] as List?)?.cast<HiveAttachment>(),
      isSelected: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveGetProduct obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.productSlug)
      ..writeByte(4)
      ..write(obj.barcode)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.numberOfProductsAvailble)
      ..writeByte(7)
      ..write(obj.rating)
      ..writeByte(8)
      ..write(obj.unit)
      ..writeByte(9)
      ..write(obj.currency)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.price)
      ..writeByte(12)
      ..write(obj.attachment)
      ..writeByte(13)
      ..write(obj.isSelected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveGetProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveProductCategoryAdapter extends TypeAdapter<HiveProductCategory> {
  @override
  final int typeId = 5;

  @override
  HiveProductCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveProductCategory(
      name: fields[0] as String?,
      slug: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveProductCategory obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.slug);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveProductCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveProductPriceAdapter extends TypeAdapter<HiveProductPrice> {
  @override
  final int typeId = 6;

  @override
  HiveProductPrice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveProductPrice(
      oldPrice: fields[0] as String?,
      price: fields[1] as String?,
      percentage: fields[2] as String?,
      totalPrice: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveProductPrice obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.oldPrice)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.percentage)
      ..writeByte(3)
      ..write(obj.totalPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveProductPriceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveAttachmentAdapter extends TypeAdapter<HiveAttachment> {
  @override
  final int typeId = 7;

  @override
  HiveAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveAttachment(
      id: fields[0] as int?,
      productId: fields[1] as int?,
      userId: fields[2] as int?,
      title: fields[3] as String?,
      isPrimary: fields[4] as int?,
      fileType: fields[5] as String?,
      filePath: fields[6] as String?,
      status: fields[7] as String?,
      alt: fields[8] as String?,
      description: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveAttachment obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.isPrimary)
      ..writeByte(5)
      ..write(obj.fileType)
      ..writeByte(6)
      ..write(obj.filePath)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.alt)
      ..writeByte(9)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
