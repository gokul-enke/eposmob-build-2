class SalesReturnOrderIdHelper {
  /// Returns only the return order created or updated by this screen session.
  ///
  /// Item-level IDs can belong to older, completed partial returns, so they
  /// must never be used as a fallback for the completion request.
  static int? forCompletion(int? submittedReturnOrderId) {
    if (submittedReturnOrderId == null || submittedReturnOrderId <= 0) {
      return null;
    }
    return submittedReturnOrderId;
  }
}
