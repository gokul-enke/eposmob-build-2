import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/services/tenant_config_store.dart';

void main() {
  late Directory dir;

  File storeFile() => File(
      '${dir.path}${Platform.pathSeparator}${TenantConfigStore.fileName}');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tenant_store_');
  });

  tearDown(() => dir.delete(recursive: true));

  test('saved tenant reads back and can be replaced', () async {
    await TenantConfigStore.write(
      const TenantConfig(apiKey: 'key-1', appUrl: 'https://one.example.com'),
      directory: dir,
    );
    await TenantConfigStore.write(
      const TenantConfig(apiKey: 'key-2', appUrl: 'https://two.example.com'),
      directory: dir,
    );

    final config = await TenantConfigStore.read(directory: dir);

    expect(config?.apiKey, 'key-2');
    expect(config?.appUrl, 'https://two.example.com');
  });

  test('nothing saved reads as null', () async {
    expect(await TenantConfigStore.read(directory: dir), isNull);
  });

  test('damaged file reads as null', () async {
    storeFile().writeAsStringSync('{"api_key":"key-');

    expect(await TenantConfigStore.read(directory: dir), isNull);
  });

  test('incomplete file reads as null', () async {
    storeFile().writeAsStringSync('{"api_key":"key-1","app_url":""}');

    expect(await TenantConfigStore.read(directory: dir), isNull);
  });

  test('delete removes the saved tenant', () async {
    await TenantConfigStore.write(
      const TenantConfig(apiKey: 'key-1', appUrl: 'https://one.example.com'),
      directory: dir,
    );

    await TenantConfigStore.delete(directory: dir);

    expect(await TenantConfigStore.read(directory: dir), isNull);
  });
}
