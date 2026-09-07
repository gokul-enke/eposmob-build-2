import 'package:pos_machine/models/api_translations.dart';

/// Represents a single master data value item from the API
class MasterDataValue {
  final int id;

  /// Stable machine value (`CASH`, `RACK_A`, `TABLE_ONE`). Never translated —
  /// it is what gets persisted against orders, stock rows and products, so a
  /// translated `value` would turn every stored reference into a dangling one.
  /// Branch on this, never on [description] or [label].
  final String value;

  /// Server-resolved human text for the locale that was requested at fetch
  /// time. May be localized — never branch on it.
  final String description;

  /// Stable machine code. The backend sends this alongside [value]; they are
  /// currently identical, but `code` is the field the contract guarantees.
  final String? code;

  /// Per-language display text keyed by base language code (`en`, `ar`, `ml`).
  /// Lets the UI switch language from cache with no refetch.
  final Map<String, String> translations;

  MasterDataValue({
    required this.id,
    required this.value,
    required this.description,
    this.code,
    this.translations = const {},
  });

  /// Display text for the active app locale, resolved at render time from
  /// [translations] with a fallback to the server-resolved [description] and
  /// finally the machine [value], so a label is never blank.
  String get label => ApiTranslations.resolve(
        translations,
        fallback: description.isNotEmpty ? description : value,
      );

  /// Stable identity, preferring the guaranteed `code` over `value`.
  String get stableCode {
    final trimmed = code?.trim();
    return (trimmed == null || trimmed.isEmpty) ? value : trimmed;
  }

  factory MasterDataValue.fromJson(Map<String, dynamic> json) {
    return MasterDataValue(
      id: _parseId(json['id']),
      value: json['value']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      code: _nonEmpty(json['code']?.toString()),
      // Master data translates the `description` column; the other names are
      // accepted in priority order so a backend that labels the row `label` or
      // `name` instead still parses.
      translations: ApiTranslations.parse(
        json['translations'],
        fields: const ['description', 'label', 'name', 'value'],
      ),
    );
  }

  /// The API has returned `id` as both a number and a numeric string across
  /// endpoints, and a hard cast crashes the whole list rather than one row.
  static int _parseId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'description': description,
      if (code != null) 'code': code,
      if (translations.isNotEmpty) 'translations': translations,
    };
  }

  @override
  String toString() {
    return 'MasterDataValue(id: $id, value: $value, description: $description)';
  }
}

/// Represents the API response for master data values
class MasterData {
  final String status;
  final String message;
  final List<MasterDataValue> data;

  MasterData({
    required this.status,
    required this.message,
    required this.data,
  });

  factory MasterData.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return MasterData(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: dataList.map((item) => MasterDataValue.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }

  /// Helper to get a value by ID
  MasterDataValue? getById(int id) {
    try {
      return data.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Helper to get a value by its value field
  MasterDataValue? getByValue(String value) {
    try {
      return data.firstWhere((item) => item.value == value);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'MasterData(status: $status, message: $message, data: $data)';
  }
}
