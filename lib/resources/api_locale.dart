import 'package:pos_machine/resources/localization_service.dart';

/// Single source of truth for attaching the active language to API requests
/// and to local cache keys.
///
/// ## Precedence
///
/// Every localized request carries the language **twice**: as `?locale=` and as
/// the `Accept-Language` header, with the same value.
///
/// The backend's current precedence is inconsistent — `Accept-Language`
/// overrides `?locale=` on master-data values and delivery methods, but is
/// ignored on website settings, cart-item statuses and product units. It has
/// been agreed that `?locale=` becomes authoritative everywhere, but until that
/// ships, sending identical values in both places makes the resolved language
/// the same under either rule. No transition window to coordinate.
class ApiLocale {
  ApiLocale._();

  /// Master switch for sending the language to the API.
  ///
  /// Set to `false` to make every request behave exactly as it did before this
  /// change — no `locale` param, no `Accept-Language` — which makes the backend
  /// serve its default language. One-line rollback if QA finds trouble.
  static const bool enabled = true;

  /// Endpoints that must NOT receive `locale` yet.
  ///
  /// `product/list-units` is documented to swap the meaning of its `data` map
  /// when a locale is present: without one it returns the original unit values
  /// (`PCS`), with one it returns translated descriptions (`قطعة`). Product
  /// unit resolution matches a stored unit against those values, so requesting
  /// a locale here would break the unit dropdown on the product, stock and
  /// purchase forms.
  ///
  /// A live capture on 2026-09-04 showed `data` *not* varying by locale, but
  /// the additive `labels` map (backend action item 1 in
  /// TRANSLATION_AGREED_SCOPE.md) has not shipped either, so requesting a
  /// locale here currently buys nothing and risks the documented behaviour on
  /// another backend build. `UnitsResponse` already parses `labels`, so
  /// unblocking is deleting the line below and nothing else.
  ///
  /// Every other endpoint was verified to return byte-identical payloads with
  /// and without `?locale=`, with machine keys/values frozen — so sending the
  /// locale is a no-op today and starts working the moment the backend
  /// resolves labels, with no client change.
  static const Set<String> notYetLocalized = {
    'product/list-units',
  };

  /// Whether [uri] will actually carry the language. Callers that build their
  /// own headers need this to keep `Accept-Language` consistent with the query
  /// parameter, since the backend lets the header override the param.
  static bool isLocalized(Uri uri) {
    if (!enabled) return false;
    final path = uri.path;
    for (final blocked in notYetLocalized) {
      if (path.contains(blocked)) return false;
    }
    return true;
  }

  /// Languages the app ships translation bundles for.
  ///
  /// Derived from [LocalizationService.supportedLocales] rather than being a
  /// second hardcoded list: when the two drifted, a Malayalam session silently
  /// requested `en` from the API and rendered Malayalam UI chrome around
  /// English payment and delivery labels. The backend falls back to its base
  /// language for a locale it has no translations for, which is exactly the
  /// behaviour we want while a language is only partly seeded.
  static Set<String> get supported => {
        for (final locale in LocalizationService.supportedLocales)
          locale.languageCode.trim().toLowerCase(),
      };

  static const String fallback = 'en';

  /// Active language as a base code (`en`, `ar`), clamped to [supported].
  static String get current {
    final code = LocalizationService.locale.languageCode.trim().toLowerCase();
    final base = code.contains('-') ? code.split('-').first : code;
    return supported.contains(base) ? base : fallback;
  }

  /// Adds `locale` to a URL's query string, preserving existing parameters.
  /// A no-op for endpoints in [notYetLocalized] or when [enabled] is false.
  static Uri apply(Uri uri) {
    if (!isLocalized(uri)) return uri;
    final params = Map<String, String>.from(uri.queryParameters);
    params['locale'] = current;
    return uri.replace(queryParameters: params);
  }

  /// Convenience for the common `Uri.parse(url).replace(queryParameters: ...)`
  /// pattern used across the providers.
  static Uri build(String url, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(url);
    final params = Map<String, String>.from(base.queryParameters);
    if (queryParameters != null) params.addAll(queryParameters);
    final merged = base.replace(queryParameters: params);
    return apply(merged);
  }

  /// Suffix for any SharedPreferences key holding a localized response.
  ///
  /// A cached Arabic payload must never be served to an English session, so the
  /// language becomes part of the key rather than being ignored on read.
  static String cacheSuffix() => '_$current';

  /// Standard headers for a localized request.
  ///
  /// Set [localized] to false for an endpoint in [notYetLocalized] so the
  /// header does not silently localize a response the query param deliberately
  /// left alone — the backend currently lets `Accept-Language` override
  /// `?locale=` on master data and delivery methods.
  static Map<String, String> headers({
    required String apiKey,
    String? accessToken,
    bool json = true,
    bool localized = true,
  }) {
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (enabled && localized) 'Accept-Language': current,
      'X-Tenant': apiKey,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }
}
