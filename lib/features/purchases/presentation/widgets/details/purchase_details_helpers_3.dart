part of 'purchase_details_view.dart';

class _DisplayFormatter {
  static String asText(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  static String? firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  static int toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(asText(value)) ?? 0;
  }

  static double toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(asText(value)) ?? 0;
  }

  static String number(dynamic value) {
    final text = asText(value);
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text.isEmpty ? '0' : text;
    }
    return parsed.toStringAsFixed(2);
  }

  static String currency(dynamic value, {String currency = 'SAR'}) {
    final text = asText(value);
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text.isEmpty ? '$currency 0.00' : '$currency $text';
    }
    return '$currency ${parsed.toStringAsFixed(2)}';
  }

  static String? calculatedTotal(dynamic quantity, dynamic unitPrice) {
    final qty = double.tryParse(asText(quantity));
    final price = double.tryParse(asText(unitPrice));
    if (qty == null || price == null) {
      return null;
    }
    return (qty * price).toStringAsFixed(2);
  }

  static String date(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    final months = [
      'purchase_order.month_jan'.tr,
      'purchase_order.month_feb'.tr,
      'purchase_order.month_mar'.tr,
      'purchase_order.month_apr'.tr,
      'purchase_order.month_may'.tr,
      'purchase_order.month_jun'.tr,
      'purchase_order.month_jul'.tr,
      'purchase_order.month_aug'.tr,
      'purchase_order.month_sep'.tr,
      'purchase_order.month_oct'.tr,
      'purchase_order.month_nov'.tr,
      'purchase_order.month_dec'.tr,
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  static String? entityName(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return firstNonEmpty([
        asText(raw['name']),
        asText(raw['title']),
      ]);
    }
    return null;
  }

  static GetProduct? findProduct(
    List<GetProduct>? gridProvider,
    int? productId,
  ) {
    if (productId == null || productId == 0) {
      return null;
    }

    final products = gridProvider;
    if (products == null) {
      return null;
    }

    for (final product in products) {
      if (product.productId == productId) {
        return product;
      }
    }
    return null;
  }

  static String? findCategoryName(
    List<Category> categoryProvider,
    int? categoryId,
  ) {
    if (categoryId == null || categoryId == 0) {
      return null;
    }

    for (final cat in categoryProvider) {
      if (cat.categoryId == categoryId) return cat.categoryName;
    }

    return null;
  }

  static String orderStatus(dynamic status) {
    final normalized = asText(status).toLowerCase();
    switch (normalized) {
      case 'fully_received':
        return 'purchase_order.fully_received'.tr;
      case 'partially_received':
        return 'purchase_order.partially_received'.tr;
      case 'pending':
        return 'purchase_order.pending'.tr;
      case 'y':
        return 'purchase_order.active'.tr;
      case 'n':
        return 'purchase_order.inactive'.tr;
      default:
        return normalized.isEmpty
            ? '-'
            : normalized
                .split('_')
                .map(
                  (part) => part.isEmpty
                      ? part
                      : '${part[0].toUpperCase()}${part.substring(1)}',
                )
                .join(' ');
    }
  }

  static _StatusDisplay itemStatus(dynamic status) {
    final normalized = asText(status).toUpperCase();
    switch (normalized) {
      case 'Y':
      case 'RECEIVED':
      case 'FULLY_RECEIVED':
        return _StatusDisplay(
          label: 'purchase_order.received'.tr,
          color: const Color(0xFF0F8A44),
          backgroundColor: const Color(0xFFDDF7E5),
        );
      case 'PARTIALLY_RECEIVED':
        return _StatusDisplay(
          label: 'purchase_order.partial'.tr,
          color: const Color(0xFF9A6700),
          backgroundColor: const Color(0xFFFFF1CC),
        );
      default:
        return _StatusDisplay(
          label: 'purchase_order.pending'.tr,
          color: const Color(0xFF6B7280),
          backgroundColor: const Color(0xFFEFF1F4),
        );
    }
  }
}
