import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// Size rules shared by every kit button: an exact [height] on every
/// platform. Without the standard density and shrink-wrapped tap target,
/// desktop's compact density makes Material buttons 8 px shorter than icon
/// buttons with fixed constraints.
ButtonStyle _sized(ButtonStyle style,
    {required double height, bool expand = false}) {
  return style.copyWith(
    minimumSize:
        WidgetStatePropertyAll(Size(expand ? double.infinity : 0, height)),
    maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// Filled primary action (Add, Save).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppSizes.control,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;

  /// Shows a spinner and disables the button.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final style = _sized(
      FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppTextStyles.themed(
          context,
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      height: height,
      expand: expand,
    );
    final effectiveOnPressed = busy ? null : onPressed;
    final Widget leading = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 19);

    if (icon == null && !busy) {
      return FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: effectiveOnPressed,
      icon: leading,
      label: Text(label),
      style: style,
    );
  }
}

/// Bordered secondary action (View, Reset, Cancel).
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppSizes.control,
    this.expand = false,
    this.foreground = AppColors.primary,
    this.radius = AppRadius.control,
    this.iconSize = 17,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;
  final Color foreground;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final style = _sized(
      OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: foreground,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: AppTextStyles.themed(context, AppTextStyles.button),
      ),
      height: height,
      expand: expand,
    );
    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(label),
      style: style,
    );
  }
}

/// Square bordered icon button with a tooltip (Refresh, Export, Filters,
/// previous/next page).
///
/// [active] tints it as "on" (e.g. filters shown). [badge] adds a small dot
/// (e.g. filters applied while hidden). [busy] swaps the icon for a spinner
/// and disables it.
class AppSquareIconButton extends StatelessWidget {
  const AppSquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AppSizes.control,
    this.iconSize = 20,
    this.radius = AppRadius.control,
    this.foreground = AppColors.heading,
    this.active = false,
    this.badge = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final double radius;
  final Color foreground;
  final bool active;
  final bool badge;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(
              width: iconSize - 2,
              height: iconSize - 2,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: iconSize),
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      style: IconButton.styleFrom(
        foregroundColor: active ? AppColors.primary : foreground,
        backgroundColor: active ? AppColors.softBlue : null,
        disabledForegroundColor: AppColors.muted.withValues(alpha: .35),
        side: BorderSide(
          color: active
              ? AppColors.primary.withValues(alpha: .35)
              : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            if (badge)
              const PositionedDirectional(
                top: 7,
                end: 7,
                child: AppBadgeDot(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small red dot that marks "something is set here".
class AppBadgeDot extends StatelessWidget {
  const AppBadgeDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
      ),
    );
  }
}
