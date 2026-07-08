import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/product_property.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// One attribute selection (property + value) inside a [VariantRow].
class VariantAttributeRow {
  int? productPropId;
  final TextEditingController valueController;
  final TextEditingController valueSearchController;
  final TextEditingController propSearchController;

  /// A prop code that came from an existing variant but could not be matched
  /// against the fetched properties. Kept only for display/debugging.
  final String? unmatchedCode;

  VariantAttributeRow({
    this.productPropId,
    String value = '',
    this.unmatchedCode,
  })  : valueController = TextEditingController(text: value),
        valueSearchController = TextEditingController(),
        propSearchController = TextEditingController();

  void dispose() {
    valueController.dispose();
    valueSearchController.dispose();
    propSearchController.dispose();
  }
}

/// A single variant editor row backed by [TextEditingController]s.
class VariantRow {
  /// Existing variant id (edit flow); null for new rows.
  int? id;
  final TextEditingController skuController;
  final TextEditingController barcodeController;
  final TextEditingController priceController;
  final TextEditingController mrpController;
  final TextEditingController purchasePriceController;
  final TextEditingController quantityController;
  final List<VariantAttributeRow> attributes;
  bool isGeneratingBarcode = false;
  bool active;

  VariantRow({
    this.id,
    String sku = '',
    String barcode = '',
    String price = '',
    String mrp = '',
    String purchasePrice = '',
    String quantity = '',
    this.active = true,
    List<VariantAttributeRow>? attributes,
  })  : skuController = TextEditingController(text: sku),
        barcodeController = TextEditingController(text: barcode),
        priceController = TextEditingController(text: price),
        mrpController = TextEditingController(text: mrp),
        purchasePriceController = TextEditingController(text: purchasePrice),
        quantityController = TextEditingController(text: quantity),
        attributes = attributes ?? [VariantAttributeRow()];

  VariantFormInput toInput() {
    return VariantFormInput(
      id: id,
      sku: skuController.text,
      barcode: barcodeController.text,
      price: priceController.text,
      mrp: mrpController.text,
      purchasePrice: purchasePriceController.text,
      quantity: quantityController.text,
      active: active,
      attributes: attributes
          .where((attr) => attr.productPropId != null)
          .map((attr) => VariantAttributeInput(
                productPropId: attr.productPropId!,
                value: attr.valueController.text,
              ))
          .toList(),
    );
  }

  void dispose() {
    skuController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    mrpController.dispose();
    purchasePriceController.dispose();
    quantityController.dispose();
    for (final attr in attributes) {
      attr.dispose();
    }
  }
}

/// One option type (e.g. "Colour") with the values chosen for it (e.g.
/// "Red", "Blue"), used by [VariantEditorController.generateFromOptions] to
/// build the cartesian product of variants, Shopify-style.
class VariantOptionGroup {
  int? productPropId;
  final List<String> values = [];
  final TextEditingController valueInputController = TextEditingController();
  final TextEditingController propSearchController = TextEditingController();

  void dispose() {
    valueInputController.dispose();
    propSearchController.dispose();
  }
}

/// Owns the variant rows for a modal and produces the payload inputs.
class VariantEditorController {
  final List<VariantRow> rows = [];

  /// Ids of existing variants the user removed (edit flow).
  final List<int> deletedVariantIds = [];

  /// Option types (e.g. Colour, Size) used to auto-generate [rows].
  final List<VariantOptionGroup> optionGroups = [];

  bool get hasRows => rows.isNotEmpty;

  void addRow() => rows.add(VariantRow());

  void addOptionGroup() => optionGroups.add(VariantOptionGroup());

  void removeOptionGroup(int index) {
    optionGroups.removeAt(index).dispose();
  }

  String _signatureFor(VariantRow row) {
    final parts = row.attributes
        .where((attr) => attr.productPropId != null)
        .map((attr) =>
            '${attr.productPropId}:${attr.valueController.text.trim()}')
        .toList()
      ..sort();
    return parts.join('|');
  }

