import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Shared sale-unit row used by add-product modal and mobile wizard.
class AddProductSaleUnitRow {
  AddProductSaleUnitRow({
    this.selectedUnitId,
    String conversionRate = '',
    String barcode = '',
    String price = '',
  })  : conversionRateController = TextEditingController(text: conversionRate),
        barcodeController = TextEditingController(text: barcode),
        priceController = TextEditingController(text: price),
        searchController = TextEditingController();

  String? selectedUnitId;
  final TextEditingController conversionRateController;
  final TextEditingController barcodeController;
  final TextEditingController priceController;
  final TextEditingController searchController;
  bool isGeneratingBarcode = false;

  void dispose() {
    conversionRateController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    searchController.dispose();
  }
}

/// Business logic shared between desktop modal and mobile add-product flow.
class AddProductFormHelpers {
  AddProductFormHelpers._();

  static Language? getBaseLanguage(List<Language> languages) {
    if (languages.isEmpty) return null;
    try {
      return languages.firstWhere((lang) => lang.code.toLowerCase() == 'en');
    } catch (_) {
      return languages.first;
    }
  }

  static String formatNum(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static String formatDynamicNumber(dynamic value) {
    if (value == null) return '';
    if (value is num) return formatNum(value);
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    final parsed = num.tryParse(text);
    return parsed != null ? formatNum(parsed) : text;
  }

  static String extractTranslatedName(dynamic names, Language language) {
    if (names == null) return '';
    final targetCode = language.code.toLowerCase();

    if (names is Map) {
      final direct = names[targetCode] ?? names[language.code];
      if (direct != null) {
        if (direct is String) return direct;
        if (direct is Map) {
          final fromMap = direct['name'] ?? direct['value'];
          if (fromMap != null) return fromMap.toString();
        }
      }

      for (final value in names.values) {
        if (value is Map) {
          final code = value['code']?.toString().toLowerCase() ??
              value['language_code']?.toString().toLowerCase();
          final languageId = value['language_id']?.toString();
          if (code == targetCode || languageId == language.id.toString()) {
            final name = value['name'] ?? value['value'];
            if (name != null) return name.toString();
          }
        }
      }
    }

    if (names is List) {
      for (final value in names) {
        if (value is Map) {
          final code = value['code']?.toString().toLowerCase() ??
              value['language_code']?.toString().toLowerCase();
          final languageId = value['language_id']?.toString();
          if (code == targetCode || languageId == language.id.toString()) {
            final name = value['name'] ?? value['value'];
            if (name != null) return name.toString();
          }
        }
      }
    }

    return '';
  }

  static String getAutofillQuantity(GetProduct product) {
    final stockQuantity = product.stock?.fold<num>(
      0,
      (sum, stock) => sum + (stock.quantity ?? 0),
    );

    if (stockQuantity != null && stockQuantity > 0) {
      return formatNum(stockQuantity);
    }

    final available = product.numberOfProductsAvailable?.trim();
    if (available != null && available.isNotEmpty) {
      return available;
    }

    return '0';
  }

  static String getAvailableQuantity(GetProduct product) {
    final stockQuantity = product.stock?.fold<num>(
      0,
      (sum, stock) => sum + (stock.quantity ?? 0),
    );

    if (stockQuantity != null && stockQuantity > 0) {
      return formatNum(stockQuantity);
    }

    final available = product.numberOfProductsAvailable?.trim();
    if (available != null && available.isNotEmpty) {
      return available;
    }

    return '-';
  }

  static Category? resolveCategory(
    GetProduct product,
    List<Category> categories,
  ) {
    if (product.categoryId != null) {
      for (final category in categories) {
        if (category.categoryId == product.categoryId) {
          return category;
        }
      }
    }

    final productCategoryName = product.category?.name?.trim().toLowerCase();
    if (productCategoryName != null && productCategoryName.isNotEmpty) {
      for (final category in categories) {
        if (category.categoryName?.trim().toLowerCase() == productCategoryName) {
          return category;
        }
      }
    }

    return null;
  }

  static String? resolveUnitValue(
    String? unit,
    Map<String, String> unitList,
  ) {
    final trimmedUnit = unit?.trim();
    if (trimmedUnit == null || trimmedUnit.isEmpty) {
      return null;
    }

    if (unitList.containsKey(trimmedUnit)) {
      return trimmedUnit;
    }

    final normalizedUnit = trimmedUnit.toLowerCase();
    for (final entry in unitList.entries) {
      if (entry.key.toLowerCase() == normalizedUnit ||
          entry.value.toLowerCase() == normalizedUnit) {
        return entry.key;
      }
    }

    return trimmedUnit;
  }

  static String resolveUnitLabel(String? unitId, Map<String, String>? unitList) {
    if (unitId == null || unitId.isEmpty) {
      return 'Select unit';
    }
    return unitList?[unitId] ?? unitId;
  }

  static Set<String> collectCurrentFormBarcodes({
    required String mainBarcode,
    required List<AddProductSaleUnitRow> saleUnitRows,
    TextEditingController? excludeController,
    TextEditingController? mainBarcodeController,
  }) {
    final usedBarcodes = <String>{};

    void addBarcode(String? value, TextEditingController controller) {
      if (excludeController != null &&
          identical(controller, excludeController)) {
        return;
      }
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        usedBarcodes.add(trimmed);
      }
    }

    if (mainBarcodeController != null) {
      addBarcode(mainBarcodeController.text, mainBarcodeController);
    } else {
      final trimmed = mainBarcode.trim();
      if (trimmed.isNotEmpty) {
        usedBarcodes.add(trimmed);
      }
    }

    for (final row in saleUnitRows) {
      addBarcode(row.barcodeController.text, row.barcodeController);
    }

    return usedBarcodes;
  }

