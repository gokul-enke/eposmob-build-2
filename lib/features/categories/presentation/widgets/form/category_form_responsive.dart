import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for category screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kCategoryPhoneBreakpoint = 600;

bool categoryIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kCategoryPhoneBreakpoint;

double categoryHorizontalMargin(double width) =>
    width < kCategoryPhoneBreakpoint ? 8.0 : 12.0;

double categoryVerticalMargin(double width) =>
    width < kCategoryPhoneBreakpoint ? 10.0 : 20.0;

/// Full-width on phones; half-width (minus gap) on wider layouts.
double categoryFieldWidth(double availableWidth, {int columns = 2}) {
  if (availableWidth < kCategoryPhoneBreakpoint) {
    return availableWidth;
  }
  final gap = 20.0 * (columns - 1);
  return (availableWidth - gap) / columns;
}

double categoryDialogWidth(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth < kCategoryPhoneBreakpoint) {
    return screenWidth - 24;
  }
  return math.min(700.0, screenWidth * 0.9);
}

double categoryDialogHeight(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  if (MediaQuery.of(context).size.width < kCategoryPhoneBreakpoint) {
    return screenHeight * 0.85;
  }
  return 600.0;
}

/// Shopify-style page title with optional subtitle.
class CategoryPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const CategoryPageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.kTitleTextColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.10,
              Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Form section card with consistent Shopify-like styling.
class CategoryFormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CategoryFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = categoryIsPhone(context);

    return BuildBoxShadowContainer(
      circleRadius: 14,
      blurRadius: 10,
      offsetValue: const Offset(0, 3),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      color: Colors.white,
      padding: EdgeInsets.all(isPhone ? 14 : 20),
      child: child,
    );
  }
}

/// Minimum 44px close affordance for dialogs.
class CategoryDialogCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CategoryDialogCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorManager.kPrimaryColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
