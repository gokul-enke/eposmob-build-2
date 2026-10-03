List<dynamic> extractExpenseOptionList(
    dynamic data, List<String> candidateKeys) {
  if (data is! Map<String, dynamic>) return const [];

  for (final key in candidateKeys) {
    final value = data[key];
    if (value is List) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      final nestedList = _extractFirstList(value);
      if (nestedList.isNotEmpty) {
        return nestedList;
      }
    }
  }

  if (candidateKeys.isNotEmpty) return const [];
  return _extractFirstList(data);
}

List<dynamic> _extractFirstList(Map<String, dynamic> map) {
  for (final value in map.values) {
    if (value is List) {
      return value;
    }
  }
  return const [];
}

List<Map<String, dynamic>> normalizeExpenseOptionList(List<dynamic> rawList) {
  final seen = <String>{};
  final normalized = <Map<String, dynamic>>[];

  for (final item in rawList) {
    final option = _normalizeOption(item);
    if (option == null) continue;
    final id = option['id']?.toString().trim() ?? '';
    final name = option['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) continue;
    if (seen.add(id)) {
      normalized.add({
        'id': id,
        'name': name,
      });
    }
  }

  return normalized;
}

Map<String, dynamic>? _normalizeOption(dynamic raw) {
  if (raw is String || raw is num) {
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return {'id': text, 'name': text};
  }

  if (raw is! Map) return null;

  String? id;
  for (final key in const [
    'id',
    'value',
    'code',
    'category_id',
    'payment_method_id',
    'account_id',
  ]) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      id = value.toString().trim();
      break;
    }
  }

  String? name;
  for (final key in const [
    'name',
    'description',
    'label',
    'title',
    'value',
    'category_name',
    'payment_method_name',
    'account_name',
  ]) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      name = value.toString().trim();
      break;
    }
  }

  if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
    return null;
  }

  return {
    'id': id ?? name!,
    'name': name ?? id!,
  };
}