  static bool barcodeExistsInLocalProducts(
    LocalProductProvider provider,
    String barcode,
  ) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return false;
    return provider.filterProductByBarcode(barCode: normalized).isNotEmpty;
  }

  static String incrementBarcodeString(String barcode, int step) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return trimmed;

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      final nextValue = BigInt.parse(trimmed) + BigInt.from(step);
      final nextText = nextValue.toString();
      return nextText.length < trimmed.length
          ? nextText.padLeft(trimmed.length, '0')
          : nextText;
    }

    return '$trimmed-$step';
  }

  static String getNextAvailableBarcode({
    required String seedBarcode,
    required LocalProductProvider productProvider,
    required String mainBarcode,
    required List<AddProductSaleUnitRow> saleUnitRows,
    TextEditingController? excludeController,
    TextEditingController? mainBarcodeController,
  }) {
    final seed = seedBarcode.trim();
    if (seed.isEmpty) return seedBarcode;

    final currentFormBarcodes = collectCurrentFormBarcodes(
      mainBarcode: mainBarcode,
      saleUnitRows: saleUnitRows,
      excludeController: excludeController,
      mainBarcodeController: mainBarcodeController,
    );

    bool isTaken(String candidate) {
      return currentFormBarcodes.contains(candidate) ||
          barcodeExistsInLocalProducts(productProvider, candidate);
    }

    if (!isTaken(seed)) return seed;

    for (int step = 1; step <= 9999; step++) {
      final candidate = incrementBarcodeString(seed, step);
      if (!isTaken(candidate)) return candidate;
    }

    return '${seed}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static List<Map<String, dynamic>> buildProductNamesPayload({
    required List<Language> languages,
    required Map<int, TextEditingController> languageNameControllers,
  }) {
    final payload = <Map<String, dynamic>>[];

    for (final language in languages) {
      final controller = languageNameControllers[language.id];
      final text = controller?.text.trim() ?? '';
      if (text.isNotEmpty) {
        payload.add({
          'language_id': language.id,
          'name': text,
        });
      }
    }

    return payload;
  }

  static List<Map<String, dynamic>> buildSaleUnitsPayload({
    required bool showAdvancedOptions,
    required String? selectedUnit,
    required List<AddProductSaleUnitRow> saleUnitRows,
  }) {
    if (!showAdvancedOptions ||
        selectedUnit == null ||
        saleUnitRows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return saleUnitRows
        .map((row) => {
              'unit_id':
                  int.tryParse(row.selectedUnitId ?? '') ?? row.selectedUnitId,
              'conversion_rate':
                  num.parse(row.conversionRateController.text.trim()),
              'barcode': row.barcodeController.text.trim(),
              'price': num.parse(row.priceController.text.trim()),
            })
        .toList(growable: false);
  }

  static bool validateSaleUnits({
    required bool showAdvancedOptions,
    required String? selectedUnit,
    required String mainBarcode,
    required List<AddProductSaleUnitRow> saleUnitRows,
    required void Function(String message) onError,
  }) {
    if (!showAdvancedOptions || selectedUnit == null) {
      return true;
    }

    final usedUnitIds = <String>{selectedUnit};
    final usedBarcodes = <String>{mainBarcode.trim()};

    for (final row in saleUnitRows) {
      final unitId = row.selectedUnitId?.trim();
      final conversionRate = row.conversionRateController.text.trim();
      final barcode = row.barcodeController.text.trim();

      if (unitId == null || unitId.isEmpty) {
        onError('Select a unit for every added sale unit row.');
        return false;
      }

      if (usedUnitIds.contains(unitId)) {
        onError('Each sale unit must use a different unit.');
        return false;
      }
      usedUnitIds.add(unitId);

      if (conversionRate.isEmpty) {
        onError('Enter a conversion rate for every sale unit.');
        return false;
      }

      final parsedRate = num.tryParse(conversionRate);
      if (parsedRate == null || parsedRate <= 0) {
        onError('Conversion rate must be greater than 0.');
        return false;
      }

      if (barcode.isEmpty) {
        onError('Enter or generate a barcode for every sale unit.');
        return false;
      }

      if (usedBarcodes.contains(barcode)) {
        onError('Sale unit barcodes must be unique.');
        return false;
      }
      usedBarcodes.add(barcode);

      final price = row.priceController.text.trim();
      if (price.isEmpty) {
        onError('Enter a price for every sale unit.');
        return false;
      }

      final parsedPrice = num.tryParse(price);
      if (parsedPrice == null || parsedPrice <= 0) {
        onError('Price must be greater than 0.');
        return false;
      }
    }

    return true;
  }

  /// Parses a quantity string for cart use; invalid or non-positive values
  /// fall back to [defaultValue].
  static num parseAddToCartQuantity(String text, {num defaultValue = 1}) {
    final parsed = num.tryParse(text.trim());
    if (parsed == null || parsed <= 0) return defaultValue;
    return parsed;
  }

  /// Selling price for cart override; only positive values are passed through.
  static double? parseAddToCartSellingPrice(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static String parseCreateProductError(dynamic result) {
    const fallback = 'Failed to add product';
    dynamic response = result;

    if (result is String) {
      final body = result.trim();
      if (body.isEmpty) return fallback;

      try {
        response = json.decode(body);
      } catch (_) {
        return body;
      }
    }

    if (response is Map) {
      // Validation errors from the create-product API are returned in `data`,
      // while some endpoints return them in `errors`.
      final errorMessages = <String>[
        ..._formatValidationErrors(response['data']),
        ..._formatValidationErrors(response['errors']),
      ];
      if (errorMessages.isNotEmpty) {
        return errorMessages.join('\n');
      }

      final message = response['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      final data = response['data']?.toString().trim();
      if (data != null && data.isNotEmpty) {
        return data;
      }
    }

    return result is String && result.trim().isNotEmpty
        ? result.trim()
        : fallback;
  }

  static List<String> _formatValidationErrors(dynamic errors) {
    if (errors is! Map) return const <String>[];

    final messages = <String>[];
    errors.forEach((field, fieldMessages) {
      if (fieldMessages is Iterable) {
        for (final message in fieldMessages) {
          final text = message.toString().trim();
          if (text.isNotEmpty) messages.add('$field: $text');
        }
      } else {
        final text = fieldMessages.toString().trim();
        if (text.isNotEmpty) messages.add('$field: $text');
      }
    });
    return messages;
  }
}