  /// Builds the cartesian product of all configured [optionGroups] and
  /// replaces [rows] with it. Existing rows whose attribute combination still
  /// appears (matched by property id + value) are kept as-is so any
  /// price/SKU/barcode already entered is preserved; combinations no longer
  /// selected are removed (and queued for deletion if they were persisted).
  void generateFromOptions() {
    final groups = optionGroups
        .where((g) => g.productPropId != null && g.values.isNotEmpty)
        .toList(growable: false);
    if (groups.isEmpty) return;

    List<List<MapEntry<int, String>>> combos = [<MapEntry<int, String>>[]];
    for (final group in groups) {
      final next = <List<MapEntry<int, String>>>[];
      for (final combo in combos) {
        for (final value in group.values) {
          next.add([...combo, MapEntry(group.productPropId!, value)]);
        }
      }
      combos = next;
    }

    final existingBySignature = <String, VariantRow>{
      for (final row in rows) _signatureFor(row): row,
    };

    final newRows = <VariantRow>[];
    final usedSignatures = <String>{};
    for (final combo in combos) {
      final signature = (combo.map((e) => '${e.key}:${e.value}').toList()
            ..sort())
          .join('|');
      usedSignatures.add(signature);
      final existing = existingBySignature[signature];
      if (existing != null) {
        newRows.add(existing);
      } else {
        newRows.add(
          VariantRow(
            attributes: combo
                .map((e) => VariantAttributeRow(
                      productPropId: e.key,
                      value: e.value,
                    ))
                .toList(),
          ),
        );
      }
    }

    for (final row in rows) {
      if (!usedSignatures.contains(_signatureFor(row))) {
        if (row.id != null) deletedVariantIds.add(row.id!);
        row.dispose();
      }
    }

    rows
      ..clear()
      ..addAll(newRows);
  }

  void removeRow(int index) {
    final row = rows.removeAt(index);
    if (row.id != null) {
      deletedVariantIds.add(row.id!);
    }
    row.dispose();
  }

  /// Rebuilds rows from an existing product's variants (edit flow prefill).
  ///
  /// [properties] is used to translate each variant's flattened
  /// `{PROP_CODE: value}` attribute map back into property-id selections.
  void loadFromVariants(
    List<ProductVariant> variants,
    List<ProductProperty> properties,
  ) {
    clear();
    final byCode = <String, ProductProperty>{
      for (final prop in properties) prop.code.toUpperCase(): prop,
    };

    for (final variant in variants) {
      final attrRows = <VariantAttributeRow>[];
      variant.attributes.forEach((code, value) {
        final match = byCode[code.toUpperCase()];
        attrRows.add(
          VariantAttributeRow(
            productPropId: match?.id,
            value: value?.toString() ?? '',
            unmatchedCode: match == null ? code : null,
          ),
        );
      });
      if (attrRows.isEmpty) {
        attrRows.add(VariantAttributeRow());
      }
      rows.add(
        VariantRow(
          id: variant.id,
          sku: variant.sku ?? '',
          barcode: variant.barcode ?? '',
          price: _numToString(variant.price),
          mrp: _numToString(variant.mrp),
          purchasePrice: _numToString(variant.purchasePrice),
          quantity: _numToString(variant.quantity?.toDouble()),
          active: variant.active,
          attributes: attrRows,
        ),
      );
    }
  }

  List<VariantFormInput> toCreateInputs() =>
      rows.map((row) => row.toInput()).toList();

  List<VariantFormInput> toEditInputs() {
    final list = rows.map((row) => row.toInput()).toList();
    for (final id in deletedVariantIds) {
      list.add(VariantFormInput(
          id: id, markedForDeletion: true, attributes: const []));
    }
    return list;
  }

  void clear() {
    for (final row in rows) {
      row.dispose();
    }
    rows.clear();
    deletedVariantIds.clear();
    for (final group in optionGroups) {
      group.dispose();
    }
    optionGroups.clear();
  }

  void dispose() => clear();

