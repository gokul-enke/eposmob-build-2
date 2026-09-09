import 'package:pos_machine/models/payment_method.dart';

/// Resolves the payment-method *strings* held across orders and receipts back
/// to the loaded [PaymentMethod] they came from.
///
/// ## Why this exists
///
/// Orders persist payment methods as stable machine codes — `payment_method:
/// ["CARD"]` and `payments: {"CARD": "118.000"}` — and that is correct: the
/// `payments` keys are map keys and branch targets (see [PaymentHelper]), so a
/// translated key would turn every lookup into a miss, silently.
///
/// The display side still needs a localized label for those codes. Reading it
/// from [MasterDataProvider] needs a `BuildContext`, which the print and PDF
/// layers do not have, so this mirrors [DeliveryMethodRegistry]: the provider
/// pushes a snapshot whenever payment methods load (from API or cache), and
/// any layer can map a code to its method without plumbing a context through.
class PaymentMethodRegistry {
  PaymentMethodRegistry._();

  static List<PaymentMethod> _methods = const [];

  /// Snapshot of the currently loaded methods. Empty before store bootstrap.
  static List<PaymentMethod> get methods => _methods;

  /// Replaces the snapshot. Called by [MasterDataProvider].
  static void update(List<PaymentMethod>? methods) {
    _methods =
        methods == null ? const [] : List<PaymentMethod>.unmodifiable(methods);
  }

  static void clear() {
    _methods = const [];
  }

  /// Finds the method a stored string refers to.
  ///
  /// Matches, in order: the stable `code`, the backend id, the server-resolved
  /// label, and finally any entry in the method's `translations` map. The
  /// translations pass is what makes an order saved while the app ran in
  /// Arabic still resolve in English, and vice versa.
  static PaymentMethod? find(String? value) {
    final needle = value?.trim();
    if (needle == null || needle.isEmpty) return null;

    final lower = needle.toLowerCase();

    for (final method in _methods) {
      if (method.code.trim().toLowerCase() == lower) return method;
    }

    for (final method in _methods) {
      if (method.id.isNotEmpty && method.id == needle) return method;
    }

    for (final method in _methods) {
      if (method.rawLabel.trim().toLowerCase() == lower) return method;
    }

    for (final method in _methods) {
      for (final translated in method.translations.values) {
        if (translated.trim().toLowerCase() == lower) return method;
      }
    }

    return null;
  }
}
