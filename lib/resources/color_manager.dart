import 'package:flutter/material.dart';
import 'package:pos_machine/config/brand_config.dart';

class ColorManager {
  // ---- Brand palette -------------------------------------------------------
  // Set per brand by the BRAND_*_COLOR keys in brands/<id>/brand.json
  // (passed with --dart-define-from-file). The defaults are CloudPOS. Values
  // stay compile-time constants, so `const` widgets keep working.
  static const int _primary =
      int.fromEnvironment('BRAND_PRIMARY_COLOR', defaultValue: 0xFF3C92F5);
  static const int _accent =
      int.fromEnvironment('BRAND_ACCENT_COLOR', defaultValue: 0xFF5B8EE9);

  static const Color kPrimaryColor = Color(_primary);
  static const Color kPrimaryWithOpacity10 =
      Color((_primary & 0x00FFFFFF) | 0x1A000000);
  static const Color kSecondaryColor = Color(
      int.fromEnvironment('BRAND_SECONDARY_COLOR', defaultValue: 0xFFF5F6FC));
  static const Color kBgLightColor = Color(
      int.fromEnvironment('BRAND_BG_LIGHT_COLOR', defaultValue: 0xFFF2F4FC));
  static const Color kBgDarkColor = Color(
      int.fromEnvironment('BRAND_BG_DARK_COLOR', defaultValue: 0xFFEBEDFA));

  // Brand replacements for Material's Colors.blue swatch. CloudPOS keeps the
  // exact Material values; other brands get tints (toward white) and shades
  // (toward black) of their primary colour at similar lightness steps.
  static const int _r = (_primary >> 16) & 0xFF;
  static const int _g = (_primary >> 8) & 0xFF;
  static const int _b = _primary & 0xFF;
  static const bool _material = BrandConfig.isDefault;

