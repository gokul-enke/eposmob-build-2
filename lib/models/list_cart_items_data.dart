class ServiceType {
  final int serviceTypeId;
  final String serviceName;
  final String serviceCode;
  final Map<String, List<ServiceArea>> serviceAreaTypes;

  ServiceType({
    required this.serviceTypeId,
    required this.serviceName,
    required this.serviceCode,
    required this.serviceAreaTypes,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> serviceAreaTypesJson = json['service_area_types'];
    Map<String, List<ServiceArea>> serviceAreaTypesMap = {};
    serviceAreaTypesJson.forEach((key, value) {
      List<ServiceArea> serviceAreas = List<ServiceArea>.from(
          value.map((area) => ServiceArea.fromJson(area)));
      serviceAreaTypesMap[key] = serviceAreas;
    });

    return ServiceType(
      serviceTypeId: json['service_type_id'],
      serviceName: json['service_name'],
      serviceCode: json['service_code'],
      serviceAreaTypes: serviceAreaTypesMap,
    );
  }
}

class ServiceArea {
  final int serviceAreaId;
  final String serviceAreaName;
  final String unit;
  final String serviceTypeId;
  final String unitPrice;
  final String currency;

  ServiceArea({
    required this.serviceAreaId,
    required this.serviceAreaName,
    required this.unit,
    required this.serviceTypeId,
    required this.unitPrice,
    required this.currency,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    return ServiceArea(
      serviceAreaId: json['service_area_id'],
      serviceAreaName: json['service_area_name'],
      unit: json['unit'],
      serviceTypeId: json['service_type_id'],
      unitPrice: json['unit_price'],
      currency: json['currency'],
    );
  }
}

class ServiceData {
  final String status;
  final Map<String, dynamic> data;

  ServiceData({
    required this.status,
    required this.data,
  });

  factory ServiceData.fromJson(Map<String, dynamic> json) {
    return ServiceData(
      status: json['status'],
      data: json['data'],
    );
  }
}

class ServiceAreaType {
  final Map<String, String> types;

  ServiceAreaType({
    required this.types,
  });

  factory ServiceAreaType.fromJson(Map<String, dynamic> json) {
    return ServiceAreaType(
      types: Map<String, String>.from(
          json.map((key, value) => MapEntry(key, value))),
    );
  }
}






// // To parse this JSON data, do
// //
// //     final listCartItemsModel = listCartItemsModelFromJson(jsonString);

// import 'dart:convert';

// ListCartItemsModel listCartItemsModelFromJson(String str) =>
//     ListCartItemsModel.fromJson(json.decode(str));

// String listCartItemsModelToJson(ListCartItemsModel data) =>
//     json.encode(data.toJson());

// class ListCartItemsModel {
//   final String? status;
//   final ListCartItemsModelData? data;

//   ListCartItemsModel({
//     this.status,
//     this.data,
//   });

//   factory ListCartItemsModel.fromJson(Map<String, dynamic> json) =>
//       ListCartItemsModel(
//         status: json["status"],
//         data: json["data"] == null
//             ? null
//             : ListCartItemsModelData.fromJson(json["data"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "status": status,
//         "data": data?.toJson(),
//       };
// }

// class ListCartItemsModelData {
//   // final The0? the0;
// //  final List<ServiceType>? serviceTypes;
//   final List<ServiceArea>? serviceArea;
//   // final ServiceAreaType? serviceAreaType;
// //  final List<ServiceFrquency>? serviceFrquency;

//   ListCartItemsModelData({
//     //  this.the0,
//     // this.serviceTypes,
//     this.serviceArea,
//     // this.serviceAreaType,
//     //  this.serviceFrquency,
//   });

//   factory ListCartItemsModelData.fromJson(Map<String, dynamic> json) =>
//       ListCartItemsModelData(
//         //  the0: json["0"] == null ? null : The0.fromJson(json["0"]),
//         // serviceTypes: json["service_types"] == null
//         //     ? []
//         //     : List<ServiceType>.from(
//         //         json["service_types"]!.map((x) => ServiceType.fromJson(x))),
//         serviceArea: json["service_area"] == null
//             ? []
//             : List<ServiceArea>.from(
//                 json["service_area"]!.map((x) => ServiceArea.fromJson(x))),
//         // serviceAreaType: json["service_area_type"] == null
//         //     ? null
//         //     : ServiceAreaType.fromJson(json["service_area_type"]),
//         // serviceFrquency: json["service_frquency"] == null
//         //     ? []
//         //     : List<ServiceFrquency>.from(json["service_frquency"]!
//         //         .map((x) => ServiceFrquency.fromJson(x))),
//       );

//   Map<String, dynamic> toJson() => {
//         // "0": the0?.toJson(),
//         // "service_types": serviceTypes == null
//         //     ? []
//         //     : List<dynamic>.from(serviceTypes!.map((x) => x.toJson())),
//         // "service_area": serviceArea == null
//         //     ? []
//         //     : List<dynamic>.from(serviceArea!.map((x) => x.toJson())),
//         //   "service_area_type": serviceAreaType?.toJson(),
//         // "service_frquency": serviceFrquency == null
//         //     ? []
//         //     : List<dynamic>.from(serviceFrquency!.map((x) => x.toJson())),
//       };
// }

// class ServiceArea {
//   final int? serviceAreaId;
//   final String? serviceAreaName;
//   final String? unit;
//   final String? serviceAreaType;
//   final String? serviceTypeId;

//   ServiceArea({
//     this.serviceAreaId,
//     this.serviceAreaName,
//     this.unit,
//     this.serviceAreaType,
//     this.serviceTypeId,
//   });

//   factory ServiceArea.fromJson(Map<String, dynamic> json) => ServiceArea(
//         serviceAreaId: json["service_area_id"],
//         serviceAreaName: json["service_area_name"],
//         unit: json["unit"],
//         serviceAreaType: json["service_area_type"],
//         serviceTypeId: json["service_type_id"],
//       );

//   Map<String, dynamic> toJson() => {
//         "service_area_id": serviceAreaId,
//         "service_area_name": serviceAreaName,
//         "unit": unit,
//         "service_area_type": serviceAreaType,
//         "service_type_id": serviceTypeId,
//       };
// }

// class ServiceAreaType {
//   final String? floor;
//   final String? wall;
//   final String? vehicle;
//   final String? backyard;
//   final String? other;

//   ServiceAreaType({
//     this.floor,
//     this.wall,
//     this.vehicle,
//     this.backyard,
//     this.other,
//   });

//   factory ServiceAreaType.fromJson(Map<String, dynamic> json) =>
//       ServiceAreaType(
//         floor: json["floor"],
//         wall: json["wall"],
//         vehicle: json["vehicle"],
//         backyard: json["backyard"],
//         other: json["other"],
//       );

//   Map<String, dynamic> toJson() => {
//         "floor": floor,
//         "wall": wall,
//         "vehicle": vehicle,
//         "backyard": backyard,
//         "other": other,
//       };
// }

// class ServiceFrquency {
//   final int? serviceFrequencyId;
//   final int? frequency;
//   final String? type;
//   final String? day;

//   ServiceFrquency({
//     this.serviceFrequencyId,
//     this.frequency,
//     this.type,
//     this.day,
//   });

//   factory ServiceFrquency.fromJson(Map<String, dynamic> json) =>
//       ServiceFrquency(
//         serviceFrequencyId: json["service_frequency_id"],
//         frequency: json["frequency"],
//         type: json["type"],
//         day: json["day"],
//       );

//   Map<String, dynamic> toJson() => {
//         "service_frequency_id": serviceFrequencyId,
//         "frequency": frequency,
//         "type": type,
//         "day": day,
//       };
// }

// class ServiceType {
//   final int? serviceTypeId;
//   final String? serviceName;
//   final String? serviceCode;
//   final ServiceAreaTypes? serviceAreaTypes;

//   ServiceType({
//     this.serviceTypeId,
//     this.serviceName,
//     this.serviceCode,
//     this.serviceAreaTypes,
//   });

//   factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
//         serviceTypeId: json["service_type_id"],
//         serviceName: json["service_name"],
//         serviceCode: json["service_code"],
//         serviceAreaTypes: json["service_area_types"] == null
//             ? null
//             : ServiceAreaTypes.fromJson(json["service_area_types"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "service_type_id": serviceTypeId,
//         "service_name": serviceName,
//         "service_code": serviceCode,
//         "service_area_types": serviceAreaTypes?.toJson(),
//       };
// }

// class ServiceAreaTypes {
//   final List<int>? floor;
//   final List<int>? vehicle;

//   ServiceAreaTypes({
//     this.floor,
//     this.vehicle,
//   });

//   factory ServiceAreaTypes.fromJson(Map<String, dynamic> json) =>
//       ServiceAreaTypes(
//         floor: json["floor"] == null
//             ? []
//             : List<int>.from(json["floor"]!.map((x) => x)),
//         vehicle: json["vehicle"] == null
//             ? []
//             : List<int>.from(json["vehicle"]!.map((x) => x)),
//       );

//   Map<String, dynamic> toJson() => {
//         "floor": floor == null ? [] : List<dynamic>.from(floor!.map((x) => x)),
//         "vehicle":
//             vehicle == null ? [] : List<dynamic>.from(vehicle!.map((x) => x)),
//       };
// }

// class The0 {
//   final int? cartId;
//   final int? customerId;
//   final int? unitPrice;
//   final int? totalPrice;
//   final int? tax;
//   final int? taxRate;
//   final int? discountValue;
//   final String? discountType;
//   final int? totalServiceCount;
//   final DateTime? startDate;
//   final DateTime? endDate;
//   final int? netTotal;
//   final String? currency;

//   The0({
//     this.cartId,
//     this.customerId,
//     this.unitPrice,
//     this.totalPrice,
//     this.tax,
//     this.taxRate,
//     this.discountValue,
//     this.discountType,
//     this.totalServiceCount,
//     this.startDate,
//     this.endDate,
//     this.netTotal,
//     this.currency,
//   });

//   factory The0.fromJson(Map<String, dynamic> json) => The0(
//         cartId: json["cart_id"],
//         customerId: json["customer_id"],
//         unitPrice: json["unit_price"],
//         totalPrice: json["total_price"],
//         tax: json["tax"],
//         taxRate: json["tax_rate"],
//         discountValue: json["discount_value"],
//         discountType: json["discount_type"],
//         totalServiceCount: json["total_service_count"],
//         startDate: json["start_date"] == null
//             ? null
//             : DateTime.parse(json["start_date"]),
//         endDate:
//             json["end_date"] == null ? null : DateTime.parse(json["end_date"]),
//         netTotal: json["net_total"],
//         currency: json["currency"],
//       );

//   Map<String, dynamic> toJson() => {
//         "cart_id": cartId,
//         "customer_id": customerId,
//         "unit_price": unitPrice,
//         "total_price": totalPrice,
//         "tax": tax,
//         "tax_rate": taxRate,
//         "discount_value": discountValue,
//         "discount_type": discountType,
//         "total_service_count": totalServiceCount,
//         "start_date":
//             "${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
//         "end_date":
//             "${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
//         "net_total": netTotal,
//         "currency": currency,
//       };
// }
// import 'dart:convert';

// ListCartItems listCartItemsFromJson(String str) =>
//     ListCartItems.fromJson(json.decode(str));

// String listCartItemsToJson(ListCartItems listCartItemsData) =>
//     json.encode(listCartItemsData.toJson());

// class ListCartItems {
//   final String status;
//   final ListCartItemsData? listCartItemsData;

//   ListCartItems({
//     required this.status,
//     this.listCartItemsData,
//   });

//   factory ListCartItems.fromJson(Map<String, dynamic> json) => ListCartItems(
//         status: json["status"],
//         listCartItemsData: json["data"] == null
//             ? null
//             : ListCartItemsData.fromJson(json["data"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "status": status,
//         "data": listCartItemsData!.toJson(),
//       };
// }

// class ListCartItemsData {
//   //final CartItems cartItems;
//   final List<ServiceType> serviceTypes;
//   final List<ServiceArea> serviceArea;
//   final ServiceAreaType serviceAreaType;
//   // final List<ServiceFrquency> serviceFrquency;

//   ListCartItemsData({
//     //required this.cartItems,
//     required this.serviceTypes,
//     required this.serviceArea,
//     required this.serviceAreaType,
//     // required this.serviceFrquency,
//   });

//   factory ListCartItemsData.fromJson(Map<String, dynamic> json) =>
//       ListCartItemsData(
//         serviceTypes: (json["service_types"] as List<dynamic>?)
//                 ?.map((x) => ServiceType.fromJson(x))
//                 .toList() ??
//             [],
//         serviceArea: List<ServiceArea>.from(
//             json["service_area"].map((x) => ServiceArea.fromJson(x))),
//         serviceAreaType: ServiceAreaType.fromJson(json["service_area_type"]),
//         //  serviceFrquency: List<ServiceFrquency>.from(
//         //      json["service_frquency"].map((x) => ServiceFrquency.fromJson(x))),
//         //cartItems: CartItems.fromJson(json["0"]),
//       );

//   Map<String, dynamic> toJson() => {
//         //"0": cartItems.toJson(),
//         "service_types":
//             List<dynamic>.from(serviceTypes.map((x) => x.toJson())),
//         "service_area": List<dynamic>.from(serviceArea.map((x) => x.toJson())),
//         "service_area_type": serviceAreaType.toJson(),
//         //   "service_frquency":
//         //      List<dynamic>.from(serviceFrquency.map((x) => x.toJson())),
//       };
// }

// class ServiceArea {
//   final int serviceAreaId;
//   final String serviceAreaName;
//   final String unit;
//   final String serviceAreaType;
//   final String serviceTypeId;

//   ServiceArea({
//     required this.serviceAreaId,
//     required this.serviceAreaName,
//     required this.unit,
//     required this.serviceAreaType,
//     required this.serviceTypeId,
//   });

//   factory ServiceArea.fromJson(Map<String, dynamic> json) => ServiceArea(
//         serviceAreaId: json["service_area_id"],
//         serviceAreaName: json["service_area_name"],
//         unit: json["unit"],
//         serviceAreaType: json["service_area_type"],
//         serviceTypeId: json["service_type_id"],
//       );

//   Map<String, dynamic> toJson() => {
//         "service_area_id": serviceAreaId,
//         "service_area_name": serviceAreaName,
//         "unit": unit,
//         "service_area_type": serviceAreaType,
//         "service_type_id": serviceTypeId,
//       };
// }

// class ServiceAreaType {
//   final String floor;
//   final String wall;
//   final String vehicle;
//   final String backyard;
//   final String other;

//   ServiceAreaType({
//     required this.floor,
//     required this.wall,
//     required this.vehicle,
//     required this.backyard,
//     required this.other,
//   });

//   factory ServiceAreaType.fromJson(Map<String, dynamic> json) =>
//       ServiceAreaType(
//         floor: json["floor"],
//         wall: json["wall"],
//         vehicle: json["vehicle"],
//         backyard: json["backyard"],
//         other: json["other"],
//       );

//   Map<String, dynamic> toJson() => {
//         "floor": floor,
//         "wall": wall,
//         "vehicle": vehicle,
//         "backyard": backyard,
//         "other": other,
//       };
// }

// class ServiceFrquency {
//   final int serviceFrequencyId;
//   final int frequency;
//   final String type;
//   final String day;

//   ServiceFrquency({
//     required this.serviceFrequencyId,
//     required this.frequency,
//     required this.type,
//     required this.day,
//   });

//   factory ServiceFrquency.fromJson(Map<String, dynamic> json) =>
//       ServiceFrquency(
//         serviceFrequencyId: json["service_frequency_id"],
//         frequency: json["frequency"],
//         type: json["type"],
//         day: json["day"],
//       );

//   Map<String, dynamic> toJson() => {
//         "service_frequency_id": serviceFrequencyId,
//         "frequency": frequency,
//         "type": type,
//         "day": day,
//       };
// }

// class ServiceType {
//   final int serviceTypeId;
//   final String serviceName;
//   final String serviceCode;
//   final ServiceAreaTypes? serviceAreaTypes;

//   ServiceType({
//     required this.serviceTypeId,
//     required this.serviceName,
//     required this.serviceCode,
//     this.serviceAreaTypes,
//   });

//   factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
//         serviceTypeId: json["service_type_id"],
//         serviceName: json["service_name"],
//         serviceCode: json["service_code"],
//         serviceAreaTypes: ServiceAreaTypes.fromJson(json["service_area_types"]),
//       );

//   Map<String, dynamic> toJson() => {
//         "service_type_id": serviceTypeId,
//         "service_name": serviceName,
//         "service_code": serviceCode,
//         "service_area_types": serviceAreaTypes!.toJson(),
//       };

//   List<String> getServiceAreaTypeKeys() {
//     return serviceAreaTypes?.toJson().keys.toList() ?? [];
//   }
// }

// class ServiceAreaTypes {
//   final List<int>? floor;
//   final List<int>? vehicle;

//   ServiceAreaTypes({
//     this.floor,
//     this.vehicle,
//   });

//   factory ServiceAreaTypes.fromJson(Map<String, dynamic> json) =>
//       ServiceAreaTypes(
//         floor: (json['floor'] as List<dynamic>?)?.cast<int>(),
//         vehicle: (json['vehicle'] as List<dynamic>?)?.cast<int>(),
//       );

//   Map<String, dynamic> toJson() => {
//         "floor": List<dynamic>.from(floor!.map((x) => x)),
//         "vehicle": List<dynamic>.from(vehicle!.map((x) => x)),
//       };
// }

// class CartItems {
//   final int cartId;
//   final int customerId;
//   final int unitPrice;
//   final int totalPrice;
//   final int tax;
//   final int taxRate;
//   final int discountValue;
//   final String discountType;
//   final int totalServiceCount;
//   final DateTime startDate;
//   final DateTime endDate;
//   final int netTotal;
//   final String currency;

//   CartItems({
//     required this.cartId,
//     required this.customerId,
//     required this.unitPrice,
//     required this.totalPrice,
//     required this.tax,
//     required this.taxRate,
//     required this.discountValue,
//     required this.discountType,
//     required this.totalServiceCount,
//     required this.startDate,
//     required this.endDate,
//     required this.netTotal,
//     required this.currency,
//   });

//   factory CartItems.fromJson(Map<String, dynamic> json) => CartItems(
//         cartId: json["cart_id"],
//         customerId: json["customer_id"],
//         unitPrice: json["unit_price"],
//         totalPrice: json["total_price"],
//         tax: json["tax"],
//         taxRate: json["tax_rate"],
//         discountValue: json["discount_value"],
//         discountType: json["discount_type"],
//         totalServiceCount: json["total_service_count"],
//         startDate: DateTime.parse(json["start_date"]),
//         endDate: DateTime.parse(json["end_date"]),
//         netTotal: json["net_total"],
//         currency: json["currency"],
//       );

//   Map<String, dynamic> toJson() => {
//         "cart_id": cartId,
//         "customer_id": customerId,
//         "unit_price": unitPrice,
//         "total_price": totalPrice,
//         "tax": tax,
//         "tax_rate": taxRate,
//         "discount_value": discountValue,
//         "discount_type": discountType,
//         "total_service_count": totalServiceCount,
//         "start_date":
//             "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
//         "end_date":
//             "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}",
//         "net_total": netTotal,
//         "currency": currency,
//       };
// }
