import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/helpers/item_tax_display.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('separate column configuration overrides legacy mode and survives cache',
      () {
    for (final visible in [true, false]) {
      final config = DocumentConfig.fromJson({
        'item_tax_display_mode': 'row_total',
        'display_configuration': {
          'showTaxHeader': {
            'visible': true,
            'value': 'الضريبة',
            'default': 'Tax'
          },
          'showRowTotalTaxHeader': {
            'visible': visible,
            'value': 'Row Total الضريبة',
            'default': 'TAX',
          },
        },
        'resolved_labels': {'row_total_tax': 'Row Total الضريبة'},
      });
      for (final actual in [config, DocumentConfig.fromJson(config.toJson())]) {
        expect(actual.hasSeparateItemTaxColumns, isTrue);
        expect(actual.taxHeaderDisplayMode, ItemTaxDisplayMode.unit);
        expect(
            actual.displayConfiguration!.options!['showRowTotalTaxHeader']!
                .visible,
            visible);
        expect(actual.resolvedLabels!.rowTotalTax, 'Row Total الضريبة');
      }
    }
    expect(DocumentConfig.fromJson({}).hasSeparateItemTaxColumns, isFalse);
    expect(DocumentConfig.fromJson({}).taxHeaderDisplayMode,
        ItemTaxDisplayMode.rowTotal);
    final flags = DocumentConfig.fromJson({
      'display_flags': {'showTaxHeader': 1, 'showRowTotalTaxHeader': 0},
    });
    expect(flags.hasSeparateItemTaxColumns, isTrue);
    expect(flags.taxHeaderDisplayMode, ItemTaxDisplayMode.unit);
    expect(
        flags.displayConfiguration!.options!['showRowTotalTaxHeader']!.visible,
        isFalse);
  });

  test('missing or unrecognized mode defaults to full row, including cache',
      () {
    expect(DocumentConfig().itemTaxDisplayMode, ItemTaxDisplayMode.rowTotal);
    for (final value in [null, '', 'unknown', 'row_total', false, 1]) {
      final config = DocumentConfig.fromJson({
        if (value != null) 'item_tax_display_mode': value,
      });
      expect(config.itemTaxDisplayMode, ItemTaxDisplayMode.rowTotal);
      expect(config.toJson()['item_tax_display_mode'], 'row_total');
      expect(DocumentConfig.fromJson(config.toJson()).itemTaxDisplayMode,
          ItemTaxDisplayMode.rowTotal);
    }
    for (final value in ['unit', ' UNIT ']) {
      final config = DocumentConfig.fromJson({'item_tax_display_mode': value});
      expect(config.itemTaxDisplayMode, ItemTaxDisplayMode.unit);
      expect(config.toJson()['item_tax_display_mode'], 'unit');
      expect(DocumentConfig.fromJson(config.toJson()).itemTaxDisplayMode,
          ItemTaxDisplayMode.unit);
    }
  });

  test('row total uses full tax; unit uses API value, including explicit zero',
      () {
    for (final unit in ['4.75', 0, '0.000']) {
      expect(
          ItemTaxDisplay.amount(
            mode: ItemTaxDisplayMode.rowTotal,
            rowTax: '50.00',
            unitTax: unit,
            quantity: 10,
          ),
          50);
      expect(
          ItemTaxDisplay.amount(
            mode: ItemTaxDisplayMode.unit,
            rowTax: '50.00',
            unitTax: unit,
            quantity: 10,
          ),
          double.parse(unit.toString()));
    }
  });

  test(
      'older rows derive unit tax safely for fractional and invalid quantities',
      () {
    for (final unit in [null, '', 'invalid', 'NaN', 'Infinity']) {
      expect(
          ItemTaxDisplay.amount(
            mode: ItemTaxDisplayMode.unit,
            rowTax: '50.00',
            unitTax: unit,
            quantity: 10,
          ),
          5);
      expect(
          ItemTaxDisplay.amount(
            mode: ItemTaxDisplayMode.unit,
            rowTax: '2.50',
            unitTax: unit,
            quantity: '0.5',
          ),
          5);
    }
    for (final qty in [null, 0, -1, '', 'invalid', 'NaN', 'Infinity']) {
      expect(
          ItemTaxDisplay.amount(
            mode: ItemTaxDisplayMode.unit,
            rowTax: '50.00',
            quantity: qty,
          ),
          0);
    }
    expect(
        ItemTaxDisplay.amount(
          mode: ItemTaxDisplayMode.unit,
          rowTax: 'NaN',
          quantity: 10,
        ),
        0);
  });

  test('sales API unit tax survives model, cache and partial quantity copies',
      () {
    for (final unit in [4.75, '4.750', 0, '0.000']) {
      final json = {
        'quantity': '10',
        'tax_amount': '50.00',
        'tax_amount_unit': unit
      };
      final order = OrderDetailsModelDataCartItem.fromJson(json);
      expect(order.taxAmountUnit, unit.toString());
      expect(order.taxAmount, '50.00');
      expect(
          OrderDetailsModelDataCartItem.fromJson(order.toJson()).taxAmountUnit,
          unit.toString());
      expect(order.copyWith(quantity: 5, taxAmount: '25.00').taxAmountUnit,
          unit.toString());
      final cart = ListCartModelDataCartItem.fromJson(json);
      expect(cart.taxAmountUnit, unit.toString());
      expect(cart.toJson()['tax_amount_unit'], unit.toString());
    }
  });

  test(
      'API mode survives configuration refresh, Hive restart and snapshot fallback',
      () async {
    final directory = await Directory.systemTemp.createTemp('item-tax-config-');
    Hive.init(directory.path);
    final adapter = HiveDocumentConfigAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    final box = await Hive.openBox<HiveDocumentConfig>('document_configs');
    SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'});
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => directory.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null);
      await Hive.close();
      // This test owns the verified, freshly-created temporary directory.
      await directory.delete(recursive: true);
    });
    final provider = DocumentConfigProvider();
    await provider.initHive();
    addTearDown(provider.dispose);
    final response = {
      'status': 'success',
      'document_configurations': {
        'Quotation': {'type': 'Quotation', 'item_tax_display_mode': 'unit'},
        'Bill': {'type': 'Bill', 'item_tax_display_mode': 'row_total'},
        'Bill A4': {
          'type': 'Bill A4',
          'display_configuration': {
            'showTaxHeader': {'visible': true},
            'showRowTotalTaxHeader': {'visible': true, 'value': 'Row tax'},
          },
          'resolved_labels': {'row_total_tax': 'Row tax'},
        },
      }
    };
    await http.runWithClient(
      () => provider.fetchDocumentConfigurations(accessToken: 'test-token'),
      () => MockClient((_) async => http.Response(jsonEncode(response), 200)),
    );
    final restored = DocumentConfigProvider();
    await restored.initHive();
    addTearDown(restored.dispose);
    expect(restored.getDocumentConfig('Quotation')!.itemTaxDisplayMode,
        ItemTaxDisplayMode.unit);
    expect(restored.getDocumentConfig('Bill')!.itemTaxDisplayMode,
        ItemTaxDisplayMode.rowTotal);
    expect(restored.getDocumentConfig('Bill A4')!.itemTaxDisplayMode,
        ItemTaxDisplayMode.rowTotal);
    await box.clear();
    final backup = DocumentConfigProvider();
    await backup.initHive();
    addTearDown(backup.dispose);
    expect(backup.getDocumentConfig('Quotation')!.itemTaxDisplayMode,
        ItemTaxDisplayMode.unit);
    expect(backup.getDocumentConfig('Bill')!.itemTaxDisplayMode,
        ItemTaxDisplayMode.rowTotal);
    for (final cached in [restored, backup]) {
      final config = cached.getDocumentConfig('Bill A4')!;
      expect(config.hasSeparateItemTaxColumns, isTrue);
      expect(config.taxHeaderDisplayMode, ItemTaxDisplayMode.unit);
      expect(
          config
              .displayConfiguration!.options!['showRowTotalTaxHeader']!.visible,
          isTrue);
      expect(config.resolvedLabels!.rowTotalTax, 'Row tax');
    }
  });
}
