/// The two dates are exact-day filters, not the ends of a date range.
class QuotationListQuery {
  const QuotationListQuery(
      {this.number = '',
      this.customerId,
      this.storeId,
      this.status = 'All',
      this.quotationDate,
      this.expiryDate});
  final String number, status;
  final String? customerId;
  final int? storeId;
  final DateTime? quotationDate, expiryDate;
  static String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Map<String, String> parameters(int page, int? activeStoreId) => {
        if (storeId ?? activeStoreId case final int id) 'store_id': '$id',
        if (number.isNotEmpty) 'quotation_number': number,
        if (customerId?.isNotEmpty ?? false) 'customer_id': customerId!,
        if (status.isNotEmpty && status.toLowerCase() != 'all')
          'status': status,
        if (quotationDate != null) ...{
          'quotation_date_from': date(quotationDate!),
          'quotation_date_to': date(quotationDate!)
        },
        if (expiryDate != null) ...{
          'expiry_date_from': date(expiryDate!),
          'expiry_date_to': date(expiryDate!)
        },
        'page': '$page',
      };
  /// True when both queries send the same request parameters.
  bool sameAs(QuotationListQuery other) =>
      number == other.number &&
      _customer == other._customer &&
      storeId == other.storeId &&
      _status == other._status &&
      _sameDay(quotationDate, other.quotationDate) &&
      _sameDay(expiryDate, other.expiryDate);
  String? get _customer => (customerId?.isNotEmpty ?? false) ? customerId : null;
  String? get _status =>
      status.isEmpty || status.toLowerCase() == 'all' ? null : status;
  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null || b == null
          ? a == b
          : a.year == b.year && a.month == b.month && a.day == b.day;

  bool get active =>
      number.isNotEmpty ||
      customerId != null ||
      storeId != null ||
      status.toLowerCase() != 'all' ||
      quotationDate != null ||
      expiryDate != null;
}
