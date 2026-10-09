import 'package:pos_machine/models/get_product.dart';

/// Resolves an actual product image without changing its attachments.
String? resolveProductAttachmentImageUrl(GetProduct product) {
  final attachments = product.attachment ?? const <Attachment>[];
  for (final attachment in [
    ...attachments.where((attachment) => attachment.isPrimary == 1),
    ...attachments.where((attachment) => attachment.isPrimary != 1),
  ]) {
    final url = usableProductImageUrl(attachment.filePath) ??
        usableProductImageUrl(attachment.file?.toString());
    if (url != null) return url;
  }
  return null;
}

/// Empty values, local filenames and malformed URLs cannot be network images.
String? usableProductImageUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return trimmed;
}
