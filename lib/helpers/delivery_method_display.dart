import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/delivery_method_registry.dart';

/// Presentation helpers for delivery methods.
///
/// Both the icon and the label used to be derived by comparing the English
/// display name (`name == "Car Delivery"`). That breaks as soon as the API
/// returns a localized name. Everything here resolves through
/// [DeliveryMethodRegistry] / [DeliveryKind] instead, so it is language-proof.
class DeliveryMethodDisplay {
  DeliveryMethodDisplay._();

  /// Bundled translation keys per kind, used when the backend has not supplied
  /// a translation for the active language.
  static const Map<DeliveryKind, String> _kindTranslationKeys = {
    DeliveryKind.storeTakeaway: 'common.store_takeaway',
    DeliveryKind.carDelivery: 'common.car_delivery',
    DeliveryKind.doorDelivery: 'common.door_delivery',
    DeliveryKind.thirdPartyLogistics: 'common.third_party_logistics',
  };

  static const Map<DeliveryKind, IconData> _kindIcons = {
    DeliveryKind.storeTakeaway: Icons.store,
    DeliveryKind.carDelivery: Icons.car_rental,
    DeliveryKind.doorDelivery: Icons.doorbell_outlined,
    DeliveryKind.thirdPartyLogistics: Icons.local_shipping,
  };

  /// Optional backend icon hints (`icon_key`) mapped to Material icons.
  static const Map<String, IconData> _iconKeys = {
    'store': Icons.store,
    'takeaway': Icons.store,
    'car': Icons.car_rental,
    'curbside': Icons.car_rental,
    'home': Icons.doorbell_outlined,
    'door': Icons.doorbell_outlined,
    'delivery': Icons.delivery_dining,
    'truck': Icons.local_shipping,
    'logistics': Icons.local_shipping,
  };

  /// Icon for a delivery method object.
  ///
  /// Prefers the backend `icon_key` so a tenant-defined method can pick its own
  /// icon without an app release, then falls back to the resolved kind.
  static IconData iconForMethod(DeliveryMethod? method) {
    if (method == null) return Icons.local_shipping;
    final key = method.iconKey?.trim().toLowerCase();
    if (key != null && _iconKeys.containsKey(key)) return _iconKeys[key]!;
    return _kindIcons[method.kind] ?? Icons.local_shipping;
  }

  /// Icon for a stored delivery-method string (name, code or id).
  static IconData iconFor(String? value) {
    final method = DeliveryMethodRegistry.find(value);
    if (method != null) return iconForMethod(method);
    return _kindIcons[DeliveryMethodRegistry.kindOf(value)] ??
        Icons.local_shipping;
  }

  /// Display label for a delivery method object.
  ///
  /// Order of preference:
  /// 1. A backend translation for the active language (`translations` map).
  /// 2. The app's own bundled string for a known kind.
  /// 3. The server-resolved `name` as-is.
  ///
  /// Backend translations win because a tenant may have renamed a method
  /// ("Curbside Pickup" instead of "Car Delivery") and their wording should
  /// survive translation.
  static String labelForMethod(DeliveryMethod? method) {
    if (method == null) return '';

    final fromBackend = method.label;
    if (fromBackend.trim().isNotEmpty && method.translations.isNotEmpty) {
      return fromBackend;
    }

    final key = _kindTranslationKeys[method.kind];
    if (key != null) {
      final translated = key.tr;
      if (translated.isNotEmpty && translated != key) return translated;
    }

    return fromBackend;
  }

  /// Display label for an order's delivery method, resolved from its id first.
  ///
  /// The order-details response returns `delivery_method_name` already
  /// resolved to the store's default language and ships no `translations`
  /// alongside it, so `delivery_method_id` is the only stable key — "Dine In"
  /// matches no [DeliveryKind] token and would otherwise stay English forever.
  ///
  /// [name] is still needed as a fallback: when the registry is cold (a deep
  /// link that lands before store bootstrap) or the method has since been
  /// deleted, the id resolves to nothing, and echoing `199` back at the user
  /// is worse than showing untranslated words.
  static String labelForIdOrName(String? id, String? name) {
    final methodId = id?.trim();
    if (methodId != null && methodId.isNotEmpty) {
      final method = DeliveryMethodRegistry.find(methodId);
      if (method != null) return labelForMethod(method);
    }
    return labelFor(name);
  }

  /// Display label for a stored delivery-method string.
  static String labelFor(String? value) {
    final method = DeliveryMethodRegistry.find(value);
    if (method != null) return labelForMethod(method);

    final key = _kindTranslationKeys[DeliveryMethodRegistry.kindOf(value)];
    if (key != null) {
      final translated = key.tr;
      if (translated.isNotEmpty && translated != key) return translated;
    }

    return value?.trim() ?? '';
  }
}
