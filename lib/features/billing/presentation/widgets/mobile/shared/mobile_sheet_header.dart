import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/product_image.dart';

/// Standard top chrome for mobile bottom sheets: drag handle, optional
/// thumbnail, title + subtitle, and a close button.
///
/// Used by the mobile product details sheet and reusable across other mobile
/// sheets that need a consistent, scannable header.
class MobileSheetHeader extends StatelessWidget {
  const MobileSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.thumbnail,
    this.onClose,
    this.showDragHandle = true,
    this.closeTooltip,
  });

  final String title;
  final String? subtitle;
  final Widget? thumbnail;
  final VoidCallback? onClose;
  final bool showDragHandle;
  final String? closeTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) _buildDragHandle(),
          if (showDragHandle) const SizedBox(height: 10),
          Row(
            children: [
              if (thumbnail != null) ...[
                thumbnail!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: closeTooltip ?? 'general.close'.tr,
                  onPressed: onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: ColorManager.kGreyColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Builds a product/category thumbnail, with an initials avatar as placeholder.
Widget buildProductThumbnail({
  required GetProduct product,
  double size = 44,
}) {
  final initials = _initials(product.productName ?? '');

  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: ProductImage(
        product: product,
        placeholder: _initialsAvatar(initials, size),
      ),
    ),
  );
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].characters.first.toUpperCase();
  return '${parts[0].characters.first}${parts[1].characters.first}'
      .toUpperCase();
}

Widget _initialsAvatar(String initials, double size) {
  return Container(
    width: size,
    height: size,
    color: ColorManager.kPrimaryWithOpacity10,
    alignment: Alignment.center,
    child: FittedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColorManager.kPrimaryColor,
          ),
        ),
      ),
    ),
  );
}
