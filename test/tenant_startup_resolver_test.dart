import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/services/tenant_config_store.dart';
import 'package:pos_machine/services/tenant_domain_service.dart';
import 'package:pos_machine/services/tenant_startup_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<String> discoveries;

  final defaultUrl = APPUrl.normalizeBaseUrl(APPUrl.defaultBaseURL);
  const tenantUrl = 'https://tenant.example.com';
  const offline = TenantDomainException('offline', serverRejected: false);

  Future<String> Function(String) discoverThrowing(Object error) =>
      (apiKey) async {
        discoveries.add(apiKey);
        throw error;
      };

  Future<TenantStartupResult> resolve(
          Future<String> Function(String) discover) =>
      TenantStartupResolver.resolve(
          discoverAndSave: discover, storeDirectory: dir);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tenant_startup_');
    discoveries = [];
    APPUrl.baseURL = APPUrl.defaultBaseURL;
  });

  tearDown(() => dir.delete(recursive: true));

  test('configured till opens sign-in without the network', () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'key-1', 'app_url': tenantUrl});

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isFalse);
    expect(discoveries, isEmpty);
    expect(APPUrl.baseURL, tenantUrl);
    final stored = await TenantConfigStore.read(directory: dir);
    expect(stored?.apiKey, 'key-1');
    expect(stored?.appUrl, tenantUrl);
  });

  test('confirmed default-server till is not re-verified every launch',
      () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'key-1', 'app_url': defaultUrl});
    await TenantConfigStore.write(
      TenantConfig(apiKey: 'key-1', appUrl: defaultUrl),
      directory: dir,
    );

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isFalse);
    expect(discoveries, isEmpty);
  });

  test('offline launch keeps an unconfirmed default-server till working',
      () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'key-1', 'app_url': defaultUrl});

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isFalse);
    expect(discoveries, ['key-1']);
    expect(APPUrl.baseURL, defaultUrl);
  });

  test('a refused key asks for a new one', () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'key-1', 'app_url': defaultUrl});

    final result = await resolve(
        discoverThrowing(const TenantDomainException('Tenant not found')));

    expect(result.needsApiKey, isTrue);
    expect(result.error, 'Tenant not found');
  });

  test('preferences that lost the tenant are restored from the tenant file',
      () async {
    SharedPreferences.setMockInitialValues({});
    await TenantConfigStore.write(
      const TenantConfig(apiKey: 'key-1', appUrl: tenantUrl),
      directory: dir,
    );

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isFalse);
    expect(discoveries, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_key'), 'key-1');
    expect(prefs.getString('app_url'), tenantUrl);
  });

  test('till that was never provisioned goes to sign-in', () async {
    SharedPreferences.setMockInitialValues({});

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isFalse);
    expect(discoveries, isEmpty);
  });

  test('key without any known server cannot continue offline', () async {
    SharedPreferences.setMockInitialValues({'api_key': 'key-1'});

    final result = await resolve(discoverThrowing(offline));

    expect(result.needsApiKey, isTrue);
    expect(discoveries, ['key-1']);
  });
}
