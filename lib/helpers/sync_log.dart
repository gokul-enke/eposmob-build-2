import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/get_product.dart';

/// What one product fetch changed. Set by
/// `LocalProductProvider.fetchProductsFromAPI` and printed by the Sync button.
class ProductFetchSummary {
  const ProductFetchSummary({
    required this.delta,
    required this.products,
    required this.addedIds,
    required this.deletedIds,
    required this.total,
    required this.elapsed,
  });

  /// True for a delta sync (only changed products came back).
  final bool delta;

  /// Every product the server returned in this fetch, deleted ones excluded.
  final List<GetProduct> products;

  /// Products that were not in the local catalog before (delta sync only).
  final Set<int> addedIds;
  final Set<int> deletedIds;

  /// Catalog size after the fetch.
  final int total;
  final Duration elapsed;
}

/// Compact logging for the Sync button.
///
/// The providers a sync runs print hundreds of routine lines. [quiet] hides
/// them for the duration of the sync while warnings and errors still print,
/// so the log shows one line per step plus the details of the products that
/// changed.
abstract final class SyncLog {
  static const _tag = '[Sync]';

  /// Full details are printed for at most this many products; a full sync
  /// of a large catalog lists the rest by count only.
  static const maxDetailedProducts = 20;

  static void line(String message) => debugPrint('$_tag $message');

  static const _apiTag = '[API]';

  /// One line per planned call: `GET <url> · <label>`.
  static void plan(List<({String method, String url, String label})> calls) {
    final methods = calls.map((c) => c.method).toSet().join('/');
    line('Plan: ${calls.length} call(s), $methods');
    for (final c in calls) {
      line('  ${c.method} ${c.url} · ${c.label}');
    }
  }

  /// Logs an outgoing request: the full URL (paste it into Postman as-is),
  /// the query params decoded, headers with secrets masked, and the body.
  static void request(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
  }) {
    debugPrint('$_apiTag → $method $url');
    if (url.queryParameters.isNotEmpty) {
      final params = url.queryParameters.entries
          .map((e) => '${e.key}=${e.value}')
          .join(' · ');
      debugPrint('$_apiTag   params $params');
    }
    if (headers.isNotEmpty) {
      final shown = headers.entries
          .map((e) => '${e.key}: ${_maskHeader(e.key, e.value)}')
          .join(' · ');
      debugPrint('$_apiTag   headers $shown');
    }
    debugPrint('$_apiTag   body ${body ?? '(none)'}');
  }

  /// Logs a response in one line; [detail] is endpoint-specific.
  static void response(int status, String detail) =>
      debugPrint('$_apiTag ← $status $detail');

  /// Tokens and tenant keys are shown by their first 4 characters only.
  static String _maskHeader(String name, String value) {
    final key = name.toLowerCase();
    if (key == 'authorization') {
      final token = value.replaceFirst(RegExp(r'^Bearer\s+'), '');
      return 'Bearer ${_mask(token)}';
    }
    if (key.contains('tenant') ||
        key.contains('key') ||
        key.contains('token')) {
      return _mask(value);
    }
    return value;
  }

  static String _mask(String value) => value.length <= 4
      ? '••••'
      : '${value.substring(0, 4)}•••• (${value.length} chars)';

  /// Runs [body] with routine `debugPrint` output hidden. Lines tagged
  /// `[Sync]`, and anything that looks like a warning or error, still print.
  static Future<T> quiet<T>(Future<T> Function() body) async {
    final original = debugPrint;
    var hidden = 0;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      if (_keep(message)) {
        original(message, wrapWidth: wrapWidth);
      } else {
        hidden++;
      }
    };
    try {
      return await body();
    } finally {
      // Restore only if nothing else replaced it meanwhile.
      debugPrint = original;
      original('$_tag $hidden routine log line(s) hidden');
    }
  }

  static final _problem = RegExp(
    r'❌|⚠️|💥|\berror\b|\bexception\b|\bfailed\b|\bfailure\b',
    caseSensitive: false,
  );

  static bool _keep(String message) =>
      message.startsWith(_tag) ||
      message.startsWith(_apiTag) ||
      _problem.hasMatch(message);

  /// Prints what a product fetch changed: one summary line, then the full
  /// details of each changed product.
  static void products(ProductFetchSummary? summary) {
    if (summary == null) {
      line('Products: no fetch summary (the fetch failed or was skipped)');
      return;
    }
    final kind = summary.delta ? 'delta' : 'full';
    final added = summary.addedIds.length;
    final updated = summary.delta ? summary.products.length - added : 0;
    line('Products ($kind): ${summary.products.length} received'
        '${summary.delta ? ' · $added new · $updated updated' : ''}'
        ' · ${summary.deletedIds.length} deleted'
        ' · catalog ${summary.total}'
        ' · ${summary.elapsed.inMilliseconds} ms');
    if (summary.deletedIds.isNotEmpty) {
      line('  Deleted ids: ${summary.deletedIds.join(', ')}');
    }
    final shown = summary.products.take(maxDetailedProducts);
    for (final product in shown) {
      final label = !summary.delta
          ? 'SYNCED'
          : summary.addedIds.contains(product.productId)
              ? 'NEW'
              : 'UPDATED';
      _product(label, product);
    }
    final rest = summary.products.length - maxDetailedProducts;
    if (rest > 0) {
      line('  … and $rest more product(s) not listed');
    }
  }

  /// 10.0 → 10, 2.5 → 2.5.
  static Object? _qty(num? value) =>
      value != null && value == value.truncate() ? value.toInt() : value;

  static void _product(String label, GetProduct p) {
    String v(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? '—' : text;
    }

    final lines = <String>[
      '$label #${v(p.productId)} ${v(p.productName)}',
      'barcode ${v(p.barcode)} · unit ${v(p.unit)}'
          ' · category ${v(p.category?.name)}',
      'price ${v(p.price?.price)} (total ${v(p.price?.totalPrice)})'
          ' · MRP ${v(p.mrp)} · purchase ${v(p.purchasePrice)}',
      'product SKU ${v(p.sku)}',
    ];
    final taxes = p.taxes ?? const <ProductTax>[];
    if (taxes.isNotEmpty) {
      lines.add(
          'tax ${taxes.map((t) => '${v(t.name)} ${v(t.rate)}%').join(', ')}');
    }
    final names = p.names;
    if (names is Map && names.isNotEmpty) {
      lines.add(
          'names ${names.entries.map((e) => '${e.key}: ${v(e.value)}').join(' · ')}');
    }
    for (final s in p.stock ?? const <Stock>[]) {
      lines.add('stock store ${v(s.storeId)} ${v(s.storeName)}'
          ' · qty ${v(_qty(s.quantity))} · price ${v(s.price)}'
          ' · SKU ${v(s.sku)}');
    }
    final variants = p.variants ?? const [];
    final saleUnits = p.saleUnits ?? const [];
    if (variants.isNotEmpty || saleUnits.isNotEmpty) {
      lines.add(
          '${variants.length} variant(s) · ${saleUnits.length} sale unit(s)');
    }
    debugPrint('$_tag   ${lines.join('\n$_tag     ')}');
  }
}
