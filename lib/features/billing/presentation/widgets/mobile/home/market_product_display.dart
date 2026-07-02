import 'package:pos_machine/models/get_product.dart';

/// Resolves the best network image URL for a market product card.
///
/// Prefers the primary attachment, then falls back to the first attachment.
/// Only returns values that look like remote URLs (http/https).
String? resolveMarketProductImageUrl(GetProduct product) {
  final attachments = product.attachment ?? const <Attachment>[];
  if (attachments.isEmpty) return null;

  Attachment? primary;
  for (final attachment in attachments) {
    if (attachment.isPrimary == 1) {
      primary = attachment;
      break;
    }
  }
  final candidates = [
    if (primary != null) _attachmentUrl(primary),
    for (final attachment in attachments) _attachmentUrl(attachment),
  ];
  for (final url in candidates) {
    if (url != null) return url;
  }
  return null;
}

String? _attachmentUrl(Attachment attachment) {
  final file = attachment.file?.toString().trim();
  final filePath = attachment.filePath?.trim();
  for (final raw in [filePath, file]) {
    if (raw == null || raw.isEmpty) continue;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  }
  return null;
}

String formatMarketProductPrice(GetProduct product, String currency) {
  final rawPrice = product.price?.price?.toString() ?? '0';
  final parsed = double.tryParse(rawPrice) ?? 0;
  final prefix = currency.isEmpty ? '' : '$currency ';
  return '$prefix${parsed.toStringAsFixed(2)}';
}

String? resolveMarketProductCategory(GetProduct product) {
  final name = product.category?.name?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}
