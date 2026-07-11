class OpenDraftCashSummary {
  final String? openingCashInHand;
  final List<dynamic>? openingCashBreakdown;

  OpenDraftCashSummary({
    this.openingCashInHand,
    this.openingCashBreakdown,
  });

  factory OpenDraftCashSummary.fromJson(Map<String, dynamic> json) {
    return OpenDraftCashSummary(
      openingCashInHand: json['opening_cash_in_hand']?.toString(),
      openingCashBreakdown: json['opening_cash_breakdown'],
    );
  }
}

class OpenDraftModel {
  final int? id;
  final String? shiftName;
  final OpenDraftCashSummary? cashSummary;
  final String? openingTime;

  OpenDraftModel({
    this.id,
    this.shiftName,
    this.cashSummary,
    this.openingTime,
  });

  factory OpenDraftModel.fromJson(Map<String, dynamic> json) {
    return OpenDraftModel(
      id: json['id'],
      shiftName: json['shift_name'],
      cashSummary: json['cash_summary'] != null
          ? OpenDraftCashSummary.fromJson(json['cash_summary'])
          : null,
      openingTime: json['opening_time'],
    );
  }
}

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
  final OpenDraftModel? openDraft;

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
    this.openDraft,
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
      openDraft: json['open_draft'] != null
          ? OpenDraftModel.fromJson(json['open_draft'])
          : null,
    );
  }
}
