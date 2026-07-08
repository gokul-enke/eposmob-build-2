import 'dart:convert';

/// A selectable product property (attribute) used when building product
/// variants. Mirrors a `product_props` row.
///
/// Parsing is deliberately defensive because the exact
/// `GET /api/v1/product/list-product-properties` response shape is not fixed:
/// the allowed values for `LST`/`MLT` types may arrive as a list of plain
/// strings (e.g. `["Red", "Blue"]`) or a list of maps
/// (e.g. `[{"id": 1, "value": "Red"}]`).
class ProductProperty {
  final int id;

  /// Machine code (e.g. `COLOR`). Matched against `ProductVariant.attributes`
  /// keys when prefilling the edit form.
  final String code;

  /// Human readable label shown in the dropdown. Falls back to [code].
  final String label;

  /// One of `LST`, `MLT`, `TXT` (uppercased). Unknown/blank values are treated
  /// as `TXT` (free text).
  final String type;

  /// Allowed values for `LST`/`MLT` types (empty for `TXT`).
  final List<String> values;

  const ProductProperty({
    required this.id,
    required this.code,
    required this.label,
    required this.type,
    this.values = const [],
  });

  bool get isFreeText => type == 'TXT';
  bool get isList => type == 'LST' || type == 'MLT';

  static List<ProductProperty> listFromResponse(dynamic decoded) {
    final raw = _extractList(decoded);
    final result = <ProductProperty>[];
    for (final item in raw) {
      final prop = _tryFromJson(item);
      if (prop != null) {
        result.add(prop);
      }
    }
    return result;
  }

  static List<ProductProperty> listFromJsonString(String source) {
    if (source.trim().isEmpty) return const [];
    try {
      return listFromResponse(json.decode(source));
    } on FormatException {
      return const [];
    }
  }

  static List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const [
        'data',
        'product_props',
        'properties',
        'props',
        'product_properties',
        'result',
      ]) {
        final value = decoded[key];
        if (value is List) return value;
        // Some APIs nest again, e.g. { data: { data: [...] } }.
        if (value is Map) {
          final inner = _extractList(value);
          if (inner.isNotEmpty) return inner;
        }
      }
    }
    return const [];
  }

  static ProductProperty? _tryFromJson(dynamic item) {
    if (item is! Map) return null;
    final map = Map<String, dynamic>.from(item);

    final id = _parseInt(
      map['id'] ?? map['product_prop_id'] ?? map['prop_id'] ?? map['props_id'],
    );
    if (id == null) return null;

    final code = (map['code'] ??
            map['props_code'] ??
            map['prop_code'] ??
            map['name'] ??
            map['label'] ??
            '')
        .toString()
        .trim();
    if (code.isEmpty) return null;

    final label = (map['label'] ??
            map['name'] ??
            map['title'] ??
            map['display_name'] ??
            code)
        .toString()
        .trim();

    final type = (map['type'] ?? map['prop_type'] ?? map['input_type'] ?? 'TXT')
        .toString()
        .trim()
        .toUpperCase();
    final normalizedType =
        (type == 'LST' || type == 'MLT' || type == 'TXT') ? type : 'TXT';

    final values = _parseValues(
      map['values'] ??
          map['allowed_values'] ??
          map['options'] ??
          map['master_values'] ??
          map['prop_values'] ??
          map['value'],
    );

    return ProductProperty(
      id: id,
      code: code,
      label: label.isEmpty ? code : label,
      type: normalizedType,
      values: values,
    );
  }

  static List<String> _parseValues(dynamic raw) {
    if (raw == null) return const [];
    final result = <String>[];

    void addValue(dynamic value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty && !result.contains(text)) {
        result.add(text);
      }
    }

    if (raw is String) {
      // Comma separated string fallback.
      for (final part in raw.split(',')) {
        addValue(part.trim());
      }
      return result;
    }

    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          addValue(entry['value'] ??
              entry['name'] ??
              entry['label'] ??
              entry['title']);
        } else {
          addValue(entry);
        }
      }
      return result;
    }

    if (raw is Map) {
      // e.g. { "1": "Red", "2": "Blue" }
      raw.forEach((key, value) {
        if (value is Map) {
          addValue(value['value'] ?? value['name'] ?? value['label']);
        } else {
          addValue(value);
        }
      });
      return result;
    }

    return result;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  String toString() =>
      'ProductProperty(id: $id, code: $code, type: $type, values: $values)';
}
