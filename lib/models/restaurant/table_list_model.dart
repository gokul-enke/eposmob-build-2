class TableListModel {
  final String status;
  final String message;
  final Map<String, String> data;

  TableListModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory TableListModel.fromJson(Map<String, dynamic> json) {
    return TableListModel(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: Map<String, String>.from(json['data'] ?? {}),
    );
  }

  bool get isSuccess => status.toLowerCase() == 'success';

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