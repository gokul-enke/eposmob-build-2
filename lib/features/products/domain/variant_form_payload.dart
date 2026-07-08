/// Pure (widget-free) logic for turning variant editor rows into the
/// `variants[]` payload described in PRODUCT_VARIANTS_API.md (sections 1 & 2).
///
/// Both the create modal (add_product_modal.dart) and the edit dialog
/// (product_details_dialog.dart) convert their stateful rows into
/// [VariantFormInput] values and call the builders here, so the payload shape
/// stays in one testable place.
library;

/// A single `product_prop_id` + `value` attribute selection on a variant row.
class VariantAttributeInput {
  final int productPropId;
  final String? value;

  const VariantAttributeInput({
    required this.productPropId,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        'product_prop_id': productPropId,
        'value': _trimToNull(value),
      };
}

/// Plain-data snapshot of one variant editor row.
class VariantFormInput {
  /// Existing variant id (edit flow). `null` for newly added rows.
  final int? id;

  final String? sku;
  final String? barcode;
  final String? price;
  final String? mrp;
  final String? purchasePrice;

  /// When true (edit flow only), the row represents a variant to delete.
  final bool markedForDeletion;

  final List<VariantAttributeInput> attributes;

  const VariantFormInput({
    this.id,
    this.sku,
    this.barcode,
    this.price,
    this.mrp,
    this.purchasePrice,
    this.markedForDeletion = false,
    this.attributes = const [],
  });

  /// Attributes that actually carry a non-empty value.
  List<VariantAttributeInput> get filledAttributes => attributes
      .where((attr) => (attr.value?.trim().isNotEmpty ?? false))
      .toList(growable: false);
}

/// Builds a single variant map (create/update, never delete).
Map<String, dynamic> buildVariantJson(VariantFormInput row) {
  final map = <String, dynamic>{};
  if (row.id != null) {
    map['id'] = row.id;
  }
  map['sku'] = _trimToNull(row.sku);
  map['barcode'] = _trimToNull(row.barcode);
  map['price'] = _parseNumOrNull(row.price);
  map['mrp'] = _parseNumOrNull(row.mrp);
  map['purchase_price'] = _parseNumOrNull(row.purchasePrice);
  map['active'] = true;
  // The server replaces attributes wholesale on every update, so always send
  // the complete set for the row.
  map['attributes'] = row.filledAttributes
      .map((attr) => {
            'product_prop_id': attr.productPropId,
            'value': _trimToNull(attr.value),
          })
      .toList();
  return map;
}

/// Create flow (§1). All rows become new variants; deletion flags are ignored.
List<Map<String, dynamic>> buildCreateVariantsPayload(
    List<VariantFormInput> rows) {
  return rows
      .where((row) => !row.markedForDeletion)
      .map(buildVariantJson)
      .toList();
}

/// Edit flow (§2). Rows with an id → update, without id → create, and
/// deletion-flagged rows that have an id → `{id, _delete: true}`.
/// A deletion-flagged row without an id was never persisted, so it is dropped.
List<Map<String, dynamic>> buildEditVariantsPayload(
    List<VariantFormInput> rows) {
  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    if (row.markedForDeletion) {
      if (row.id != null) {
        result.add({'id': row.id, '_delete': true});
      }
      continue;
    }
    result.add(buildVariantJson(row));
  }
  return result;
}

/// Validates the editor rows. Returns an error message, or null when valid.
///
/// Only non-deleted rows are checked:
///  - each row needs at least one attribute with a value;
///  - attribute sets must be unique across rows;
///  - barcodes (when present) must be unique across rows;
///  - price / mrp / purchase_price must be numeric >= 0 when present.
String? validateVariantRows(List<VariantFormInput> rows) {
  final activeRows =
      rows.where((row) => !row.markedForDeletion).toList(growable: false);

  final attributeSignatures = <String>{};
  final usedBarcodes = <String>{};

  for (var i = 0; i < activeRows.length; i++) {
    final row = activeRows[i];
    final label = 'Variant ${i + 1}';

    final filled = row.filledAttributes;
    if (filled.isEmpty) {
      return '$label needs at least one attribute with a value.';
    }

    final signature = _attributeSignature(filled);
    if (!attributeSignatures.add(signature)) {
      return 'Two variants have the same attributes. Each variant must be unique.';
    }

    final barcode = row.barcode?.trim() ?? '';
    if (barcode.isNotEmpty && !usedBarcodes.add(barcode)) {
      return 'Variant barcodes must be unique ("$barcode" is repeated).';
    }

    for (final entry in <String, String?>{
      'price': row.price,
      'mrp': row.mrp,
      'purchase price': row.purchasePrice,
    }.entries) {
      final error = _validateOptionalPrice(entry.value, entry.key, label);
      if (error != null) return error;
    }
  }

  return null;
}

String _attributeSignature(List<VariantAttributeInput> attributes) {
  final parts = attributes
      .map((attr) => '${attr.productPropId}:${attr.value?.trim() ?? ''}')
      .toList()
    ..sort();
  return parts.join('|');
}

String? _validateOptionalPrice(String? raw, String field, String label) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = num.tryParse(text);
  if (parsed == null || parsed < 0) {
    return '$label $field must be a number >= 0.';
  }
  return null;
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

num? _parseNumOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return num.tryParse(trimmed);
}
