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
      this.from,
      this.until,
      this.businessDate,
      this.storeId,
      this.isOnlineSales = false});
  final String number, customer, phone, email, price, status;
  final DateTime? from, until, businessDate;
  final int? storeId;
  final bool isOnlineSales;
  static String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String dateTime(DateTime value) => '${date(value)} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
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
      from != null ||
      until != null ||
      businessDate != null;
}
