import 'package:pos_machine/models/master_data.dart';

class TableListModel {
  final String status;
  final String message;
  final Map<String, String> data;
  final List<MasterDataValue>? dataList;

  TableListModel({
    required this.status,
    required this.message,
    required this.data,
    this.dataList,
  });

  factory TableListModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> mapData = {};
    List<MasterDataValue>? listData;

    if (json['data'] != null) {
      if (json['data'] is List) {
        // New structure: List of objects with id, value, description
        listData = (json['data'] as List)
            .map((item) => MasterDataValue.fromJson(item))
            .toList();
        // Convert to Map for backwards compatibility (value -> description)
        mapData = {for (var item in listData) item.value: item.description};
      } else if (json['data'] is Map) {
        // Legacy structure: Map<String, String>
        mapData = Map<String, String>.from(json['data']);
        // Convert to List for new usage
        int index = 0;
        listData = mapData.entries.map((entry) {
          return MasterDataValue(
            id: index++,
            value: entry.key,
            description: entry.value,
          );
        }).toList();
      }
    }

    return TableListModel(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: mapData,
      dataList: listData,
    );
  }

  bool get isSuccess => status.toLowerCase() == 'success';

  /// Get table ID by value
  int? getIdByValue(String value) {
    if (dataList == null) return null;
    try {
      return dataList!.firstWhere((item) => item.value == value).id;
    } catch (e) {
      return null;
    }
  }

  /// Get table value (display name) by ID
  String? getValueById(int id) {
    if (dataList == null) return null;
    try {
      return dataList!.firstWhere((item) => item.id == id).value;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data,
    };
  }
}

class TableData {
  final String key;
  final String value;

  TableData({
    required this.key,
    required this.value,
  });

  factory TableData.fromMapEntry(MapEntry<String, String> entry) {
    return TableData(
      key: entry.key,
      value: entry.value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
    };
  }
}
