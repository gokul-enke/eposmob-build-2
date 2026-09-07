import 'package:pos_machine/resources/localization_service.dart';

/// Shared handling for the `translations` field the API attaches to
/// reference data (delivery methods, master-data values, payment methods).
///
/// ## Why this is not just `Map<String, String>.from(json)`
///
/// The backend has been observed emitting three different shapes for the same
/// logical field, and a parser that handles only the documented one silently
/// discards the other two — the failure mode is an empty map and a label that
/// falls back to the server-resolved text, so nothing throws and nothing is
/// logged, but offline language switching stops working.
///
/// 1. `{"en": "Car Delivery", "ar": "التوصيل بالسيارة"}` — the agreed contract.
/// 2. `[]` — PHP's `json_encode` of an empty associative array. This is what
///    every untranslated record looks like today.
/// 3. `[{"locale": "ar", "key": "name", "value": "...", "language": {…}}]` —
///    the raw translation *rows*, which is what `list-delivery-methods`
///    actually returns.
///
/// See `TRANSLATION_BACKEND_STATUS.md` for the captured payloads.
class ApiTranslations {
  ApiTranslations._();

  /// Parses any of the three shapes into `{baseLanguage: text}`.
  ///
  /// [fields] names the translated column(s) to read out of shape 3, in
  /// descending priority — delivery methods translate `name`, master data
  /// translates `description`. A row that names none of them is skipped; a row
  /// with no `key` at all is assumed to be the wanted column, since the older
  /// row format omitted it.
  ///
  /// Keys are lowercased and `_` is normalized to `-`, because the backend's
  /// language table stores `en_ar` while its master-data payload reports the
  /// same language as `en-ar`. A region-qualified key (`ar-sa`) additionally
  /// populates its base language (`ar`) when that is not already present,
  /// since lookups are by base language only.
  static Map<String, String> parse(
    dynamic raw, {
    List<String> fields = const ['name'],
  }) {
    final Map<String, String> result;
    if (raw is Map) {
      result = _fromMap(raw);
    } else if (raw is List) {
      result = _fromRows(raw, fields);
    } else {
      return const {};
    }

    if (result.isEmpty) return const {};

    // Backfill base languages from region-qualified keys (`ar-sa` -> `ar`).
    for (final entry in result.entries.toList()) {
      final dashIndex = entry.key.indexOf('-');
      if (dashIndex > 0) {
        result.putIfAbsent(entry.key.substring(0, dashIndex), () => entry.value);
      }
    }

    return result;
  }

  /// Resolves the label to show for the active app locale.
  ///
  /// Resolving at render time rather than at fetch time is what lets a language
  /// switch relabel cached data with no network call — which is the entire
  /// reason the translations map is shipped inline.
  ///
  /// [fallback] is the server-resolved text that came alongside the map; it
  /// wins over an English translation, because the server already applied the
  /// tenant's own fallback chain to produce it. English is used only when the
  /// fallback is itself empty.
  static String resolve(
    Map<String, String> translations, {
    required String fallback,
  }) {
    if (translations.isNotEmpty) {
      final active = LocalizationService.locale.languageCode.toLowerCase();
      final exact = translations[active];
      if (exact != null && exact.trim().isNotEmpty) return exact.trim();
    }

    final trimmedFallback = fallback.trim();
    if (trimmedFallback.isNotEmpty) return trimmedFallback;

    final english = translations['en'];
    if (english != null && english.trim().isNotEmpty) return english.trim();

    return fallback;
  }

  /// Shape 1: `{locale: label}`.
  static Map<String, String> _fromMap(Map<dynamic, dynamic> raw) {
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      final normalizedKey = normalizeLocale(key.toString());
      if (normalizedKey.isEmpty) return;
      result[normalizedKey] = text;
    });
    return result;
  }

  /// Shape 3: a list of `(locale, key, value)` translation rows.
  ///
  /// A row set can carry several translated columns per locale, so the winner
  /// for a locale is the row naming the highest-priority entry of [fields].
  static Map<String, String> _fromRows(
    List<dynamic> rows,
    List<String> fields,
  ) {
    final wanted = [
      for (final field in fields) field.trim().toLowerCase(),
    ];

    final result = <String, String>{};
    final priorities = <String, int>{};

    for (final row in rows) {
      if (row is! Map) continue;

      final column = row['key']?.toString().trim().toLowerCase();
      // An absent key means the old shape, which only ever carried one column.
      final priority =
          (column == null || column.isEmpty) ? 0 : wanted.indexOf(column);
      if (priority < 0) continue;

      final locale = _localeOfRow(row);
      if (locale == null || locale.isEmpty) continue;

      final text = row['value']?.toString().trim();
      if (text == null || text.isEmpty) continue;

      final existing = priorities[locale];
      // Strictly-better only, so the first row wins a tie and a duplicate
      // cannot flip the label non-deterministically.
      if (existing != null && existing <= priority) continue;

      priorities[locale] = priority;
      result[locale] = text;
    }

    return result;
  }

  /// Row locale, preferring the flat `locale` column and falling back to the
  /// nested `language.code` object the API embeds alongside it.
  static String? _localeOfRow(Map<dynamic, dynamic> row) {
    final direct = row['locale']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return normalizeLocale(direct);
    }

    final language = row['language'];
    if (language is Map) {
      final code = language['code']?.toString();
      if (code != null && code.trim().isNotEmpty) {
        return normalizeLocale(code);
      }
    }

    return null;
  }

  static String normalizeLocale(String raw) =>
      raw.trim().toLowerCase().replaceAll('_', '-');
}
