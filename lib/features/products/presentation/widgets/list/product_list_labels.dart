import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';

abstract final class ProductListLabels {
  static String value(Object? value) => value?.toString() ?? 'product.na'.tr;
  static String name(GetProduct p) => p.productName ?? 'product.unnamed'.tr;
  static String category(GetProduct p) => p.category == null
      ? 'product.no_category'.tr
      : p.category!.name ?? 'general.unknown'.tr;
  static Object? purchasePrice(GetProduct p) =>
      p.purchasePrice ??
      (p.stock?.isNotEmpty == true ? p.stock!.first.purchasePrice : null);
}
