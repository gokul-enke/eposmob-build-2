import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Shared palette for the app's management screens (listing pages, detail
/// pages, forms).
///
/// This is the single source for these values. Feature code must not declare
/// its own copy of the palette — add the colour here instead.
abstract final class AppColors {
  static const primary = ColorManager.kPrimaryColor;
  static const onPrimary = Colors.white;

  static const canvas = Color(0xFFF6F6F7);
  static const surface = Colors.white;
  static const border = Color(0xFFE1E3E5);
  static const subtleBorder = Color(0xFFEBEBEB);

  static const heading = Color(0xFF202223);
  static const body = Color(0xFF4A4A4A);
  static const muted = Color(0xFF6D7175);
  static const hint = Color(0xFF9A9A9A);

  static const softBlue = Color(0xFFEBF3FF);
  static const softGreen = Color(0xFFE3F1DF);
  static const green = Color(0xFF2C6E49);
  static const softRed = Color(0xFFFFEDEB);
  static const red = Color(0xFFB42318);
  static const softAmber = Color(0xFFFFF4E0);
  static const amber = Color(0xFF8A5A00);

  static const shadow = Color(0x0A000000);
  static const rowHover = Color(0xFFF9FAFB);

  /// Green for zero or positive amounts, red for negative ones.
  static Color amount(num value) => value >= 0 ? green : red;
}
