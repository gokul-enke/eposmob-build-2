import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<HiveDocumentConfig> box;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('receipt-config-refresh-');
    Hive.init(directory.path);
    final adapter = HiveDocumentConfigAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) Hive.registerAdapter(adapter);
    box = await Hive.openBox<HiveDocumentConfig>('document_configs');
    SharedPreferences.setMockInitialValues({'api_key': 'test-tenant', 'active_store_id': 7});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    await Hive.close();
    // The test owns this freshly-created temporary directory exclusively.
    await directory.delete(recursive: true);
  });

  test('full refresh replaces stale documents and retains intentionally blank English', () async {
    await box.put('Credit Note', HiveDocumentConfig.fromDocumentConfig({
      'type': 'Credit Note', 'language': 'en', 'header': 'STALE HEADER',
    }));
    final provider = DocumentConfigProvider();
    await provider.initHive();
    final payload = {'status': 'success', 'document_configurations': {
      'Return Bill': {'type': 'Return Bill', 'language': 'en_ar',
        'display_configuration': {'showReturnQty': {
          'visible': true, 'value': 'الكمية', 'default': '',
        }}},
    }};
    final client = MockClient((request) async {
      expect(request.url.queryParameters['store_id'], '7');
      return http.Response(jsonEncode(payload), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await http.runWithClient(() => provider.fetchDocumentConfigurations(accessToken: 'test-token'), () => client);
    expect(provider.getDocumentConfig('Credit Note'), isNull,
        reason: 'Removed credit-note config must not shadow the current Return Bill');
    final restored = DocumentConfigProvider();
    await restored.initHive();
    final qty = restored.getDocumentConfig('Return Bill')!.displayConfiguration!.options!['showReturnQty']!;
    expect(qty.value, 'الكمية');
    expect(qty.defaultValue, '');
    expect(restored.getDocumentConfig('Credit Note'), isNull);
    provider.dispose();
    restored.dispose();
  });

  test('all five language cases survive refresh, restart and failed refresh', () async {
    final provider = DocumentConfigProvider();
    await provider.initHive();
    const types = ['Bill', 'Bill A4', 'Sales and Return Bill',
      'Sales and Return Bill A4', 'Return Bill'];
    for (final scenario in ['en', 'ar', 'both', 'empty_en', 'table_en']) {
      final fullEnglish = scenario == 'en' || scenario == 'both';
      final headingEnglish = fullEnglish || scenario == 'table_en';
      final language = ['en', 'ar'].contains(scenario) ? scenario : 'en_ar';
      final payload = {'status': 'success', 'document_configurations': {
        for (final type in types) type: {
          'type': type, 'language': language,
          'display_configuration': {
            'showStoreName': {'visible': true, 'value': 'متجر',
              'default': fullEnglish ? 'STORE' : ''},
            'showReturnQty': {'visible': true, 'value': 'الكمية',
              'default': headingEnglish ? 'QTY' : ''},
            'showReturnMRP': {'visible': false, 'value': 'MRP', 'default': ''},
          },
        },
      }};
      await http.runWithClient(() => provider.fetchDocumentConfigurations(accessToken: 'test'),
          () => MockClient((_) async => http.Response(jsonEncode(payload), 200,
              headers: {'content-type': 'application/json; charset=utf-8'})));
      final restored = DocumentConfigProvider();
      await restored.initHive();
      for (final type in types) {
        final config = restored.getDocumentConfig(type)!;
        expect(config.language, language);
        final fields = config.displayConfiguration!.options!;
        expect(fields['showStoreName']!.defaultValue, fullEnglish ? 'STORE' : '');
        expect(fields['showReturnQty']!.defaultValue, headingEnglish ? 'QTY' : '');
        expect(fields['showReturnQty']!.value, 'الكمية');
        expect(fields['showReturnMRP']!.visible, isFalse);
      }
      restored.dispose();
    }
    await expectLater(http.runWithClient(
        () => provider.fetchDocumentConfigurations(accessToken: 'test'),
        () => MockClient((_) async => http.Response('unavailable', 503))), throwsException);
    expect(provider.isLoading, isFalse);
    expect(provider.getDocumentConfig('Bill')!.language, 'en_ar');
    expect(box.length, 5);
    await box.clear();
    final backup = DocumentConfigProvider();
    await backup.initHive();
    for (final type in types) {
      final fields = backup.getDocumentConfig(type)!.displayConfiguration!.options!;
      expect(fields['showStoreName']!.defaultValue, '');
      expect(fields['showReturnQty']!.defaultValue, 'QTY');
    }
    await backup.clearAllCaches();
    expect(backup.getDocumentConfig('Bill'), isNull);
    expect((await SharedPreferences.getInstance()).getString('document_configs_snapshot_json'), isNull);
    backup.dispose();
    provider.dispose();
  });
}
