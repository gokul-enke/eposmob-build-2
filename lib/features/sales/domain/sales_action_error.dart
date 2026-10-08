class SalesApiException implements Exception {
  const SalesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
