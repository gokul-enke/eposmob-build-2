/// Pure lookup port; the shared payment directory supplies the current codes.
class SalesPaymentCodes {
  SalesPaymentCodes._();
  static String? Function(String) resolve = (_) => null;
}
