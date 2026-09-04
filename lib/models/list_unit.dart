class UnitsResponse {
  final String status;
  final String message;

  /// The **machine** unit values (`PCS`, `KG`), keyed by unit id.
  ///
  /// This map must stay in the tenant's base language for every locale. Unit
  /// resolution on the product, stock and purchase forms matches a product's
  /// stored unit against both the keys *and* the values here, so a translated
  /// value silently breaks the unit dropdown. See backend action item 1 in
  /// `TRANSLATION_AGREED_SCOPE.md`.
  final Map<String, String> unitList;

  /// Locale-resolved display text keyed by the same unit id, from the additive
  /// `labels` map. Empty until the backend ships it — [displayFor] falls back
  /// to [unitList] so the UI reads the same either way.
  final Map<String, String> labels;

  UnitsResponse({
    required this.status,
    required this.message,
    required this.unitList,
    this.labels = const {},
  });

  /// Display text for a unit id: the localized label when the backend has one,
  /// otherwise the machine value.
  String? displayFor(String unitId) {
    final label = labels[unitId]?.trim();
    if (label != null && label.isNotEmpty) return label;
    return unitList[unitId];
  }

  /// `{id: displayText}` for every known unit, for dropdowns that want one map.
  Map<String, String> get displayList => {
        for (final entry in unitList.entries)
          entry.key: displayFor(entry.key) ?? entry.value,
      };

  factory UnitsResponse.fromJson(Map<String, dynamic> json) {
    return UnitsResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      unitList: _stringMap(json['data']),
      labels: _stringMap(json['labels']),
    );
  }

  /// Tolerates a missing key, a null, and the `[]` PHP emits for an empty
  /// associative array — any of which would otherwise throw on a hard cast.
  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      result[key.toString()] = text;
    });
    return result;
  }
}

// import 'dart:convert';

// GetListUnitModel getListUnitModelFromJson(String str) =>
//     GetListUnitModel.fromJson(json.decode(str));

// String getListUnitModelToJson(GetListUnitModel data) =>
//     json.encode(data.toJson());

// class GetListUnitModel {
//   final String? status;
//   final String? message;
//   final UnitList? data;

//   GetListUnitModel({
//     this.status,
//     this.message,
//     this.data,
//   });

//   factory GetListUnitModel.fromJson(Map<String, dynamic> json) =>
//       GetListUnitModel(
//         status: json["status"],
//         message: json["message"],
//         data: json["data"] == null ? null : UnitList.fromJson(json["data"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "status": status,
//         "message": message,
//         "data": data?.toJson(),
//       };
// }

// class UnitList {
//   final String? kg;
//   final String? pc;
//   final String? pk;
//   final String? dz;
//   final String? lt;

//   UnitList({
//     this.kg,
//     this.pc,
//     this.pk,
//     this.dz,
//     this.lt,
//   });

//   factory UnitList.fromJson(Map<String, dynamic> json) => UnitList(
//         kg: json["KG"],
//         pc: json["PC"],
//         pk: json["PK"],
//         dz: json["DZ"],
//         lt: json["LT"],
//       );

//   Map<String, dynamic> toJson() => {
//         "KG": kg,
//         "PC": pc,
//         "PK": pk,
//         "DZ": dz,
//         "LT": lt,
//       };
// }
