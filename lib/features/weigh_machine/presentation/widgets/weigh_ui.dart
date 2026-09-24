import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Weigh-machine presentation primitives.
///
/// The palette mirrors the Customers page so both screens read as one system.
/// Promote the shared pieces together instead of copying them a third time.
abstract final class WeighUiColors {
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
  static const softAmber = Color(0xFFFFF4E0);
  static const amber = Color(0xFF8A5A00);
}

abstract final class WeighFormat {
  static final _count = NumberFormat.decimalPattern();

  static String count(int value) => _count.format(value);

  static String products(int value) =>
      value == 1 ? '1 product' : '${count(value)} products';

  static String price(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    return number == null ? '—' : number.toStringAsFixed(2);
  }
}

class WeighSurface extends StatelessWidget {
  const WeighSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Shadow sits outside a Material so checkbox rows, switches and InkWells
    // inside the card still paint their splashes.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: WeighUiColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: WeighUiColors.border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class WeighIconTile extends StatelessWidget {
  const WeighIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.background = WeighUiColors.softBlue,
    this.foreground = ColorManager.kPrimaryColor,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}

class WeighBadge extends StatelessWidget {
  const WeighBadge.weighted({super.key})
      : label = 'Weighted',
        background = WeighUiColors.softGreen,
        foreground = WeighUiColors.green;

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class WeighEmptyState extends StatelessWidget {
  const WeighEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WeighIconTile(icon: icon, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: WeighUiColors.heading,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: WeighUiColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: weighSecondaryButtonStyle(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

ButtonStyle weighPrimaryButtonStyle() => FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: ColorManager.kPrimaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

ButtonStyle weighSecondaryButtonStyle() => OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      foregroundColor: ColorManager.kPrimaryColor,
      side: const BorderSide(color: WeighUiColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
