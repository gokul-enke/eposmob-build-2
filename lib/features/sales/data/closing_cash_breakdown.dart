/// Preserve the closing endpoint's denomination strings and integer counts.
List<Map<String, dynamic>> closingCashBreakdown(
    List<String> denominations, List<String> counts) {
  final result = <Map<String, dynamic>>[];
  for (var i = 0; i < denominations.length; i++) {
    final denomination = denominations[i].trim();
    final count = counts[i].trim();
    if (denomination.isEmpty && count.isEmpty) continue;
    result
        .add({'denomination': denomination, 'count': int.tryParse(count) ?? 0});
  }
  return result;
}
