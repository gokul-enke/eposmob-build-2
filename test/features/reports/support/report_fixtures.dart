/// One customer group row of the Customer Transactions Report API.
Map<String, dynamic> customerGroup(Object id, [String name = 'Customer']) => {
      'customer_id': id,
      'customer_name': name,
      'total_debit': '12.125',
      'total_credit': 2,
      'balance': '-10.125',
      'transaction_count': '3'
    };

/// A Customer Transactions Report API page.
Map<String, dynamic> customerReportResponse(
        int page, List<Map<String, dynamic>> rows,
        {int last = 1, int? total}) =>
    {
      'status': 'success',
      'data': {
        'data': rows,
        'current_page': page,
        'last_page': last,
        'per_page': 20,
        if (total != null) 'total': total
      }
    };

/// One sales executive row of the My Sales Report API.
Map<String, dynamic> salesRow(String name) => {
      'name': name,
      'phone': '0012345',
      'order_count': 2,
      'total_sales': '12.125',
      'online_sales': '2.125',
      'cash_sales': 5,
      'credit_sales': 5,
      'collected_sales': '4.125',
      'payment_breakdown': {'UPI': 1.125, 'CARD': 1},
      'total_payment_received': 8.25,
      'total_collected_on_sale': 4.125,
      'credit_collected_prev': 4.125
    };

/// A My Sales Report API response.
Map<String, dynamic> salesReport([List<Map<String, dynamic>>? rows]) => {
      'status': 'success',
      'data': rows ?? [salesRow('My Executive')]
    };
