import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/config/brand_config.dart';
import 'package:pos_machine/resources/color_manager.dart';

const _requiredKeys = [
  'BRAND_ID',
  'BRAND_NAME',
  'BRAND_TITLE',
  'BRAND_COMPANY',
  'BRAND_PRODUCT_NAME',
  'BRAND_PUBLISHER',
  'BRAND_URL',
  'BRAND_EXE_NAME',
  'BRAND_INSTALLER_NAME',
  'BRAND_APP_ID',
  'BRAND_LOGO_ASSET',
  'BRAND_ICON_ASSET',
  'BRAND_WEBSITE',
  'BRAND_PRIMARY_COLOR',
  'BRAND_ACCENT_COLOR',
  'BRAND_SECONDARY_COLOR',
  'BRAND_BG_LIGHT_COLOR',
  'BRAND_BG_DARK_COLOR',
  'BRAND_SPLASH_TEXT_COLOR',
];

Map<String, Map<String, dynamic>> _loadBrands() {
  final brands = <String, Map<String, dynamic>>{};
  for (final dir in Directory('brands').listSync().whereType<Directory>()) {
    final file = File('${dir.path}/brand.json');
    if (!file.existsSync()) continue;
    final id = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    brands[id] = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  return brands;
}

void main() {
  final brands = _loadBrands();
  final pubspec = File('pubspec.yaml').readAsStringSync();
  // These check the plain CloudPOS build; CI also runs this file per brand.
  final cloudposOnly =
      BrandConfig.isDefault ? null : 'CloudPOS build only (default defines)';

  test('default build is the CloudPOS brand and leaves copy unchanged', () {
    expect(BrandConfig.id, 'cloudpos');
    expect(BrandConfig.title, 'CLOUDPOS');
    expect(BrandConfig.apply('Restart CloudPOS (cloudpos.exe)'),
        'Restart CloudPOS (cloudpos.exe)');
  }, skip: cloudposOnly);

  test('CloudPOS keeps the identity of existing installs', () {
    // Changing any of these makes the next release install as a second app
    // with empty data instead of updating customers' tills.
    final cloudpos = brands['cloudpos']!;
    expect(cloudpos['BRAND_APP_ID'], '5A15344D-601E-49CD-AD46-C2F1C2B21F3D');
    expect(cloudpos['BRAND_COMPANY'], 'com.enke');
    expect(cloudpos['BRAND_PRODUCT_NAME'], 'pos_machine');
    expect(cloudpos['BRAND_EXE_NAME'], 'cloudpos.exe');
    expect(cloudpos['BRAND_LOGO_ASSET'], BrandConfig.logoAsset);
    expect(cloudpos['BRAND_ICON_ASSET'], BrandConfig.iconAsset);
    expect(cloudpos['BRAND_WEBSITE'], BrandConfig.website);
  }, skip: cloudposOnly);

  test('CloudPOS brand file matches the palette a plain build uses', () {
    // A plain `flutter run` uses ColorManager's defaults; the release build
    // passes brands/cloudpos/brand.json. They must give the same colours.
    final cloudpos = brands['cloudpos']!;
    int color(String key) => int.parse(cloudpos[key] as String);
    expect(color('BRAND_PRIMARY_COLOR'), ColorManager.kPrimaryColor.toARGB32());
    expect(color('BRAND_ACCENT_COLOR'), ColorManager.kButtonBlue.toARGB32());
    expect(
        color('BRAND_SECONDARY_COLOR'), ColorManager.kSecondaryColor.toARGB32());
    expect(color('BRAND_BG_LIGHT_COLOR'), ColorManager.kBgLightColor.toARGB32());
    expect(color('BRAND_BG_DARK_COLOR'), ColorManager.kBgDarkColor.toARGB32());
    // CloudPOS keeps Material's exact blue swatch.
    expect(ColorManager.kBrandBlue.toARGB32(), 0xFF2196F3);
    expect(ColorManager.kBrandBlue50.toARGB32(), 0xFFE3F2FD);
    expect(ColorManager.kBrandBlue700.toARGB32(), 0xFF1976D2);
    expect(ColorManager.primaryHex, '#3C92F5');
    // Former hardcoded blues keep their exact CloudPOS values.
    expect(ColorManager.kBlue2563EB.toARGB32(), 0xFF2563EB);
    expect(ColorManager.kBlue0066CC.toARGB32(), 0xFF0066CC);
    expect(ColorManager.kBlueEFF6FF.toARGB32(), 0xFFEFF6FF);
    expect(ColorManager.kBlue1E88E5a1A.toARGB32(), 0x1A1E88E5);
  }, skip: cloudposOnly);

  for (final entry in brands.entries) {
    test('brand ${entry.key} is complete and packageable', () {
      final brand = entry.value;
      for (final key in _requiredKeys) {
        expect(brand[key], isA<String>(), reason: '$key missing');
        expect((brand[key] as String).trim(), isNotEmpty, reason: key);
        expect(RegExp(r'^[\x20-\x7E]*$').hasMatch(brand[key] as String) &&
                !(brand[key] as String).contains('"'),
            isTrue,
            reason: '$key must be plain ASCII without quotes for Runner.rc');
      }
      expect(brand['BRAND_ID'], entry.key);
      expect(
          RegExp(r'^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$')
              .hasMatch(brand['BRAND_APP_ID'] as String),
          isTrue,
          reason: 'BRAND_APP_ID must be a bare GUID');
      expect(brand['BRAND_EXE_NAME'], endsWith('.exe'));
      for (final key in _requiredKeys.where((k) => k.endsWith('_COLOR'))) {
        // Anything else silently falls back to the CloudPOS colour in Dart.
        expect(RegExp(r'^0x[0-9A-Fa-f]{8}$').hasMatch(brand[key] as String),
            isTrue,
            reason: '$key must look like 0xFFRRGGBB');
      }
      expect(brand['BRAND_WEBSITE'], startsWith('https://'));
      for (final key in ['BRAND_LOGO_ASSET', 'BRAND_ICON_ASSET']) {
        final asset = brand[key] as String;
        expect(File(asset).existsSync(), isTrue, reason: '$asset missing');
        final folder = asset.substring(0, asset.lastIndexOf('/') + 1);
        expect(pubspec, contains('- $folder'),
            reason: '$folder must be listed under assets in pubspec.yaml');
      }
    });
  }

  test('brands never share an installer id, data folder or exe name', () {
    for (final key in ['BRAND_APP_ID', 'BRAND_EXE_NAME', 'BRAND_INSTALLER_NAME']) {
      final values = brands.values.map((b) => b[key]).toList();
      expect(values.toSet().length, values.length, reason: '$key is shared');
    }
    final dataDirs = brands.values
        .map((b) => '${b['BRAND_COMPANY']}/${b['BRAND_PRODUCT_NAME']}')
        .toList();
    expect(dataDirs.toSet().length, dataDirs.length,
        reason: 'data folder is shared');
  });

  test('release workflow builds every brand', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final match = RegExp(r'brand: \[([^\]]*)\]').firstMatch(workflow);
    expect(match, isNotNull);
    final listed = match!.group(1)!.split(',').map((s) => s.trim()).toSet();
    expect(listed, brands.keys.toSet());
  });
}
