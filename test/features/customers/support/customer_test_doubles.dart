export '../../../test_support/network_fakes.dart';

/// A one-page customers payload.
Map<String, dynamic> customersPage(List<Map<String, dynamic>> customers) => {
      'status': 'success',
      'message': 'ok',
      'data': {
        'current_page': 1,
        'last_page': 1,
        'per_page': 100,
        'total': customers.length,
        'data': customers,
      },
    };
