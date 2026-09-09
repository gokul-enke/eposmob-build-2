import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/payment_method_registry.dart';

/// Presentation helper for payment methods.
///
/// Orders store payment methods as machine codes (`CARD`, `CASH`, a tenant's
/// own code), which must never be translated — see [PaymentMethodRegistry].
/// This turns one of those codes into text for the active app locale.
class PaymentMethodDisplay {
  PaymentMethodDisplay._();

  /// Display label for a single stored payment-method code.
  ///
  /// Order of preference:
  /// 1. The loaded method's own label, which carries backend translations and
  ///    so covers tenant-defined methods the app has never heard of.
  /// 2. The app's bundled string for a core code ([UiCodeLabels.payment]),
  ///    which still works when the registry is cold or the backend has shipped
  ///    no translations for the active language.
  /// 3. The raw code, so an unrecognised method still renders something.
  static String labelFor(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';

    final method = PaymentMethodRegistry.find(raw);
    if (method != null) {
      final label = method.label.trim();
      // An untranslated backend resolves `label` back to the code itself
      // (`PaymentMethod.fromJson` falls back to `value`), and showing `CARD`
      // is exactly what we are here to avoid — let the bundled string win.
      if (label.isNotEmpty && label.toLowerCase() != raw.toLowerCase()) {
        return label;
      }
    }

    return UiCodeLabels.payment(raw);
  }

  /// Display label for the `payment_method` field of an order.
  ///
  /// [OrderDetailsModelDataPaymentDetails] joins the API's `payment_method`
  /// array into one comma-separated string, so a split order arrives as
  /// `"CASH, CARD"`. Localizing that whole string would match nothing; each
  /// code has to be resolved on its own.
  static String labelForCodeList(String? value, {String separator = ', '}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';

    final labels = <String>[];
    for (final part in raw.split(',')) {
      final label = labelFor(part);
      if (label.isNotEmpty) labels.add(label);
    }

    return labels.isEmpty ? raw : labels.join(separator);
  }
}
