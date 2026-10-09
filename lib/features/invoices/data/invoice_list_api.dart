import 'package:http/http.dart' as http;

/// List read transport only. Latest-request guards/publication stay in the
/// compatibility provider shared with existing invoice row actions.
Future<http.Response> fetchInvoiceListPage(Uri uri,
        {required Map<String, String> headers, http.Client? client}) =>
    client == null
        ? http.get(uri, headers: headers)
        : client.get(uri, headers: headers);