  static String _numToString(double? value) {
    if (value == null) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

/// Signature: generate a unique barcode into [target], toggling [setLoading].
typedef GenerateBarcodeCallback = Future<void> Function(
  TextEditingController target,
  void Function(bool loading) setLoading,
);

/// The variants editor section shared by the create modal and edit dialog.
class VariantEditorSection extends StatefulWidget {
  final VariantEditorController controller;
  final List<ProductProperty> properties;
  final bool isLoadingProperties;
  final GenerateBarcodeCallback? onGenerateBarcode;
  final VoidCallback? onRetryLoadProperties;

  const VariantEditorSection({
    super.key,
    required this.controller,
    required this.properties,
    this.isLoadingProperties = false,
    this.onGenerateBarcode,
    this.onRetryLoadProperties,
  });

  @override
  State<VariantEditorSection> createState() => _VariantEditorSectionState();
}

class _VariantEditorSectionState extends State<VariantEditorSection> {
  final ScrollController _tableScrollController = ScrollController();

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Variants',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.isLoadingProperties)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Add sellable variations (e.g. Colour / Size). Each variant needs at '
            'least one attribute with a value.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (widget.properties.isEmpty && !widget.isLoadingProperties)
            _buildNoPropertiesNotice(),
          if (widget.properties.isNotEmpty) _buildOptionGeneratorPanel(),
          if (controller.rows.isNotEmpty) ...[
            const Text(
              'Variants',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildVariantsTable(),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => controller.addRow());
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Variant'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor,
                side: BorderSide(color: ColorManager.kPrimaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGeneratorPanel() {
    final controller = widget.controller;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Options',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Text(
            'Define option types (e.g. Colour: Red, Blue) and generate every '
            'combination as a variant automatically.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            controller.optionGroups.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOptionGroupRow(controller.optionGroups[index], index),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => controller.addOptionGroup()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Option'),
                style: TextButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                ),
              ),
              if (controller.optionGroups.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => controller.generateFromOptions()),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Generate Variants'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroupRow(VariantOptionGroup group, int index) {
    final selectedProp = _propertyById(group.productPropId);
    final propertyDropdown = CustomDropDownWithSearch<ProductProperty>(
      title: '',
      hintText: 'Select option',
      value: selectedProp,
      height: 42,
      margin: EdgeInsets.zero,
      items: widget.properties,
      onChanged: (prop) {
        setState(() {
          group.productPropId = prop?.id;
          group.values.clear();
        });
      },
      displayText: (prop) => prop.label,
      searchController: group.propSearchController,
    );
    final deleteButton = IconButton(
      onPressed: () => setState(() => widget.controller.removeOptionGroup(index)),
      splashRadius: 16,
      icon: const Icon(Icons.close, size: 18, color: Colors.black45),
    );
    final valuesInput = _buildOptionValuesInput(group, selectedProp);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below ~420px (mobile) the property dropdown and value picker don't
        // both fit on one line; stack them instead of overflowing.
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: propertyDropdown),
                  deleteButton,
                ],
              ),
              const SizedBox(height: 8),
              valuesInput,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 160, child: propertyDropdown),
            const SizedBox(width: 8),
            Expanded(child: valuesInput),
            deleteButton,
          ],
        );
      },
    );
  }

  Widget _buildOptionValuesInput(VariantOptionGroup group, ProductProperty? prop) {
    final availableValues =
        (prop != null && prop.isList) ? prop.values : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.values.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in group.values)
                Chip(
                  label: Text(value, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onDeleted: () => setState(() => group.values.remove(value)),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (availableValues.isNotEmpty)
          CustomDropDownWithSearch<String>(
            title: '',
            hintText: 'Add value',
            value: null,
            height: 42,
            margin: EdgeInsets.zero,
            items: availableValues
                .where((v) => !group.values.contains(v))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => group.values.add(value));
            },
            displayText: (value) => value,
            searchController: group.valueInputController,
          )
        else
          Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: group.valueInputController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type value + Enter',
                hintStyle: TextStyle(fontSize: 11, color: Colors.black38),
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) return;
                setState(() {
                  if (!group.values.contains(trimmed)) {
                    group.values.add(trimmed);
                  }
                  group.valueInputController.clear();
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNoPropertiesNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'No product properties are available. Variants need at least one '
              'property (attribute) configured.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          ),
          if (widget.onRetryLoadProperties != null)
            TextButton(
              onPressed: widget.onRetryLoadProperties,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  static const double _colAttr = 230;
  static const double _colSku = 100;
  static const double _colBarcode = 150;
  static const double _colPrice = 80;
  static const double _colMrp = 80;
  static const double _colPurchase = 90;
  static const double _colQty = 70;
  static const double _colActive = 52;
  static const double _colDelete = 36;
  static const double _colGap = 8;

  // Row content has 7 inter-column gaps (no gap between the Active checkbox
  // and the delete icon), plus each variant row's Container adds 8px padding
  // and a 1px border on both sides.
  static const double _tableContentWidth = _colAttr +
      _colSku +
      _colBarcode +
      _colPrice +
      _colMrp +
      _colPurchase +
      _colQty +
      _colActive +
      _colDelete +
      _colGap * 7 +
      (8 + 1) * 2;

  static const _tableHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.black54,
  );

  Widget _buildVariantsTable() {
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTableHeaderRow(),
            const SizedBox(height: 8),
            ...List.generate(
              controller.rows.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildVariantTableRow(controller.rows[index], index),
              ),
            ),
          ],
        );

        // Only wrap in a horizontal scrollbar when the table is actually
        // wider than the space available (small screens); otherwise let it
        // size to the available width so it doesn't scroll needlessly.
        if (constraints.maxWidth >= _tableContentWidth) {
          return SizedBox(width: _tableContentWidth, child: table);
        }

        return Scrollbar(
          controller: _tableScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _tableScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(width: _tableContentWidth, child: table),
          ),
        );
      },
    );
  }

  Widget _buildTableHeaderRow() {
    return Row(
      children: [
        const SizedBox(width: _colAttr, child: Text('Attributes', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colSku, child: Text('SKU', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colBarcode, child: Text('Barcode', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colPrice, child: Text('Price', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colMrp, child: Text('MRP', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colPurchase, child: Text('Purchase Price', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colQty, child: Text('Qty', style: _tableHeaderStyle)),
        const SizedBox(width: _colGap),
        const SizedBox(width: _colActive, child: Text('Active', style: _tableHeaderStyle)),
        const SizedBox(width: _colDelete),
      ],
    );
  }

  Widget _buildVariantTableRow(VariantRow row, int index) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _colAttr, child: _buildAttributeSummaryCell(row)),
          const SizedBox(width: _colGap),
          SizedBox(height: 42, width: _colSku, child: _plainField(row.skuController)),
          const SizedBox(width: _colGap),
          SizedBox(width: _colBarcode, child: _buildBarcodeTableCell(row)),
          const SizedBox(width: _colGap),
          SizedBox(height: 42, width: _colPrice, child: _plainField(row.priceController, numeric: true)),
          const SizedBox(width: _colGap),
          SizedBox(height: 42, width: _colMrp, child: _plainField(row.mrpController, numeric: true)),
          const SizedBox(width: _colGap),
          SizedBox(height: 42, width: _colPurchase, child: _plainField(row.purchasePriceController, numeric: true)),
          const SizedBox(width: _colGap),
          SizedBox(height: 42, width: _colQty, child: _plainField(row.quantityController, numeric: true)),
          const SizedBox(width: _colGap),
          SizedBox(
            height: 42,
            width: _colActive,
            child: Checkbox(
              value: row.active,
              onChanged: (value) => setState(() => row.active = value ?? true),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(
            height: 42,
            width: _colDelete,
            child: IconButton(
              onPressed: () => setState(() => widget.controller.removeRow(index)),
              splashRadius: 16,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeSummaryCell(VariantRow row) {
    final filled = row.attributes
        .where((attr) => attr.valueController.text.trim().isNotEmpty)
        .toList();

    return InkWell(
      onTap: () => _openAttributeEditor(row),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: filled.isEmpty
                  ? const Text(
                      'No attributes',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    )
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: filled.map((attr) {
                        final prop = _propertyById(attr.productPropId);
                        final label = prop?.label ?? attr.unmatchedCode ?? '?';
                        return Chip(
                          label: Text(
                            '$label: ${attr.valueController.text.trim()}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                        );
                      }).toList(),
                    ),
            ),
            const Icon(Icons.edit, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttributeEditor(VariantRow row) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Attributes'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(
                      row.attributes.length,
                      (attrIndex) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildAttributeRow(
                          row,
                          attrIndex,
                          extraRefresh: () => setDialogState(() {}),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDialogState(() {
                          row.attributes.add(VariantAttributeRow());
                        }),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Attribute'),
                        style: TextButton.styleFrom(
                          foregroundColor: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _buildBarcodeTableCell(VariantRow row) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(height: 42, child: _plainField(row.barcodeController)),
        ),
        if (widget.onGenerateBarcode != null) ...[
          const SizedBox(width: 6),
          SizedBox(
            height: 36,
            width: 36,
            child: ElevatedButton(
              onPressed: row.isGeneratingBarcode
                  ? null
                  : () async {
                      await widget.onGenerateBarcode!(
                        row.barcodeController,
                        (loading) => row.isGeneratingBarcode = loading,
                      );
                      if (mounted) setState(() {});
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: row.isGeneratingBarcode
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttributeRow(
    VariantRow row,
    int attrIndex, {
    VoidCallback? extraRefresh,
  }) {
    final attr = row.attributes[attrIndex];
    final selectedProp = _propertyById(attr.productPropId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attribute',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              CustomDropDownWithSearch<ProductProperty>(
                title: '',
                hintText: 'Select attribute',
                value: selectedProp,
                height: 42,
                margin: EdgeInsets.zero,
                items: widget.properties,
                onChanged: (prop) {
                  setState(() {
                    attr.productPropId = prop?.id;
                    // Reset value when the property changes.
                    attr.valueController.text = '';
                  });
                  extraRefresh?.call();
                },
                displayText: (prop) => prop.label,
                searchController: attr.propSearchController,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAttributeValueField(attr, selectedProp, extraRefresh: extraRefresh),
        ),
        IconButton(
          onPressed: row.attributes.length <= 1
              ? null
              : () {
                  setState(() {
                    row.attributes.removeAt(attrIndex).dispose();
                  });
                  extraRefresh?.call();
                },
          splashRadius: 16,
          icon: const Icon(Icons.close, size: 18, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildAttributeValueField(
    VariantAttributeRow attr,
    ProductProperty? prop, {
    VoidCallback? extraRefresh,
  }) {
    if (prop != null && prop.isList && prop.values.isNotEmpty) {
      final currentValue = attr.valueController.text.trim();
      final selected = prop.values.contains(currentValue) ? currentValue : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Value',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          CustomDropDownWithSearch<String>(
            title: '',
            hintText: 'Select value',
            value: selected,
            height: 42,
            margin: EdgeInsets.zero,
            items: prop.values,
            onChanged: (value) {
              setState(() {
                attr.valueController.text = value ?? '';
              });
              extraRefresh?.call();
            },
            displayText: (value) => value,
            searchController: attr.valueSearchController,
          ),
        ],
      );
    }
    return _buildTextField('Value', attr.valueController);
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        _plainField(controller, numeric: numeric),
      ],
    );
  }

  Widget _plainField(TextEditingController controller, {bool numeric = false}) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))]
            : null,
        cursorColor: ColorManager.kPrimaryColor,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  ProductProperty? _propertyById(int? id) {
    if (id == null) return null;
    for (final prop in widget.properties) {
      if (prop.id == id) return prop;
    }
    return null;
  }
}
