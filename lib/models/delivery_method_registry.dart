import 'package:pos_machine/models/delivery_method.dart';

/// Resolves the delivery-method *strings* held all over the billing flow back
/// to a canonical [DeliveryKind].
///
/// ## Why this exists
///
/// `BillingProvider.deliveryMethod`, `Order.deliveryMethod` and a dozen widget
/// fields all store the delivery method as a plain display-name `String`, and
/// ~64 sites branch on it with `== "Car Delivery"`. Those comparisons break the
/// moment the API returns a localized name, and they break *silently*: car
/// number validation just stops firing.
///
/// Rewriting every one of those fields to carry an id would be a very large,
/// risky change touching order persistence and the print layer. Instead this
/// registry keeps a snapshot of the loaded [DeliveryMethod] list and maps any
/// stored string — an id, a code, an English name, or an Arabic name — back to
/// the method it came from, and from there to a stable [DeliveryKind].
///
/// [DeliveryMethodsProvider] calls [update] whenever methods load (from API or
/// cache), so the snapshot follows the active store.
class DeliveryMethodRegistry {
  DeliveryMethodRegistry._();

  static List<DeliveryMethod> _methods = const [];

  /// Snapshot of the currently loaded methods. Empty before store bootstrap.
  static List<DeliveryMethod> get methods => _methods;

  /// Replaces the snapshot. Called by [DeliveryMethodsProvider].
  static void update(List<DeliveryMethod> methods) {
    _methods = List<DeliveryMethod>.unmodifiable(methods);
  }

  static void clear() {
    _methods = const [];
  }

  /// Finds the method a stored string refers to.
  ///
  /// Matches, in order: exact id, `code`, the localized `name`, and finally any
  /// entry in the method's `translations` map. The translations pass is what
  /// makes an order saved in English still resolve while the app runs in
  /// Arabic, and vice versa.
  static DeliveryMethod? find(String? value) {
    final needle = value?.trim();
    if (needle == null || needle.isEmpty) return null;

    for (final method in _methods) {
      if (method.id == needle) return method;
    }

    final lower = needle.toLowerCase();

    for (final method in _methods) {
      final code = method.code?.trim().toLowerCase();
      if (code != null && code.isNotEmpty && code == lower) return method;
    }

    for (final method in _methods) {
      if (method.name.trim().toLowerCase() == lower) return method;
    }

    for (final method in _methods) {
      for (final translated in method.translations.values) {
        if (translated.trim().toLowerCase() == lower) return method;
      }
    }

    return null;
  }

  /// Canonical kind for a stored delivery-method string.
  ///
  /// Falls back to token matching on the string itself when the registry has
  /// not loaded yet (cold start, offline first run) or when the string refers
  /// to a method that no longer exists — so behaviour degrades to exactly what
  /// the old English-name comparisons did rather than to nothing.
  static DeliveryKind kindOf(String? value) {
    final method = find(value);
    if (method != null) return method.kind;

    final needle = value?.trim();
    if (needle == null || needle.isEmpty) return DeliveryKind.other;

    return DeliveryMethod(id: '', name: needle).kind;
  }

  /// Whether the given stored delivery-method string requires a car number.
  static bool requiresCarNumber(String? value) {
    final method = find(value);
    if (method != null) return method.requiresCarNumber;
    return kindOf(value) == DeliveryKind.carDelivery;
  }

  /// Whether the given stored delivery-method string requires an address.
  static bool requiresAddress(String? value) {
    final method = find(value);
    if (method != null) return method.requiresAddress;
    return kindOf(value) == DeliveryKind.doorDelivery;
  }

  /// Display label for a stored delivery-method string, localized when the
  /// method is known. Returns the original string unchanged otherwise, so an
  /// unrecognised tenant method still renders something sensible.
  static String labelOf(String? value) {
    final method = find(value);
    if (method != null) return method.label;
    return value?.trim() ?? '';
  }

  /// The method that should be selected by default (store takeaway), or the
  /// first available one.
  static DeliveryMethod? get defaultMethod {
    for (final method in _methods) {
      if (method.kind == DeliveryKind.storeTakeaway) return method;
    }
    return _methods.isEmpty ? null : _methods.first;
  }
}
