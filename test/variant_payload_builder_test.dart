import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/models/product_property.dart';

void main() {
  group('buildCreateVariantsPayload', () {
    test('produces the create shape with active flag and attributes', () {
      final payload = buildCreateVariantsPayload([
        const VariantFormInput(
          sku: '  ',
          barcode: 'TS-RED-L',
          price: '549',
          mrp: '599',
          purchasePrice: '300',
          attributes: [
            VariantAttributeInput(productPropId: 7, value: 'Red'),
            VariantAttributeInput(productPropId: 9, value: 'L'),
          ],
        ),
      ]);

      expect(payload.length, 1);
      final variant = payload.first;
      expect(variant.containsKey('id'), isFalse);
      expect(variant['sku'], isNull); // blank -> null
      expect(variant['barcode'], 'TS-RED-L');
      expect(variant['price'], 549);
      expect(variant['mrp'], 599);
      expect(variant['purchase_price'], 300);
      expect(variant['active'], true);
      expect(variant['attributes'], [
        {'product_prop_id': 7, 'value': 'Red'},
        {'product_prop_id': 9, 'value': 'L'},
      ]);
    });

    test('nullifies empty prices and drops value-less attributes', () {
      final payload = buildCreateVariantsPayload([
        const VariantFormInput(
          price: '',
          attributes: [
            VariantAttributeInput(productPropId: 7, value: 'Red'),
            VariantAttributeInput(productPropId: 9, value: '   '),
          ],
        ),
      ]);

      final variant = payload.first;
      expect(variant['price'], isNull);
      expect(variant['mrp'], isNull);
      // The blank-value attribute is not sent.
      expect(variant['attributes'], [
        {'product_prop_id': 7, 'value': 'Red'},
      ]);
    });

    test('empty rows produce an empty list', () {
      expect(buildCreateVariantsPayload(const []), isEmpty);
    });
  });

  group('buildEditVariantsPayload', () {
    test('mixes update, create and delete correctly', () {
      final payload = buildEditVariantsPayload([
        const VariantFormInput(
          id: 41,
          price: '575',
          attributes: [
            VariantAttributeInput(productPropId: 7, value: 'Red'),
            VariantAttributeInput(productPropId: 9, value: 'XL'),
          ],
        ),
        const VariantFormInput(
          id: 42,
          markedForDeletion: true,
        ),
        const VariantFormInput(
          barcode: 'TS-BLU-M',
          attributes: [
            VariantAttributeInput(productPropId: 7, value: 'Blue'),
            VariantAttributeInput(productPropId: 9, value: 'M'),
          ],
        ),
      ]);

      expect(payload.length, 3);

      // update
      expect(payload[0]['id'], 41);
      expect(payload[0]['price'], 575);
      expect(payload[0]['attributes'], [
        {'product_prop_id': 7, 'value': 'Red'},
        {'product_prop_id': 9, 'value': 'XL'},
      ]);

      // delete
      expect(payload[1], {'id': 42, '_delete': true});

      // create (no id)
      expect(payload[2].containsKey('id'), isFalse);
      expect(payload[2]['barcode'], 'TS-BLU-M');
    });

    test('a new (id-less) row marked for deletion is dropped entirely', () {
      final payload = buildEditVariantsPayload([
        const VariantFormInput(
          markedForDeletion: true,
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
      ]);
      expect(payload, isEmpty);
    });

    test('always sends the complete attribute set on update', () {
      final payload = buildEditVariantsPayload([
        const VariantFormInput(
          id: 5,
          attributes: [
            VariantAttributeInput(productPropId: 1, value: 'A'),
            VariantAttributeInput(productPropId: 2, value: 'B'),
            VariantAttributeInput(productPropId: 3, value: 'C'),
          ],
        ),
      ]);
      expect((payload.first['attributes'] as List).length, 3);
    });
  });

  group('validateVariantRows', () {
    test('rejects a row with no valued attribute', () {
      final error = validateVariantRows([
        const VariantFormInput(
          attributes: [VariantAttributeInput(productPropId: 7, value: '')],
        ),
      ]);
      expect(error, contains('at least one attribute'));
    });

    test('rejects duplicate attribute sets', () {
      final error = validateVariantRows([
        const VariantFormInput(
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
        const VariantFormInput(
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
      ]);
      expect(error, contains('same attributes'));
    });

    test('rejects duplicate barcodes', () {
      final error = validateVariantRows([
        const VariantFormInput(
          barcode: 'DUP',
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
        const VariantFormInput(
          barcode: 'DUP',
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Blue')],
        ),
      ]);
      expect(error, contains('unique'));
    });

    test('rejects a negative price', () {
      final error = validateVariantRows([
        const VariantFormInput(
          price: '-5',
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
      ]);
      expect(error, contains('price'));
    });

    test('accepts a valid unique set and ignores deleted rows', () {
      final error = validateVariantRows([
        const VariantFormInput(
          price: '10',
          attributes: [VariantAttributeInput(productPropId: 7, value: 'Red')],
        ),
        const VariantFormInput(
          id: 9,
          markedForDeletion: true,
        ),
      ]);
      expect(error, isNull);
    });
  });

  group('ProductProperty parsing', () {
    test('parses LST values given as plain strings', () {
      final props = ProductProperty.listFromResponse({
        'data': [
          {
            'id': 7,
            'code': 'COLOR',
            'label': 'Colour',
            'type': 'LST',
            'values': ['Red', 'Blue', 'Green'],
          }
        ]
      });

      expect(props.length, 1);
      expect(props.first.id, 7);
      expect(props.first.code, 'COLOR');
      expect(props.first.label, 'Colour');
      expect(props.first.type, 'LST');
      expect(props.first.isList, isTrue);
      expect(props.first.values, ['Red', 'Blue', 'Green']);
    });

    test('parses MLT values given as {id, value} maps', () {
      final props = ProductProperty.listFromResponse([
        {
          'id': '9',
          'props_code': 'SIZE',
          'type': 'MLT',
          'values': [
            {'id': 1, 'value': 'S'},
            {'id': 2, 'value': 'M'},
            {'id': 3, 'value': 'L'},
          ],
        }
      ]);

      expect(props.length, 1);
      expect(props.first.id, 9);
      expect(props.first.code, 'SIZE');
      // label falls back to code when absent
      expect(props.first.label, 'SIZE');
      expect(props.first.values, ['S', 'M', 'L']);
    });

    test('treats TXT as free text with no values', () {
      final props = ProductProperty.listFromResponse({
        'product_props': [
          {
            'id': 3,
            'name': 'NOTE',
            'type': 'TXT',
          }
        ]
      });

      expect(props.length, 1);
      expect(props.first.type, 'TXT');
      expect(props.first.isFreeText, isTrue);
      expect(props.first.values, isEmpty);
    });

    test('skips entries without id or code and defaults unknown type to TXT',
        () {
      final props = ProductProperty.listFromResponse([
        {'code': 'NO_ID'},
        {'id': 5},
        {'id': 6, 'code': 'WEIRD', 'type': 'XYZ'},
      ]);

      expect(props.length, 1);
      expect(props.first.code, 'WEIRD');
      expect(props.first.type, 'TXT');
    });

    test('parses from a JSON string', () {
      final props = ProductProperty.listFromJsonString(
        '{"data":[{"id":1,"code":"C","type":"LST","values":["x"]}]}',
      );
      expect(props.single.values, ['x']);
    });
  });
}