  /// Material scheme for white-label brands, so Material's own widgets
  /// (spinners, checkboxes, switches, selection) follow the brand. Null for
  /// CloudPOS, which keeps Flutter's default scheme and its original look.
  static ColorScheme? get brandColorScheme => _material
      ? null
      : ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
          secondary: kButtonBlue,
          surface: Colors.white,
        );

  /// Primary as "#RRGGBB", for configs that store colours as hex strings.
  static String get primaryHex =>
      '#${(_primary & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static const Color kBrandBlue = Color(_material ? 0xFF2196F3 : _primary);
  static const Color kBrandBlueAccent =
      Color(_material ? 0xFF448AFF : _accent);
  static const Color kBrandBlue50 = Color(_material ? 0xFFE3F2FD : _t50);
  static const Color kBrandBlue100 = Color(_material ? 0xFFBBDEFB : _t100);
  static const Color kBrandBlue200 = Color(_material ? 0xFF90CAF9 : _t200);
  static const Color kBrandBlue300 = Color(_material ? 0xFF64B5F6 : _t300);
  static const Color kBrandBlue600 = Color(_material ? 0xFF1E88E5 : _s600);
  static const Color kBrandBlue700 = Color(_material ? 0xFF1976D2 : _s700);
  static const Color kBrandBlue800 = Color(_material ? 0xFF1565C0 : _s800);
  static const Color kBrandBlue900 = Color(_material ? 0xFF0D47A1 : _s900);

  // Swatch steps of the primary for white-label brands: tints toward white
  // (_t*) and shades toward black (_s*) at Material's lightness steps.
  static const int _t50 = 0xFF000000 |
      ((_r + (255 - _r) * 90 ~/ 100) << 16) |
      ((_g + (255 - _g) * 90 ~/ 100) << 8) |
      (_b + (255 - _b) * 90 ~/ 100);
  static const int _t100 = 0xFF000000 |
      ((_r + (255 - _r) * 75 ~/ 100) << 16) |
      ((_g + (255 - _g) * 75 ~/ 100) << 8) |
      (_b + (255 - _b) * 75 ~/ 100);
  static const int _t200 = 0xFF000000 |
      ((_r + (255 - _r) * 55 ~/ 100) << 16) |
      ((_g + (255 - _g) * 55 ~/ 100) << 8) |
      (_b + (255 - _b) * 55 ~/ 100);
  static const int _t300 = 0xFF000000 |
      ((_r + (255 - _r) * 35 ~/ 100) << 16) |
      ((_g + (255 - _g) * 35 ~/ 100) << 8) |
      (_b + (255 - _b) * 35 ~/ 100);
  static const int _t400 = 0xFF000000 |
      ((_r + (255 - _r) * 15 ~/ 100) << 16) |
      ((_g + (255 - _g) * 15 ~/ 100) << 8) |
      (_b + (255 - _b) * 15 ~/ 100);
  static const int _s600 = 0xFF000000 |
      ((_r * 90 ~/ 100) << 16) |
      ((_g * 90 ~/ 100) << 8) |
      (_b * 90 ~/ 100);
  static const int _s700 = 0xFF000000 |
      ((_r * 78 ~/ 100) << 16) |
      ((_g * 78 ~/ 100) << 8) |
      (_b * 78 ~/ 100);
  static const int _s800 = 0xFF000000 |
      ((_r * 66 ~/ 100) << 16) |
      ((_g * 66 ~/ 100) << 8) |
      (_b * 66 ~/ 100);
  static const int _s900 = 0xFF000000 |
      ((_r * 50 ~/ 100) << 16) |
      ((_g * 50 ~/ 100) << 8) |
      (_b * 50 ~/ 100);

  // Former hardcoded blues, named by their CloudPOS value (AARRGGBB, alpha
  // suffix when not opaque). CloudPOS keeps the exact value; other brands get
  // the swatch step of their primary with the closest lightness.
  static const Color kBlue1E88E5a1A =
      Color(_material ? 0x1A1E88E5 : 0x1A000000 | (_s600 & 0x00FFFFFF));
  static const Color kBlue234395a26 =
      Color(_material ? 0x26234395 : 0x26000000 | (_s900 & 0x00FFFFFF));
  static const Color kBlue0056B3 =
      Color(_material ? 0xFF0056B3 : _s900);
  static const Color kBlue0066CC =
      Color(_material ? 0xFF0066CC : _s800);
  static const Color kBlue0277BD =
      Color(_material ? 0xFF0277BD : _s900);
  static const Color kBlue0EA5E9 =
      Color(_material ? 0xFF0EA5E9 : _s700);
  static const Color kBlue0F3D75 =
      Color(_material ? 0xFF0F3D75 : _s900);
  static const Color kBlue1565C0 =
      Color(_material ? 0xFF1565C0 : _s800);
  static const Color kBlue1A56DB =
      Color(_material ? 0xFF1A56DB : _s700);
  static const Color kBlue1D4ED8 =
      Color(_material ? 0xFF1D4ED8 : _s700);
  static const Color kBlue1E88E5 =
      Color(_material ? 0xFF1E88E5 : _s600);
  static const Color kBlue2196F3 =
      Color(_material ? 0xFF2196F3 : _primary);
  static const Color kBlue2563EB =
      Color(_material ? 0xFF2563EB : _primary);
  static const Color kBlue2962FF =
      Color(_material ? 0xFF2962FF : _t400);
  static const Color kBlue2E69C8 =
      Color(_material ? 0xFF2E69C8 : _s700);
  static const Color kBlue3B82F6 =
      Color(_material ? 0xFF3B82F6 : _t400);
  static const Color kBlue4FACFE =
      Color(_material ? 0xFF4FACFE : _t300);
  static const Color kBlue5B8DEF =
      Color(_material ? 0xFF5B8DEF : _t300);
  static const Color kBlueBFDBFE =
      Color(_material ? 0xFFBFDBFE : _t100);
  static const Color kBlueDCE8F7 =
      Color(_material ? 0xFFDCE8F7 : _t50);
  static const Color kBlueDDE7F3 =
      Color(_material ? 0xFFDDE7F3 : _t50);
  static const Color kBlueE1F5FE =
      Color(_material ? 0xFFE1F5FE : _t50);
  static const Color kBlueE3F2FD =
      Color(_material ? 0xFFE3F2FD : _t50);
  static const Color kBlueEAF3FF =
      Color(_material ? 0xFFEAF3FF : _t50);
  static const Color kBlueEBF3FF =
      Color(_material ? 0xFFEBF3FF : _t50);
  static const Color kBlueEDF5FF =
      Color(_material ? 0xFFEDF5FF : _t50);
  static const Color kBlueEFF6FF =
      Color(_material ? 0xFFEFF6FF : _t50);
  static const Color kBlueF0F9FF =
      Color(_material ? 0xFFF0F9FF : _t50);
  // ---------------------------------------------------------------------------

  static const Color kBadgeColor = Color(0XFFEE376E);
  static const Color kGreyColor = Color(0XFF8793B2);
  static const Color kTitleTextColor = Color(0XFF30384D);
  static const Color kTextColor = Color(0XFF4D5875);
  static const Color kListTileColor = Color(0XFFFCFCFC);
  static const Color kListTiletextColor = Color(0XFFCFCDCD);
  static const Color kTextFieldColor25 = Color(0X4DCDCDCD);
  static const Color kButtonGreen = Color.fromARGB(255, 8, 202, 47);
  static const Color kButtonRed = Color.fromARGB(255, 245, 49, 73);
  static const Color kButtonBlue = Color(_accent);
  static const Color kButtonYellow = Color.fromARGB(255, 255, 184, 0);

  static const Color kRedBox = Color(0XFFF33030);
  static const Color kGreenBox = Color(0XFF54CA93);
  static const Color kBoxColorF7 = Color.fromARGB(255, 162, 142, 142);
  static const Color textColor = Color(0XCC000000);
  static const Color shadowColor = Color(0XFFE7ECEF);
  static const Color boxShadowColor = Color.fromRGBO(0, 0, 0, 0.16);
  static const Color containerShadowColor = Color(0xA6000029);
  static const Color containerShadowColor1 = Color(0xFFF8F8F7);
  static const Color containerShadowColorForList = Color(0x80F8F8F8);
  static const Color grey = Colors.grey;
  static const Color textColor1 = Color(0xFFD4D4D4);
  static const Color kSuccessColor = Colors.green;
  static const Color kErrorColor = Colors.red;

  static const Color tableBGColor = Color(0xFFF9F9F9);

  static const Color kRed = Color(0xFFF33535);
  static const Color tableBOrderColor = Color(0x4D707070);
  static const Color textColorRed = Color(0xFFFF3737);
  static const Color blackWithOpacity50 = Color(0x80000000);
  static const Color greyWithOpacity60 = Color(0x99C9C9C9);
  //********************************DashBoard Screen***************************/
  static const Color kGreen = Color(0XFF0CE437);
  static const Color kMaroon = Color(0XFFE34545);
  static const Color kMaroonWithOpacity = Color(0X40E34545);
  static const Color kGreenWithOpacity = Color(0X400CE437);
  static const Color kMagentha = Color(0XFFB938EF);
  static const Color kOrange = Color(0XFFF5863C);
  static const Color kBlue = Color(0XFF5B7DE7);
  static const Color kCyan = Color(0XFF1DDADB);
  static const Color kPink = Color(0XFFF75098);
  static const Color kLightPink = Color(0XFFF56B7D);
  static const Color kViolet = Color(0XFF532DE3);
  static const Color kLightViolet = Color(0XFF9347C7);
  static const Color kGreenLight = Color(0XFFC4D111);
  static const Color kGreenDarkLight = Color(0XFFD5CB3A);

  static const Color kGradientBlue = Color(0XFF5B7DE7);
  static const Color kGradientCyan = Color(0XFF1DDADB);
  static const Color kGradientRose = Color(0XFFF75098);
  static const Color kGradientPeach = Color(0XFFF56B7D);
  static const Color kGradientVoilet = Color(0XFF532DE3);
  static const Color kGradientIndigo = Color(0XFF9347C7);
  static const Color kGradientGreen = Color(0XFFC4D111);
  static const Color kGradientGreenLight = Color(0XFFD5CB3A);

  static const Color colorPlaceholder = Color.fromARGB(179, 213, 209, 209);
}
