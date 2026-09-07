import 'package:flutter/material.dart';
import 'package:pos_machine/models/category_list.dart';
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
    if (vertical) {
      return Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListView.separated(
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _CategoryButton(
            category: index == 0 ? null : categories[index - 1],
            selected: index == 0
                ? selectedId == null
                : categories[index - 1].categoryId == selectedId,
            onPressed: () => onSelected(
              index == 0 ? null : categories[index - 1].categoryId,
            ),
            expanded: true,
          ),
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => _CategoryButton(
          category: index == 0 ? null : categories[index - 1],
          selected: index == 0
              ? selectedId == null
              : categories[index - 1].categoryId == selectedId,
          onPressed: () => onSelected(
            index == 0 ? null : categories[index - 1].categoryId,
          ),
        ),
      ),
    );
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
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: 64,
      child: Material(
        color: selected ? ColorManager.kPrimaryColor : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color:
                selected ? ColorManager.kPrimaryColor : const Color(0xFFDDE3EF),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                _CategoryIcon(category: category, color: foreground),
                const SizedBox(width: 12),
                Text(
                  category?.categoryName?.trim().isNotEmpty == true
                      ? category!.categoryName!.trim()
                      : 'All items',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
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
    final imageUrl = category?.categoryIcon?.trim();
    if (imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return Image.network(
        imageUrl,
        width: 26,
        height: 26,
        color: color,
        errorBuilder: (_, __, ___) => Icon(
          Icons.category_outlined,
          color: color,
          size: 26,
        ),
      );
    }
    return Icon(
      category == null ? Icons.grid_view_rounded : Icons.category_outlined,
      color: color,
      size: 26,
    );
  }
}
