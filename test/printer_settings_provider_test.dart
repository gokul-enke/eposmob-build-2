import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/printer_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const responseBody = <String, dynamic>{
    'status': 'success',
    'data': <String, dynamic>{
      'b2b_paper_size': 'A5',
      'b2b_template': 'boxed_bilingual_tax_invoice',
      'b2c_paper_size': 'A5',
      'b2c_template': 'boxed_bilingual_tax_invoice',
    },
    'options': <String, dynamic>{
      'paper_sizes': <String, String>{
        '58mm': 'Thermal — 58mm',
        '80mm': 'Thermal — 80mm',
        '112mm': 'Thermal — 112mm',
        'A4': 'A4',
        'A5': 'A5',
        'PDF': 'PDF Sharing',
      },
      'thermal_templates': <String, String>{
        'classic': 'Classic',
        'premium': 'Premium',
      },
      'paper_templates': <String, String>{
        'classic': 'Classic',
        'boxed_bilingual_tax_invoice': 'Boxed Bilingual Tax Invoice',
      },
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'api_key': 'test-tenant',
      'default_paper_size': 'A4',
      'default_paper_size_b2b': '80mm',
      'billing_receipt_theme': 'classic',
      'billing_receipt_theme_b2b': 'premium',
      'default_paper_size_user_selected': true,
      'default_paper_size_b2b_user_selected': true,
      'billing_receipt_theme_user_selected': true,
      'billing_receipt_theme_b2b_user_selected': true,
    });
  });

  MockClient buildClient() => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/document/printer-settings');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['x-tenant'], 'test-tenant');
        return http.Response.bytes(
          utf8.encode(json.encode(responseBody)),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });

  test('ordinary sync preserves explicit local selections', () async {
    final provider = PrinterSettingsProvider(client: buildClient());

    await provider.fetchAndApplyDefaults(accessToken: 'test-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('default_paper_size'), 'A4');
    expect(prefs.getString('default_paper_size_b2b'), '80mm');
    expect(prefs.getString('billing_receipt_theme'), 'classic');
    expect(prefs.getString('billing_receipt_theme_b2b'), 'premium');
    expect(provider.errorMessage, isNull);
  });

  test('forced store sync replaces explicit local selections', () async {
    final provider = PrinterSettingsProvider(client: buildClient());

    await provider.fetchAndApplyDefaults(
      accessToken: 'test-token',
      forceServerValues: true,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('default_paper_size'), 'A5');
    expect(prefs.getString('default_paper_size_b2b'), 'A5');
    expect(
      prefs.getString('billing_receipt_theme'),
      'boxed_bilingual_tax_invoice',
    );
    expect(
      prefs.getString('billing_receipt_theme_b2b'),
      'boxed_bilingual_tax_invoice',
    );

    // Keep the markers so any non-store refresh still respects a test choice.
    expect(prefs.getBool('default_paper_size_user_selected'), isTrue);
    expect(prefs.getBool('billing_receipt_theme_user_selected'), isTrue);
    expect(provider.errorMessage, isNull);
  });
}
