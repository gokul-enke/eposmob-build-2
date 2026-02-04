/// Represents a single master data value item from the API
class MasterDataValue {
  final int id;
  final String value;
  final String description;

  MasterDataValue({
    required this.id,
    required this.value,
    required this.description,
  });

  factory MasterDataValue.fromJson(Map<String, dynamic> json) {
    return MasterDataValue(
      id: json['id'] ?? 0,
      value: json['value'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'description': description,
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
