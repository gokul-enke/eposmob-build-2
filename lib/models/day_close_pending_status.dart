class DayClosePendingStatus {
  final bool pendingDayClose;
  final bool canOpenShift;
  final bool requiresConfirmation;
  final String businessDate;
  final String message;
  final String confirmationMessage;
  final int? openingTransactionId;
  final int? closingTransactionId;
  final String? openingDate;
  final String? openingTime;
  final String? closingDate;
  final String? closingTime;

  DayClosePendingStatus({
    required this.pendingDayClose,
    required this.canOpenShift,
    required this.requiresConfirmation,
    required this.businessDate,
    required this.message,
    required this.confirmationMessage,
    this.openingTransactionId,
    this.closingTransactionId,
    this.openingDate,
    this.openingTime,
    this.closingDate,
    this.closingTime,
  });

  factory DayClosePendingStatus.fromJson(Map<String, dynamic> json) {
    return DayClosePendingStatus(
      pendingDayClose: json['pending_day_close'] ?? false,
      canOpenShift: json['can_open_shift'] ?? true,
      requiresConfirmation: json['requires_confirmation'] ?? false,
      businessDate: json['business_date'] ?? '',
      message: json['message'] ?? '',
      confirmationMessage: json['confirmation_message'] ?? '',
      openingTransactionId: json['opening_transaction_id'],
      closingTransactionId: json['closing_transaction_id'],
      openingDate: json['opening_date'],
      openingTime: json['opening_time'],
      closingDate: json['closing_date'],
      closingTime: json['closing_time'],
    );
  }
}
