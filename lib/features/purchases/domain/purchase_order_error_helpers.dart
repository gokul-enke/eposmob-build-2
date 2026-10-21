bool isAlreadyFullyPaidPurchaseOrderError(
  Map<String, dynamic>? result,
  String? displayedMessage,
) {
  final candidates = <dynamic>[
    displayedMessage,
    result?['message'],
    result?['error'],
    result?['code'],
    result?['error_code'],
  ];

  return candidates.any(_isExplicitlyAlreadyPaid);
}

bool _isExplicitlyAlreadyPaid(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;

  final collapsed = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  return collapsed.contains('already_paid') ||
      collapsed.contains('already_fully_paid') ||
      (collapsed.contains('purchase_order') &&
          collapsed.contains('fully_paid'));
}

/// The receive endpoint answers 422 "Item N has already been received." when a
/// row was received earlier (e.g. by a repeated request). That is not a
/// failure: the work is already done.
bool isAlreadyReceivedPurchaseOrderError(
  Map<String, dynamic>? result,
  String? displayedMessage,
) {
  final candidates = <dynamic>[
    displayedMessage,
    result?['message'],
    result?['error'],
    result?['code'],
    result?['error_code'],
  ];

  return candidates.any(_isExplicitlyAlreadyReceived);
}

bool _isExplicitlyAlreadyReceived(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;

  final collapsed = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  return collapsed.contains('already_been_received') ||
      collapsed.contains('already_received');
}
