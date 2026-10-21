Map<String, dynamic> detailRow(
  int id, {
  String date = '2026-10-13',
  String type = 'Credit',
  String payment = '',
  String amount = '10.125',
}) =>
    {
      'id': id,
      'date': date,
      'type': type,
      'payment_method': payment,
      'transaction_type': type == 'Credit' ? 'Invoice' : 'Voucher',
      'amount': amount,
      'currency': 'SAR',
      'reference': 'REF-$id',
      'status': 'SUCC',
    };
Map<String, dynamic> detailGroup(int id,
        {String name = 'Supplier', List<Map<String, dynamic>>? rows}) =>
    {
      'supplier_id': id,
      'supplier_name': name,
      'transactions': rows ?? [detailRow(id * 10 + 1)],
    };
Map<String, dynamic> detailResponse(
        {int page = 1,
        int last = 1,
        List<Map<String, dynamic>>? groups,
        bool legacy = false,
        int? total}) =>
    {
      'status': 'success',
      'data': legacy
          ? (groups ?? [detailGroup(7)])
          : {
              'current_page': page,
              'last_page': last,
              if (total != null) 'total': total,
              'data': groups ?? [detailGroup(7)],
            },
    };
