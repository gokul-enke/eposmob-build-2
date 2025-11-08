class MasterData {
  final String status;
  final String message;
  final Map<String, String> data;

  MasterData({
    required this.status,
    required this.message,
    required this.data,
  });

  factory MasterData.fromJson(Map<String, dynamic> json) {
    return MasterData(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: Map<String, String>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'MasterData(status: $status, message: $message, data: $data)';
  }
}
