/// Tolerant readers for values in report API responses, shared by the
/// reports that parse loosely typed JSON (numbers as strings, lists of
/// names, `{name: ...}` maps).
library;

int? reportInt(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}'.trim());

/// A finite amount from a number or numeric string; null when missing/bad.
double? reportAmount(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}'.replaceAll(',', '').trim());
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Trimmed text, or null when empty. Maps such as `{name: ...}` give their
/// name; lists are joined with ", ".
String? reportText(Object? value) {
  if (value is Map) return reportText(value['name'] ?? value['label']);
  if (value is List) {
    final parts = [
      for (final v in value)
        if (reportText(v) case final String text) text
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// The first non-empty value among [keys] of [json].
Object? reportField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && reportText(value) != null) return value;
  }
  return null;
}
