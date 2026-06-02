/// Fallback delivery method ID when no default is configured.
const String kFallbackDeliveryMethodId = '11';

/// Checks if an API response status indicates success.
///
/// Keeps support for the known server typo `sucesss`.
bool isApiSuccess(dynamic response) {
  if (response == null) return false;
  final status = (response['status'] as String?)?.toLowerCase();
  return status == 'success' || status == 'sucesss';
}
