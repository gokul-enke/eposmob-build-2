import 'report_date_range.dart';

/// Date Range options of the order reports. The API works out the preset
/// ranges itself; only [custom] sends dates. Each report offers its own subset
/// (see the report's controller).
enum ReportPeriod {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  last3Months,
  custom;

  /// Translation key of the option label.
  String get labelKey => 'report_period.$name';

  /// Roughly the range this preset covers on [now]'s calendar, as whole days.
  /// Only used to prefill the custom dates when switching to [custom], so the
  /// user starts from what was on screen instead of every order.
  ReportDateRange approximateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.today:
        return ReportDateRange(from: today, to: today);
      case ReportPeriod.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return ReportDateRange(
            from: monday, to: monday.add(const Duration(days: 6)));
      case ReportPeriod.thisMonth:
        return ReportDateRange(
            from: DateTime(now.year, now.month),
            to: DateTime(now.year, now.month + 1, 0));
      case ReportPeriod.lastMonth:
        return ReportDateRange(
            from: DateTime(now.year, now.month - 1),
            to: DateTime(now.year, now.month, 0));
      case ReportPeriod.last3Months:
        return ReportDateRange(
            from: DateTime(now.year, now.month - 3, now.day), to: today);
      case ReportPeriod.custom:
        return ReportDateRange.empty;
    }
  }
}

/// `yyyy-MM-dd`, the date format of the report APIs.
String reportApiDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
      '${two(value.day)}';
}
