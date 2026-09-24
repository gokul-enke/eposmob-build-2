import 'package:pos_machine/models/master_data.dart';

class ExternalLogistic {
  final int id;
  final String name;
  final String? trackingUrl;
  final List<String> shippingServices;
  final List<String> transportModes;
  final List<ExternalLogisticWarehouse> warehouses;

  const ExternalLogistic({
    required this.id,
    required this.name,
    this.trackingUrl,
    this.shippingServices = const [],
    this.transportModes = const [],
    this.warehouses = const [],
  });

  factory ExternalLogistic.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic value) => value is List
        ? value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList()
        : const [];
    List<ExternalLogisticWarehouse> warehouseList(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map((item) => ExternalLogisticWarehouse.fromJson(
                Map<String, dynamic>.from(item)))
            .toList()
        : const [];

    return ExternalLogistic(
      id: _asInt(json['id']),
      name: json['name']?.toString().trim() ?? '',
      trackingUrl: _asString(json['tracking_url']),
      shippingServices: strings(json['shipping_services']),
      transportModes: strings(json['transport_modes']),
      warehouses: warehouseList(json['warehouses']),
    );
  }
}

class ExternalLogisticWarehouse {
  final int id;
  final int? externalLogisticId;
  final String name;
  final String? address;
  final String? city;

  const ExternalLogisticWarehouse({
    required this.id,
    required this.name,
    this.externalLogisticId,
    this.address,
    this.city,
  });

  factory ExternalLogisticWarehouse.fromJson(Map<String, dynamic> json) =>
      ExternalLogisticWarehouse(
        id: _asInt(json['id']),
        name: json['name']?.toString().trim() ?? '',
        externalLogisticId: _asNullableInt(json['external_logistic_id']),
        address: _asString(json['address']),
        city: _asString(json['city']),
      );
}

class PackingStaff {
  final int id;
  final String name;

  const PackingStaff({required this.id, required this.name});

  factory PackingStaff.fromJson(Map<String, dynamic> json) => PackingStaff(
        id: _asInt(json['id']),
        name: json['name']?.toString().trim() ?? '',
      );
}

int _asInt(dynamic value) => _asNullableInt(value) ?? 0;

int? _asNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _asString(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty || result == 'null' ? null : result;
}

/// Master-data option used by the delivery form. The persisted value remains
/// the machine value; [label] is only for display.
typedef FulfillmentMasterDataValue = MasterDataValue;
