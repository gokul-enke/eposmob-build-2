import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/config/brand_config.dart';

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

  test('default build is the CloudPOS brand and leaves copy unchanged', () {
    expect(BrandConfig.id, 'cloudpos');
    expect(BrandConfig.title, 'CLOUDPOS');
    expect(BrandConfig.apply('Restart CloudPOS (cloudpos.exe)'),
        'Restart CloudPOS (cloudpos.exe)');
  });

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
  });

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
