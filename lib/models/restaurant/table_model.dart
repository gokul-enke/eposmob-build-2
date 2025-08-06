class TableModel {
  final String id;
  final String name;
  final int capacity;
  final TableStatus status;
  final String? assignedServerId;
  final String? currentOrderId;
  final DateTime? reservationTime;
  final int section; // 1 for dine-in, 2 for takeaway, 3 for delivery

  TableModel({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    this.assignedServerId,
    this.currentOrderId,
    this.reservationTime,
    this.section = 1,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      name: json['name'] as String,
      capacity: json['capacity'] as int,
      status: TableStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TableStatus.available,
      ),
      assignedServerId: json['assignedServerId'] as String?,
      currentOrderId: json['currentOrderId'] as String?,
      reservationTime: json['reservationTime'] != null
          ? DateTime.parse(json['reservationTime'])
          : null,
      section: json['section'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'status': status.toString().split('.').last,
      'assignedServerId': assignedServerId,
      'currentOrderId': currentOrderId,
      'reservationTime': reservationTime?.toIso8601String(),
      'section': section,
    };
  }

  TableModel copyWith({
    String? id,
    String? name,
    int? capacity,
    TableStatus? status,
    String? assignedServerId,
    String? currentOrderId,
    DateTime? reservationTime,
    int? section,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      assignedServerId: assignedServerId ?? this.assignedServerId,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      reservationTime: reservationTime ?? this.reservationTime,
      section: section ?? this.section,
    );
  }
}

enum TableStatus {
  available,
  occupied,
  reserved,
  cleaning,
  maintenance,
} 