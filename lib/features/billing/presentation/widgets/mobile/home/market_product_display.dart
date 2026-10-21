import 'package:pos_machine/helpers/product_image_helper.dart';
import 'package:pos_machine/models/get_product.dart';

/// Resolves the best network image URL for a market product card.
///
/// Prefers the primary attachment, then falls back to the first attachment.
/// Only returns values that look like remote URLs (http/https).
String? resolveMarketProductImageUrl(GetProduct product) =>
    resolveProductAttachmentImageUrl(product);

String formatMarketProductPrice(GetProduct product, String currency) {
  final rawPrice = product.price?.price?.toString() ?? '0';
  final parsed = double.tryParse(rawPrice) ?? 0;
  final prefix = currency.isEmpty ? '' : '$currency ';
  return '$prefix${parsed.toStringAsFixed(2)}';
}

String? resolveMarketProductCategory(GetProduct product) {
  final name = product.category?.name?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}
