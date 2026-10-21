/// Filters shared by Sales and Online Orders. The lookup stays uppercase;
/// From/To include time, while Business Date is an independent exact-day filter.
class SalesListQuery {
  const SalesListQuery(
      {this.number = '',
      this.customer = '',
      this.phone = '',
      this.email = '',
      this.price = '',
      this.status = 'all',
      this.paymentStatus = 'all',
      this.minAmount = '',
      this.maxAmount = '',
      this.from,
      this.until,
      this.businessDate,
      this.storeId,
      this.isOnlineSales = false});
  final String number, customer, phone, email, price, status;

  /// Payment status (`pending`, `paid`, `refunded`) or `all`.
  final String paymentStatus;

  /// Raw Min/Max Amount input; only a valid number >= 0 is sent.
  final String minAmount, maxAmount;
  final DateTime? from, until, businessDate;
  final int? storeId;
  final bool isOnlineSales;
  static String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String dateTime(DateTime value) => '${date(value)} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  /// The amount to send for a Min/Max field, or null when it is empty or not
  /// a valid number >= 0 (the backend rejects anything else). Arabic-Indic
  /// digits and the Arabic decimal/thousands marks are accepted.
  static String? amount(String raw) {
    final text = String.fromCharCodes(raw.trim().runes.expand((c) {
      if (c >= 0x0660 && c <= 0x0669) return [0x30 + c - 0x0660]; // ٠-٩
      if (c >= 0x06F0 && c <= 0x06F9) return [0x30 + c - 0x06F0]; // ۰-۹
      if (c == 0x066B) return [0x2E]; // Arabic decimal separator
      if (c == 0x066C) return const <int>[]; // Arabic thousands separator
      return [c];
    }));
    final value = double.tryParse(text);
    return value == null || value < 0 || !value.isFinite ? null : text;
  }

  /// Min/Max to send; swapped when entered the wrong way round so the user
  /// still gets the range they meant instead of an empty list.
  ({String? min, String? max}) get amountRange {
    final min = amount(minAmount), max = amount(maxAmount);
    if (min != null && max != null && double.parse(min) > double.parse(max)) {
      return (min: max, max: min);
    }
    return (min: min, max: max);
  }

  Map<String, String> parameters(int page, int? fallbackStore) => {
        if (storeId ?? fallbackStore case final int id) ...{
          'store_id': '$id',
          'filter_store': '$id',
        },
        if (number.trim().isNotEmpty) 'number': number.trim().toUpperCase(),
        if (customer.trim().isNotEmpty) 'filter_name': customer.trim(),
        if (phone.trim().isNotEmpty) 'filter_phone': phone.trim(),
        if (email.trim().isNotEmpty) 'filter_email': email.trim(),
        if (price.trim().isNotEmpty) 'filter_price': price.trim(),
        if (status.isNotEmpty && status != 'all')
          'filter_status': status.trim(),
        if (paymentStatus.isNotEmpty && paymentStatus != 'all')
          'filter_payment_status': paymentStatus.trim(),
        if (amountRange.min case final String min) 'filter_min_amount': min,
        if (amountRange.max case final String max) 'filter_max_amount': max,
        if (from != null) 'filter_datetime[from]': dateTime(from!),
        if (until != null) 'filter_datetime[until]': dateTime(until!),
        if (businessDate != null) 'business_date': date(businessDate!),
        if (isOnlineSales) 'filter_online_sales': 'true',
        'page': '$page',
      };
  bool sameAs(SalesListQuery other) {
    final left = parameters(1, null), right = other.parameters(1, null);
    return left.length == right.length &&
        left.entries.every((entry) => right[entry.key] == entry.value);
  }

  bool get active =>
      number.trim().isNotEmpty ||
      customer.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      price.trim().isNotEmpty ||
      status != 'all' ||
      paymentStatus != 'all' ||
      amount(minAmount) != null ||
      amount(maxAmount) != null ||
      from != null ||
      until != null ||
      businessDate != null;
}
