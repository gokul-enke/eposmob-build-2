import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Customer-list presentation primitives.
///
/// Keep these feature-scoped until another module needs the same visual and
/// interaction contract. At that point, promote the genuinely shared pieces
/// instead of copying them.
abstract final class CustomerDisplay {
  static bool isUnnamed(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower == 'no name' || lower == 'unnamed';
  }

  static String name(String? value) =>
      isUnnamed(value) ? 'customers.unnamed'.tr : value!.trim();
}

abstract final class CustomerUiColors {
  static const canvas = Color(0xFFF6F6F7);
  static const surface = Colors.white;
  static const border = Color(0xFFE1E3E5);
  static const subtleBorder = Color(0xFFEBEBEB);
  static const heading = Color(0xFF202223);
  static const body = Color(0xFF4A4A4A);
  static const muted = Color(0xFF6D7175);
  static const softBlue = Color(0xFFEBF3FF);
  static const softGreen = Color(0xFFE3F1DF);
  static const green = Color(0xFF2C6E49);
  static const softRed = Color(0xFFFFEDEB);
  static const red = Color(0xFFB42318);
}

class CustomerSurface extends StatelessWidget {
  const CustomerSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CustomerUiColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerUiColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({
    super.key,
    required this.name,
    this.size = 40,
  });

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedName = CustomerDisplay.isUnnamed(name) ? '' : name!.trim();
    final initial = trimmedName.isEmpty ? '#' : trimmedName[0].toUpperCase();

    return Semantics(
      label: trimmedName.isEmpty
          ? 'customers.unnamed'.tr
          : 'customers.avatar_label'.trParams({'name': trimmedName}),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CustomerUiColors.softBlue,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: ColorManager.kPrimaryColor,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class CustomerTypeBadge extends StatelessWidget {
  const CustomerTypeBadge({
    super.key,
    required this.type,
  });

  final String? type;

  @override
  Widget build(BuildContext context) {
    final value = (type ?? 'B2C').toUpperCase();
    final isBusiness = value == 'B2B';
    final background =
        isBusiness ? CustomerUiColors.softGreen : CustomerUiColors.softBlue;
    final foreground =
        isBusiness ? CustomerUiColors.green : ColorManager.kPrimaryColor;

    return Semantics(
      label: 'customers.type_semantics'.trParams({'type': value}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isBusiness ? 'customers.type_b2b'.tr : 'customers.type_b2c'.tr,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class CustomerMetric extends StatelessWidget {
  const CustomerMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CustomerUiColors.canvas,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: CustomerUiColors.muted),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: CustomerUiColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? CustomerUiColors.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CustomerEmptyState extends StatelessWidget {
  const CustomerEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CustomerUiColors.softBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 34,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'customers.empty_title'.tr,
              style: const TextStyle(
                color: CustomerUiColors.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'customers.empty_subtitle'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CustomerUiColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerPaginationBar extends StatelessWidget {
  const CustomerPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.visibleItemCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int visibleItemCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('customer_pagination_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CustomerUiColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerUiColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 440;
          final countLabel = Text(
            visibleItemCount == 1
                ? 'customers.count_on_page_one'.tr
                : 'customers.count_on_page'
                    .trParams({'count': '$visibleItemCount'}),
            style: const TextStyle(
              color: CustomerUiColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          );
          final pagination = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CustomerPageButton(
                tooltip: 'pagination.previous'.tr,
                icon: Icons.chevron_left_rounded,
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'pagination.page_of'.trParams({
                    'current': '$currentPage',
                    'total': '$totalPages',
                  }),
                  style: const TextStyle(
                    color: CustomerUiColors.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CustomerPageButton(
                tooltip: 'pagination.next'.tr,
                icon: Icons.chevron_right_rounded,
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          );

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                countLabel,
                const SizedBox(height: 8),
                pagination,
              ],
            );
          }

          return Row(
            children: [
              countLabel,
              const Spacer(),
              pagination,
            ],
          );
        },
      ),
    );
  }
}

class _CustomerPageButton extends StatelessWidget {
  const _CustomerPageButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: CustomerUiColors.heading,
          disabledForegroundColor:
              CustomerUiColors.muted.withValues(alpha: .35),
          side: const BorderSide(color: CustomerUiColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }
}
