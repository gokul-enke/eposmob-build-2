import '../../reports/domain/report_date_range.dart';
import '../../reports/domain/report_period.dart';
import 'general_payment_type.dart';
import 'models/general_payment.dart';

/// The web's General Payments filters: Reference Number (partial), Entry
/// type, Category, Debit A/c, Credit A/c and the Date Range. Null means All.
/// Applied in memory to the loaded entries.
class GeneralPaymentFilter {
  const GeneralPaymentFilter({
    this.reference = '',
    this.type,
    this.categoryId,
    this.debitAccountId,
    this.creditAccountId,
    this.period,
    this.customFrom,
    this.customTo,
  });

  static const none = GeneralPaymentFilter();

  final String reference;
  final GeneralPaymentType? type;
  final String? categoryId;
  final String? debitAccountId;
  final String? creditAccountId;

  /// Date Range preset; null means every date.
  final ReportPeriod? period;

  /// Whole days of the Custom range; either end may be open.
  final DateTime? customFrom, customTo;

  bool get isActive =>
      reference.trim().isNotEmpty ||
      type != null ||
      categoryId != null ||
      debitAccountId != null ||
      creditAccountId != null ||
      period != null;

  /// The Custom From is after its To: no entry can match.
  bool get isInverted =>
      period == ReportPeriod.custom &&
      ReportDateRange(from: customFrom, to: customTo).isInverted;

  /// The first and last day included on [now]'s calendar; open ends when
  /// every date is wanted. Payment dates are whole days, so the presets'
  /// whole-day ranges are exact. Last 3 Months starts on the same day three
  /// months back, or that month's last day when it is shorter (May 31 →
  /// Feb 28), never rolling into the month after.
  ReportDateRange dateRange(DateTime now) => switch (period) {
        null => ReportDateRange.empty,
        ReportPeriod.custom => ReportDateRange(from: customFrom, to: customTo),
        ReportPeriod.last3Months =>
          ReportDateRange(from: _monthsBack(now, 3), to: _day(now)),
        final preset => preset.approximateRange(now),
      };

  static DateTime _monthsBack(DateTime now, int months) {
    final lastDay = DateTime(now.year, now.month - months + 1, 0).day;
    return DateTime(
        now.year, now.month - months, now.day < lastDay ? now.day : lastDay);
  }

  bool matches(GeneralPayment row, DateTime now) {
    final text = reference.trim().toLowerCase();
    if (text.isNotEmpty && !row.referenceNumber.toLowerCase().contains(text)) {
      return false;
    }
    if (type != null && row.type != type) return false;
    if (categoryId != null && row.categoryId != categoryId) return false;
    if (debitAccountId != null && row.debitAccountId != debitAccountId) {
      return false;
    }
    if (creditAccountId != null && row.creditAccountId != creditAccountId) {
      return false;
    }
    if (isInverted) return false;
    final range = dateRange(now);
    final day = row.paymentDate;
    if (range.from case final from? when day.isBefore(_day(from))) {
      return false;
    }
    if (range.to case final to? when day.isAfter(_day(to))) return false;
    return true;
  }

  /// Nullable fields take a function so they can be set back to null.
  GeneralPaymentFilter copyWith({
    String? reference,
    GeneralPaymentType? Function()? type,
    String? Function()? categoryId,
    String? Function()? debitAccountId,
    String? Function()? creditAccountId,
    ReportPeriod? Function()? period,
    DateTime? Function()? customFrom,
    DateTime? Function()? customTo,
  }) =>
      GeneralPaymentFilter(
        reference: reference ?? this.reference,
        type: type == null ? this.type : type(),
        categoryId: categoryId == null ? this.categoryId : categoryId(),
        debitAccountId:
            debitAccountId == null ? this.debitAccountId : debitAccountId(),
        creditAccountId:
            creditAccountId == null ? this.creditAccountId : creditAccountId(),
        period: period == null ? this.period : period(),
        customFrom: customFrom == null ? this.customFrom : customFrom(),
        customTo: customTo == null ? this.customTo : customTo(),
      );

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  bool operator ==(Object other) =>
      other is GeneralPaymentFilter &&
      other.reference == reference &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.debitAccountId == debitAccountId &&
      other.creditAccountId == creditAccountId &&
      other.period == period &&
      other.customFrom == customFrom &&
      other.customTo == customTo;

  @override
  int get hashCode => Object.hash(reference, type, categoryId, debitAccountId,
      creditAccountId, period, customFrom, customTo);
}
