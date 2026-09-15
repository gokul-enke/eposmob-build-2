import 'package:flutter/material.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskCategorySelector extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool vertical;

  const KioskCategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final options = <Category?>[null, ...categories];
    if (vertical) {
      return Container(
        width: 224,
        padding: const EdgeInsets.all(KioskSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(KioskRadius.card),
          border: Border.all(color: const Color(0xFFE2E9F3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                KioskSpacing.sm,
                KioskSpacing.xs,
                KioskSpacing.sm,
                KioskSpacing.md,
              ),
              child: Text(
                'CATEGORIES',
                style: TextStyle(
                  color: ColorManager.kGreyColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: KioskSpacing.xs),
                itemBuilder: (_, index) {
                  final category = options[index];
                  return _CategoryButton(
                    category: category,
                    selected: _isSelected(category),
                    onPressed: () => onSelected(category?.categoryId),
                    expanded: true,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: KioskSpacing.sm),
        itemBuilder: (_, index) {
          final category = options[index];
          return _CategoryButton(
            category: category,
            selected: _isSelected(category),
            onPressed: () => onSelected(category?.categoryId),
          );
        },
      ),
    );
  }

  bool _isSelected(Category? category) {
    return category == null
        ? selectedId == null
        : category.categoryId == selectedId;
  }
}

class _CategoryButton extends StatelessWidget {
  final Category? category;
  final bool selected;
  final VoidCallback onPressed;
  final bool expanded;

  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onPressed,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : ColorManager.kTitleTextColor;
    final label = Text(
      category?.categoryName?.trim().isNotEmpty == true
          ? category!.categoryName!.trim()
          : 'All products',
      maxLines: expanded ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: KioskType.label.copyWith(
        color: foreground,
        fontSize: 15,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: expanded ? 68 : 56,
      child: Material(
        color: selected ? ColorManager.kPrimaryColor : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(KioskRadius.control),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(KioskRadius.control),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 15 : 17),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                _CategoryIcon(category: category, color: foreground),
                const SizedBox(width: KioskSpacing.sm),
                if (expanded)
                  Expanded(child: label)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final Category? category;
  final Color color;

  const _CategoryIcon({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _categoryImageUrl(category);
    if (imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.network(
          imageUrl,
          width: 26,
          height: 26,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.category_outlined,
            color: color,
            size: 24,
          ),
        ),
      );
    }
    return Icon(
      category == null ? Icons.grid_view_rounded : Icons.category_outlined,
      color: color,
      size: 24,
    );
  }
}

String? _categoryImageUrl(Category? category) {
  final candidates = <String?>[
    category?.categoryImage,
    category?.categoryIcon,
  ];
  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value != null &&
        (value.startsWith('http://') || value.startsWith('https://'))) {
      return value;
    }
  }
  return null;
}
