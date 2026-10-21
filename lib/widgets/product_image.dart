import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/product_image_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:provider/provider.dart';

/// Displays the product image, its category image, then the caller's placeholder.
/// Category URLs come from cached data and update when categories finish loading.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
  });

  final GetProduct product;
  final Widget placeholder;
  final BoxFit fit;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final categoryImageUrl = usableProductImageUrl(
      context.select<CategoryProvider?, String?>(
        (provider) =>
            provider?.findCategoryById(product.categoryId)?.categoryImage,
      ),
    );
    final productImageUrl = resolveProductAttachmentImageUrl(product);

    Widget categoryImage() {
      if (categoryImageUrl == null || categoryImageUrl == productImageUrl) {
        return placeholder;
      }
      return Image.network(
        categoryImageUrl,
        fit: fit,
        loadingBuilder: loadingBuilder,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    if (productImageUrl == null) return categoryImage();
    return Image.network(
      productImageUrl,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: (_, __, ___) => categoryImage(),
    );
  }
}
