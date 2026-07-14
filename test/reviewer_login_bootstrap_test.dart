import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/services/play_store_review_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('only the exact reviewer email matches, ignoring case and spaces', () {
    expect(
      PlayStoreReviewAccess.matchesEmail(' PLAYSTORESAELES@FUNZCART.IN '),
      isTrue,
    );
    expect(
      PlayStoreReviewAccess.matchesEmail('salesexecutive2@funzcart.in'),
      isFalse,
    );
  });

  test('reviewer email discovers and saves the reviewer API key before login',
      () async {
    var discoveryRequests = 0;
    var loginRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/find-domain') {
        discoveryRequests++;
        expect(
          request.headers['X-Tenant-Key'],
          PlayStoreReviewAccess.tenantKey,
        );
        return http.Response(
          '{"status":200,"data":{"domain":"https://review.example"}}',
          200,
        );
      }

      if (request.url.path == '/api/v1/user/signin') {
        loginRequests++;
        expect(request.url.host, 'review.example');
        expect(request.headers['X-Tenant'], PlayStoreReviewAccess.tenantKey);
        expect(
          jsonDecode(request.body)['email'],
          PlayStoreReviewAccess.reviewerEmail,
        );
        return http.Response('{"status":"success","data":{}}', 200);
      }

      fail('Unexpected request: ${request.url}');
    });

    final result = await AuthenticationProvider().login(
      PlayStoreReviewAccess.reviewerEmail,
      'review-password',
      null,
      client: client,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(result['status'], 'success');
    expect(discoveryRequests, 1);
    expect(loginRequests, 1);
    expect(prefs.getString('api_key'), PlayStoreReviewAccess.tenantKey);
    expect(prefs.getString('app_url'), 'https://review.example');
  });

  test('a non-reviewer without an API key is sent to API-key setup', () async {
    final client = MockClient((request) async {
      fail('No request should be made for a non-reviewer without an API key.');
    });

    expect(
      () => AuthenticationProvider().login(
        'customer@example.com',
        'password',
        null,
        client: client,
      ),
      throwsA(isA<ApiKeyRequiredException>()),
    );
  });
}
