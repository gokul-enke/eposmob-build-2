/// Preserve zero/default display values, without crashing on an invalid expiry.
String stockReportMoney(Object? value) =>
    (double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2);
String stockReportExpiry(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '-';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';
}

double stockReportExportNumber(Object? value) {
  if (value == null) return 0;
  final parsed = double.tryParse(value.toString());
  if (parsed == null || !parsed.isFinite) {
    throw const FormatException('Invalid stock export amount');
  }
  return parsed;
}
