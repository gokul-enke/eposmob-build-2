import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/config/brand_config.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Runs only for a white-label build, e.g.
/// `flutter test --dart-define-from-file=brands/easyerp/brand.json test/config/brand_white_label_test.dart`
void main() {
  final skip = BrandConfig.isDefault
      ? 'Run with --dart-define-from-file=brands/<id>/brand.json'
      : null;

  Map<String, dynamic> brandFile() => jsonDecode(
          File('brands/${BrandConfig.id}/brand.json').readAsStringSync())
      as Map<String, dynamic>;

  test('brand values reach Dart', () {
    final brand = brandFile();
    expect(BrandConfig.name, brand['BRAND_NAME']);
    expect(BrandConfig.title, brand['BRAND_TITLE']);
    expect(BrandConfig.website, brand['BRAND_WEBSITE']);
    expect(BrandConfig.logoAsset, brand['BRAND_LOGO_ASSET']);
    expect(BrandConfig.exeName, brand['BRAND_EXE_NAME']);
  }, skip: skip);

  test('built-in copy shows the brand name', () {
    expect(
        BrandConfig.apply(
            'Restart CloudPOS. End cloudpos.exe. CLOUDPOS STORE. متجر كلاود بوس'),
        'Restart ${BrandConfig.name}. End ${BrandConfig.exeName}. '
        '${BrandConfig.title} STORE. متجر ${BrandConfig.name}');
  }, skip: skip);

  test('palette comes from the brand file', () {
    final brand = brandFile();
    int color(String key) => int.parse(brand[key] as String);
    expect(ColorManager.kPrimaryColor.toARGB32(), color('BRAND_PRIMARY_COLOR'));
    expect(ColorManager.kButtonBlue.toARGB32(), color('BRAND_ACCENT_COLOR'));
    expect(ColorManager.kSecondaryColor.toARGB32(),
        color('BRAND_SECONDARY_COLOR'));
    expect(
        ColorManager.kBgLightColor.toARGB32(), color('BRAND_BG_LIGHT_COLOR'));
    expect(ColorManager.kBgDarkColor.toARGB32(), color('BRAND_BG_DARK_COLOR'));
    expect(ColorManager.kPrimaryWithOpacity10.toARGB32(),
        (color('BRAND_PRIMARY_COLOR') & 0x00FFFFFF) | 0x1A000000);
    expect(ColorManager.kBrandBlue, ColorManager.kPrimaryColor);
    expect(ColorManager.kBrandBlueAccent, ColorManager.kButtonBlue);
  }, skip: skip);

  test('Material blue replacements follow the primary, light to dark', () {
    final swatch = [
      ColorManager.kBrandBlue50,
      ColorManager.kBrandBlue100,
      ColorManager.kBrandBlue200,
      ColorManager.kBrandBlue300,
      ColorManager.kPrimaryColor,
      ColorManager.kBrandBlue600,
      ColorManager.kBrandBlue700,
      ColorManager.kBrandBlue800,
      ColorManager.kBrandBlue900,
    ];
    final lightness =
        swatch.map((c) => HSLColor.fromColor(c).lightness).toList();
    for (var i = 1; i < lightness.length; i++) {
      expect(lightness[i], lessThan(lightness[i - 1]),
          reason: 'step $i should be darker than step ${i - 1}');
    }
    // Same hue family as the primary, not Material blue.
    final hue = HSLColor.fromColor(ColorManager.kPrimaryColor).hue;
    for (final c in swatch) {
      expect((HSLColor.fromColor(c).hue - hue).abs(), lessThan(3));
    }
    expect(ColorManager.kBrandBlue50, isNot(const Color(0xFFE3F2FD)));
  }, skip: skip);

  test('former hardcoded blues follow the brand and keep their alpha', () {
    final hue = HSLColor.fromColor(ColorManager.kPrimaryColor).hue;
    for (final c in [
      ColorManager.kBlue2563EB,
      ColorManager.kBlue0066CC,
      ColorManager.kBlue1D4ED8,
      ColorManager.kBlueBFDBFE,
      ColorManager.kBlueEFF6FF,
    ]) {
      expect((HSLColor.fromColor(c).hue - hue).abs(), lessThan(3));
    }
    expect(ColorManager.kBlue2563EB, ColorManager.kPrimaryColor);
    expect(ColorManager.kBlue1E88E5a1A.a, closeTo(0x1A / 255, 0.001));
    expect(ColorManager.kBlue1E88E5a1A.withValues(alpha: 1),
        ColorManager.kBrandBlue600);
  }, skip: skip);
}
