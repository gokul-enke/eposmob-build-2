import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

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
    this.closeTooltip = 'Close',
  });

  final String title;
  final String? subtitle;
  final Widget? thumbnail;
  final VoidCallback? onClose;
  final bool showDragHandle;
  final String closeTooltip;

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
                  tooltip: closeTooltip,
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

/// Builds a square product thumbnail that prefers the primary attachment image
/// and falls back to an initials avatar. Returns `null` when no thumbnail is
/// wanted (e.g. callers may pass their own widget to [MobileSheetHeader]).
Widget? buildProductThumbnail({
  required String? productName,
  required List<dynamic>? attachments,
  double size = 44,
}) {
  String? imageUrl;
  if (attachments != null && attachments.isNotEmpty) {
    for (final attachment in attachments) {
      final path = attachment?.filePath;
      final isPrimary = attachment?.isPrimary == 1;
      if (isPrimary && path != null && path.isNotEmpty) {
        imageUrl = path;
        break;
      }
    }
    imageUrl ??= attachments.first?.filePath;
  }

  final initials = _initials(productName ?? '');

  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsAvatar(initials, size),
            )
          : _initialsAvatar(initials, size),
    ),
  );
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
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
