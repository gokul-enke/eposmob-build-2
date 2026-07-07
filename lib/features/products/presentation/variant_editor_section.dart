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
  final List<VariantAttributeRow> attributes;
  bool isGeneratingBarcode = false;

  VariantRow({
    this.id,
    String sku = '',
    String barcode = '',
    String price = '',
    String mrp = '',
    String purchasePrice = '',
    List<VariantAttributeRow>? attributes,
  })  : skuController = TextEditingController(text: sku),
        barcodeController = TextEditingController(text: barcode),
        priceController = TextEditingController(text: price),
        mrpController = TextEditingController(text: mrp),
        purchasePriceController = TextEditingController(text: purchasePrice),
        attributes = attributes ?? [VariantAttributeRow()];

  VariantFormInput toInput() {
    return VariantFormInput(
      id: id,
      sku: skuController.text,
      barcode: barcodeController.text,
      price: priceController.text,
      mrp: mrpController.text,
      purchasePrice: purchasePriceController.text,
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
    for (final attr in attributes) {
      attr.dispose();
    }
  }
}

/// Owns the variant rows for a modal and produces the payload inputs.
class VariantEditorController {
  final List<VariantRow> rows = [];

  /// Ids of existing variants the user removed (edit flow).
  final List<int> deletedVariantIds = [];

  bool get hasRows => rows.isNotEmpty;

  void addRow() => rows.add(VariantRow());

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
          ...List.generate(
            controller.rows.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == controller.rows.length - 1 ? 0 : 10,
              ),
              child: _buildVariantCard(controller.rows[index], index),
            ),
          ),
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

  Widget _buildVariantCard(VariantRow row, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant ${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => widget.controller.removeRow(index)),
                splashRadius: 18,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          // Attributes.
          ...List.generate(
            row.attributes.length,
            (attrIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttributeRow(row, attrIndex),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                row.attributes.add(VariantAttributeRow());
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Attribute'),
              style: TextButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // SKU + Barcode.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildTextField(
                  'SKU (optional)',
                  row.skuController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBarcodeField(row),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Prices.
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Price',
                  row.priceController,
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  'MRP',
                  row.mrpController,
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  'Purchase Price',
                  row.purchasePriceController,
                  numeric: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(VariantRow row, int attrIndex) {
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
                },
                displayText: (prop) => prop.label,
                searchController: attr.propSearchController,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAttributeValueField(attr, selectedProp),
        ),
        IconButton(
          onPressed: row.attributes.length <= 1
              ? null
              : () => setState(() {
                    row.attributes.removeAt(attrIndex).dispose();
                  }),
          splashRadius: 16,
          icon: const Icon(Icons.close, size: 18, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildAttributeValueField(
    VariantAttributeRow attr,
    ProductProperty? prop,
  ) {
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
            },
            displayText: (value) => value,
            searchController: attr.valueSearchController,
          ),
        ],
      );
    }
    return _buildTextField('Value', attr.valueController);
  }

  Widget _buildBarcodeField(VariantRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Barcode (optional)',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _plainField(row.barcodeController),
            ),
            if (widget.onGenerateBarcode != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                width: 42,
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome,
                          size: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ],
    );
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
