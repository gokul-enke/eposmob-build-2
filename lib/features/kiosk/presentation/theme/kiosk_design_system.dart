import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Shared visual scale for customer-facing kiosk screens.
///
/// Kiosk controls deliberately use larger type and touch targets than the
/// staff POS because customers read and operate them from farther away.
class KioskSpacing {
  KioskSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class KioskRadius {
  KioskRadius._();

  static const double control = 14;
  static const double card = 20;
  static const double modal = 24;
}

class KioskType {
  KioskType._();

  static const TextStyle pageTitle = TextStyle(
    color: ColorManager.kTitleTextColor,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: ColorManager.kTitleTextColor,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle productTitle = TextStyle(
    color: ColorManager.kTitleTextColor,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    color: ColorManager.kTextColor,
    fontSize: 16,
    height: 1.4,
  );

  static const TextStyle supporting = TextStyle(
    color: ColorManager.kTextColor,
    fontSize: 14,
    height: 1.35,
  );

  static const TextStyle label = TextStyle(
    color: ColorManager.kTitleTextColor,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle action = TextStyle(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle price = TextStyle(
    color: ColorManager.kPrimaryColor,
    fontSize: 19,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );
}
