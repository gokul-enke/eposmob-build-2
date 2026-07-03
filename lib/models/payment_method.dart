import 'package:pos_machine/models/master_data.dart';

/// How a payment method behaves at checkout.
///
/// * [collected] — cash-like methods where the cashier enters a collected
///   amount (CASH / CARD / UPI / COD and any dynamic backend method).
/// * [credit] — "to customer credit" / DEBIT: a read-only, auto-calculated
///   amount that is allocated to the customer's balance rather than collected.
/// * [terminal] — external terminal / gateway flow (e.g. Pine Labs ONLINE):
///   no manually-entered amount; requires a successful terminal transaction.
enum PaymentBehavior { collected, credit, terminal }

/// A single backend/config-driven payment method.
///
/// Parsing is intentionally lenient: it reads the historical master-data keys
/// (`id` / `value` / `description`) that the current API returns, plus a set of
/// new optional keys (`code` / `label` / `enabled` / `sort_order` / `icon_key`
/// / `behavior` / `requires_reference`) with safe defaults, so existing API
/// responses continue to parse unchanged while the backend can progressively
/// enrich the payload.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.code,
    required this.label,
    this.enabled = true,
    this.sortOrder = 0,
    this.iconKey,
    this.behavior = PaymentBehavior.collected,
    this.requiresReference = false,
  });

  /// Backend id (master-data value id). Empty string when unknown.
  final String id;

  /// Stable machine code (UPPERCASE), e.g. `CASH`, `CARD`, `UPI`, `COD`,
  /// `DEBIT`, `ONLINE`, or any dynamic backend code.
  final String code;

  /// Human-facing label shown in the UI (already localized upstream if needed).
  final String label;

  /// Whether the method is enabled for the active store.
  final bool enabled;

  /// Sort position (ascending). Ties fall back to label.
  final int sortOrder;

  /// Optional icon hint from the backend (e.g. `cash`, `card`, `upi`).
  final String? iconKey;

  /// Behavior class controlling the checkout interaction.
  final PaymentBehavior behavior;

  /// Whether a transaction reference is required (terminal/gateway methods).
  final bool requiresReference;

  /// Known "core" behaviors keyed by code, used to infer [behavior] when the
  /// backend does not send an explicit `behavior` field.
  static PaymentBehavior _inferBehavior(String code) {
    switch (code.toUpperCase()) {
      case 'DEBIT':
      case 'CREDIT':
        return PaymentBehavior.credit;
      case 'ONLINE':
        return PaymentBehavior.terminal;
      default:
        return PaymentBehavior.collected;
    }
  }

  static PaymentBehavior _parseBehavior(dynamic raw, String code) {
    if (raw is String && raw.trim().isNotEmpty) {
      switch (raw.trim().toLowerCase()) {
        case 'collected':
          return PaymentBehavior.collected;
        case 'credit':
          return PaymentBehavior.credit;
        case 'terminal':
          return PaymentBehavior.terminal;
      }
    }
    return _inferBehavior(code);
  }

  static bool _parseBool(dynamic raw, {required bool defaultValue}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no' || v == '') return false;
    }
    return defaultValue;
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    // Historical master-data keys.
    final rawValue = (json['value'] ?? '').toString().trim();
    final rawDescription = (json['description'] ?? '').toString().trim();
    final rawId = json['id']?.toString() ?? '';

    // New optional keys (safe defaults keep old responses parsing).
    final code = (json['code']?.toString().trim().isNotEmpty ?? false)
        ? json['code'].toString().trim()
        : rawValue;
    final label = (json['label']?.toString().trim().isNotEmpty ?? false)
        ? json['label'].toString().trim()
        : (rawDescription.isNotEmpty ? rawDescription : rawValue);

    return PaymentMethod(
      id: rawId,
      code: code.toUpperCase(),
      label: label.isNotEmpty ? label : code,
      enabled: _parseBool(json['enabled'], defaultValue: true),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      iconKey: json['icon_key']?.toString().trim().isNotEmpty ?? false
          ? json['icon_key'].toString().trim()
          : null,
      behavior: _parseBehavior(json['behavior'], code),
      requiresReference: _parseBool(
        json['requires_reference'],
        defaultValue: _inferBehavior(code) == PaymentBehavior.terminal,
      ),
    );
  }

  /// Builds a [PaymentMethod] from the legacy [MasterDataValue] shape so the
  /// existing cache/fetch layer can be reused without a second network format.
  factory PaymentMethod.fromMasterDataValue(MasterDataValue value) {
    final code = value.value.trim().toUpperCase();
    return PaymentMethod(
      id: value.id.toString(),
      code: code,
      label: value.description.trim().isNotEmpty
          ? value.description.trim()
          : value.value,
      behavior: _inferBehavior(code),
      requiresReference: _inferBehavior(code) == PaymentBehavior.terminal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'label': label,
      'enabled': enabled,
      'sort_order': sortOrder,
      'icon_key': iconKey,
      'behavior': behavior.name,
      'requires_reference': requiresReference,
      // Legacy keys retained so downstream MasterDataValue consumers still work.
      'value': code,
      'description': label,
    };
  }

  PaymentMethod copyWith({
    String? id,
    String? code,
    String? label,
    bool? enabled,
    int? sortOrder,
    String? iconKey,
    PaymentBehavior? behavior,
    bool? requiresReference,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      code: code ?? this.code,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      iconKey: iconKey ?? this.iconKey,
      behavior: behavior ?? this.behavior,
      requiresReference: requiresReference ?? this.requiresReference,
    );
  }

  /// Minimal default list so billing is never blocked when both the API and
  /// the local cache are empty. A single CASH method keeps checkout functional.
  static List<PaymentMethod> get minimalDefaults => const [
        PaymentMethod(
          id: '',
          code: 'CASH',
          label: 'Cash',
          sortOrder: 0,
          iconKey: 'cash',
        ),
      ];

  @override
  String toString() =>
      'PaymentMethod(code: $code, label: $label, enabled: $enabled, '
      'sortOrder: $sortOrder, behavior: ${behavior.name})';
}
