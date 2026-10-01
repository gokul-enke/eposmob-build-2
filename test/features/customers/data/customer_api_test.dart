import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/customers/data/customer_api.dart';

import '../support/customer_test_doubles.dart';

void main() {
  group('fetchPage', () {
    Future<CustomerPage> fetch(http.Response response) {
      final api = CustomerApi(
        httpGet: (url, {headers}) async => response,
        session: const FakeTenantSession(),
      );
      return api.fetchPage(
        accessToken: 't',
        apiKey: 'k',
        queryParameters: const {'page': '1'},
      );
    }

    test('parses a successful page', () async {
      final page = await fetch(jsonResponse(customersPage([
        {'id': 1, 'name': 'Ann'},
      ])));
      expect(page.model.data!.single.name, 'Ann');
      expect(page.payload['status'], 'success');
    });

    test('throws on non-200, non-object bodies and error status', () async {
      expect(fetch(http.Response('', 500)), throwsA(isA<HttpException>()));
      expect(fetch(http.Response('[]', 200)), throwsA(isA<FormatException>()));
      expect(
        fetch(jsonResponse({'status': 'error', 'message': 'nope'})),
        throwsA(isA<HttpException>().having(
          (error) => error.message,
          'message',
          'nope',
        )),
      );
    });

    test('sends bearer and tenant headers', () async {
      Map<String, String>? sent;
      final api = CustomerApi(
        httpGet: (url, {headers}) async {
          sent = headers;
          return jsonResponse(customersPage(const []));
        },
      );
      await api.fetchPage(
        accessToken: 'tok',
        apiKey: 'ten',
        queryParameters: const {},
      );
      expect(sent!['Authorization'], 'Bearer tok');
      expect(sent!['X-Tenant'], 'ten');
    });
  });

  group('mutations', () {
    CustomerApi apiReturning(Future<http.Response> Function() respond,
        {String? apiKey = 'k'}) {
      return CustomerApi(
        httpPost: (url, {headers, body}) => respond(),
        session: FakeTenantSession(key: apiKey),
      );
    }

    test('returns the decoded body on success', () async {
      final api = apiReturning(
          () async => jsonResponse({'status': 'success', 'id': 3}, 201));
      expect(await api.create('t', const {}), {'status': 'success', 'id': 3});
    });

    test('returns the server error body when there is one', () async {
      final api = apiReturning(() async => jsonResponse({
            'status': 'error',
            'errors': {
              'phone': ['taken']
            }
          }, 422));
      final result = await api.update('t', const {}) as Map;
      expect(result['errors'], {
        'phone': ['taken']
      });
    });

    test('returns a generic error for an empty or unreadable error body',
        () async {
      final empty = apiReturning(() async => http.Response('', 500));
      final garbage = apiReturning(() async => http.Response('<html>', 500));
      expect(((await empty.create('t', const {})) as Map)['status'], 'error');
      expect(
        ((await garbage.create('t', const {})) as Map)['errors'],
        containsPair('general', ['Error processing your request']),
      );
    });

    test('returns a connection error when the request fails', () async {
      final api = apiReturning(() async => throw const SocketException('x'));
      final result = await api.create('t', const {}) as Map;
      expect(result['message'], 'Failed to connect to server');
    });

    test('throws when no API key is stored', () async {
      final api = apiReturning(() async => jsonResponse({}), apiKey: null);
      await expectLater(
          api.create('t', const {}), throwsA(isA<HttpException>()));
    });

    test('posts the JSON body to the endpoint', () async {
      Object? sentBody;
      final api = CustomerApi(
        httpPost: (url, {headers, body}) async {
          sentBody = body;
          return jsonResponse({'status': 'success'});
        },
        session: const FakeTenantSession(),
      );
      await api.addAddress('t', const {'line': 'A'});
      expect(jsonDecode(sentBody! as String), {'line': 'A'});
    });
  });

  group('lookups', () {
    test('adds the store id and maps HTTP errors to messages', () async {
      Uri? requested;
      var status = 200;
      final api = CustomerApi(
        httpGet: (url, {headers}) async {
          requested = url;
          return jsonResponse({'status': 'success'}, status);
        },
        session: const FakeTenantSession(storeId: 9),
      );

      await api.findByPhone('t', '555');
      expect(
          requested!.queryParameters, {'filter_phone': '555', 'store_id': '9'});

      status = 404;
      await expectLater(
        api.findByName('t', 'Ann'),
        throwsA(isA<HttpException>().having(
            (e) => e.message, 'message', 'Customer Not Found. Try Again!')),
      );
      status = 302;
      await expectLater(api.fetchById('t', 1), throwsA(isA<HttpException>()));
    });
  });
}
