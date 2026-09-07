import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class ProductCardWidget extends StatelessWidget {
  final GetProduct product;
  final VoidCallback onTap;
  final bool isSelected;
  final double? width;
  final double? height;

  const ProductCardWidget({
    Key? key,
    required this.product,
    required this.onTap,
    this.isSelected = false,
    this.width,
    this.height,
  }) : super(key: key);

  String? _getPrimaryImage() {
    if (product.attachment != null && product.attachment!.isNotEmpty) {
      // Look for primary image
      for (var attachment in product.attachment!) {
        if (attachment.isPrimary == 1) {
          return attachment.filePath;
        }
      }
      // If no primary image found, use the first one
      return product.attachment!.first.filePath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primaryImage = _getPrimaryImage();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: Container(
                      color: Colors.grey.shade50,
                      child: primaryImage != null
                          ? Image.network(
                              primaryImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.image_not_supported,
                                size: 24,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              size: 24,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  // Price indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                        ),
                      ),
                      child: Consumer<AppSettingsProvider>(
                        builder: (context, appSettingsProvider, _) {
                          final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
                          final amount = (product.price?.price ?? 0).toString();
                          return Text(
                            '$currency $amount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Selection indicator
                  if (isSelected)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        height: 16,
                        width: 16,
                        decoration: const BoxDecoration(
                          color: ColorManager.kPrimaryColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product name/unit
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                "${product.localizedName} / ${product.unit}",
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
