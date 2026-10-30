import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../domain/general_payment_entry.dart';
import '../domain/general_payment_type.dart';
import 'general_payment_api.dart' show GeneralPaymentHttpGet;

typedef GeneralPaymentHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body});

/// The New Entry calls: the accounts a kind of entry may use, and saving it.
class GeneralPaymentFormApi {
  GeneralPaymentFormApi(
      {String Function()? accountsEndpoint,
      String Function()? createEndpoint,
      GeneralPaymentHttpGet? get,
      GeneralPaymentHttpPost? post,
      this.session = const TenantSession()})
      : _accountsEndpoint =
            accountsEndpoint ?? (() => APPUrl.generalPaymentAccountOptions),
        _createEndpoint = createEndpoint ?? (() => APPUrl.createGeneralPayment),
        _get = get ?? http.get,
        _post = post ?? http.post;

  /// For loading account options only.
  static const timeout = Duration(seconds: 30);

  final String Function() _accountsEndpoint;
  final String Function() _createEndpoint;
  final GeneralPaymentHttpGet _get;
  final GeneralPaymentHttpPost _post;
  final TenantSession session;

  Future<Map<String, String>> _headers(String accessToken) async {
    final apiKey = await session.apiKey();
    if (apiKey == null) throw StateError('Tenant is unavailable.');
    return {
      ...TenantSession.headers(accessToken: accessToken, apiKey: apiKey),
      // Validation errors come back as JSON instead of a web page.
      'Accept': 'application/json',
    };
  }

  /// The debit (`expense_accounts`) and credit (`payment_accounts`) choices
  /// of [type]; loans also send which way the money moves. An answer for
  /// another type is refused rather than shown.
  Future<GeneralPaymentAccounts> accountOptions(
      {required String accessToken,
      required GeneralPaymentType type,
      GeneralPaymentLoan? loan}) async {
    final headers = await _headers(accessToken);
    final loanCode = type == GeneralPaymentType.loan
        ? (loan ?? GeneralPaymentLoan.received).code
        : null;
    final uri = Uri.parse(_accountsEndpoint()).replace(queryParameters: {
      'entry_type': type.code,
      if (loanCode != null) 'loan_type': loanCode,
    });
    final response = await _get(uri, headers: headers).timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError('Account options failed (${response.statusCode}).');
    }
    final body = json.decode(response.body);
    final data = body is Map ? body['data'] : null;
    if (body is! Map || body['success'] == false || data is! Map) {
      throw const FormatException('Invalid account options.');
    }
    final echoedType = data['entry_type']?.toString().toUpperCase();
    final echoedLoan = data['loan_type']?.toString().toUpperCase();
    if ((echoedType != null && echoedType != type.code) ||
        (loanCode != null && echoedLoan != null && echoedLoan != loanCode)) {
      throw const FormatException('Account options are for another entry.');
    }
    return GeneralPaymentAccounts(
        debit: _accounts(data['expense_accounts']),
        credit: _accounts(data['payment_accounts']));
  }

  /// `[{id, name}]`; entries without either, and repeats, are left out.
  static List<GeneralPaymentOption> _accounts(Object? raw) {
    final seen = <String>{};
    final accounts = <GeneralPaymentOption>[];
    if (raw is! List) return accounts;
    for (final item in raw) {
      if (item is! Map) continue;
      final id = '${item['id'] ?? ''}'.trim();
      final name = '${item['name'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty || !seen.add(id)) continue;
      accounts.add(GeneralPaymentOption(id, name));
    }
    return accounts;
  }

  /// Saves a new entry for the active store. A refusal (validation or a
  /// failed answer) comes back as [GeneralPaymentRejected]; a lost
  /// connection throws. No client timeout, as on Create Expense: giving up
  /// on a slow save that the server still completes would invite saving the
  /// entry twice.
  Future<GeneralPaymentSaveResult> create(
      {required String accessToken,
      required Map<String, dynamic> payload}) async {
    final headers = await _headers(accessToken);
    final storeId = await session.activeStoreId();
    final body = {...payload, if (storeId != null) 'store_id': storeId};
    final response = await _post(Uri.parse(_createEndpoint()),
        headers: headers, body: json.encode(body));
    Object? decoded;
    try {
      decoded = json.decode(response.body);
    } on FormatException {
      decoded = null;
    }
    final answer = decoded is Map ? decoded : const {};
    final ok = response.statusCode == 200 || response.statusCode == 201;
    if (ok && answer['success'] != false && answer['status'] != 'failed') {
      final data = answer['data'];
      final reference = data is Map ? data['reference_number'] : null;
      return GeneralPaymentSaved(
          reference: reference is String && reference.trim().isNotEmpty
              ? reference.trim()
              : null);
    }
    return GeneralPaymentRejected(_firstError(answer));
  }

  /// The first field error (`errors: {amount: ['...']}`), else the message.
  static String? _firstError(Map answer) {
    final errors = answer['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        final text = value is List && value.isNotEmpty ? value.first : value;
        if (text is String && text.trim().isNotEmpty) return text.trim();
      }
    }
    final message = answer['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : null;
  }
}
