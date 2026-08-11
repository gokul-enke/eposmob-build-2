import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/subscription/domain/company_subscription.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'api_key': 'tenant-key',
      'company_id': 10,
      'company_name': 'Example Company',
    });
    SubscriptionAccessRegistry.update(null, verificationFailed: true);
  });

  group('CompanySubscription', () {
    test('parses canonical nested login payload', () {
      final subscription = CompanySubscription.tryParsePayload({
        'status': 'success',
        'data': {
          'company_id': 10,
          'subscription': {
            'subscription_status': 'warning',
            'message': 'Expires soon',
            'valid_until': '2026-08-07T23:59:59Z',
            'manage_subscription_url': 'https://example.com/subscription',
          },
        },
      });

      expect(subscription, isNotNull);
      expect(subscription!.companyId, 10);
      expect(subscription.status, CompanySubscriptionStatus.warning);
      expect(subscription.message, 'Expires soon');
      expect(subscription.validUntil, DateTime.parse('2026-08-07T23:59:59Z'));
    });

    test('does not mistake API success status for subscription status', () {
      final subscription = CompanySubscription.tryParsePayload({
        'status': 'success',
        'data': {'company_id': 10},
      });

      expect(subscription, isNull);
    });

    test('maps backend terminal statuses to blocked', () {
      for (final status in ['blocked', 'expired', 'suspended', 'inactive']) {
        final subscription = CompanySubscription.fromJson({
          'subscription_status': status,
          'message': status,
        });
        expect(subscription.status, CompanySubscriptionStatus.blocked);
      }
    });
  });

  group('App settings subscription fallback', () {
    test('defaults fallback enablement to false when key is missing', () {
      final settings = AppSettings.fromJson({'data': <dynamic>[]});

      expect(settings.companySubscriptionFallbackEnabled, isFalse);
      expect(settings.companySubscriptionStatus, isEmpty);
      expect(
        AppSettingsProvider.resolveCompanySubscriptionFallback(settings)
            ?.status,
        CompanySubscriptionStatus.active,
      );
    });

    test('parses enabled fallback keys', () {
      final settings = AppSettings.fromJson({
        'data': [
          {
            'code': 'COMPANY_SUBSCRIPTION_STATUS',
            'status': true,
            'value': 'warning',
          },
          {
            'code': 'COMPANY_SUBSCRIPTION_MESSAGE',
            'status': true,
            'value': 'Renew soon',
          },
          {
            'code': 'COMPANY_SUBSCRIPTION_VALID_UNTIL',
            'status': true,
            'value': '2026-08-07T23:59:59Z',
          },
          {
            'code': 'COMPANY_SUBSCRIPTION_MANAGE_URL',
            'status': true,
            'value': 'https://example.com/subscription',
          },
        ],
      });

      expect(settings.companySubscriptionFallbackEnabled, isTrue);
      expect(settings.companySubscriptionStatus, 'warning');
      expect(settings.companySubscriptionMessage, 'Renew soon');
      expect(
        settings.companySubscriptionValidUntil,
        '2026-08-07T23:59:59Z',
      );
      expect(
        settings.companySubscriptionManageUrl,
        'https://example.com/subscription',
      );
    });

    test('disabled status row does not enable the fallback', () {
      final settings = AppSettings.fromJson({
        'data': [
          {
            'code': 'COMPANY_SUBSCRIPTION_STATUS',
            'status': false,
            'value': 'active',
          },
        ],
      });

      expect(settings.companySubscriptionFallbackEnabled, isFalse);
      expect(
        AppSettingsProvider.resolveCompanySubscriptionFallback(settings)
            ?.status,
        CompanySubscriptionStatus.active,
      );
    });

    test('enabled fallback with an invalid value remains unverifiable', () {
      final settings = AppSettings.fromJson({
        'data': [
          {
            'code': 'COMPANY_SUBSCRIPTION_STATUS',
            'status': true,
            'value': 'not-a-valid-status',
          },
        ],
      });

      expect(
        AppSettingsProvider.resolveCompanySubscriptionFallback(settings),
        isNull,
      );
    });
  });

  group('SubscriptionProvider', () {
    test('accepts login state and enables low-level order access', () async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      final accepted = await provider.applyLoginPayload({
        'data': {
          'company_id': 10,
          'subscription': {
            'subscription_status': 'active',
            'message': '',
          },
        },
      });

      expect(accepted, isTrue);
      expect(provider.status, CompanySubscriptionStatus.active);
      expect(SubscriptionAccessRegistry.permitsOrderSubmission, isTrue);
      provider.dispose();
    });

    test('refresh sends tenant auth and stores warning state', () async {
      late http.Request captured;
      final provider = SubscriptionProvider(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'subscription': {
                  'company_id': 10,
                  'subscription_status': 'warning',
                  'message': 'Renew soon',
                },
              },
            }),
            200,
          );
        }),
      );

      expect(await provider.refresh(), isTrue);
      expect(captured.headers['Authorization'], 'Bearer token');
      expect(captured.headers['X-Tenant'], 'tenant-key');
      expect(provider.status, CompanySubscriptionStatus.warning);
      expect(SubscriptionAccessRegistry.permitsOrderSubmission, isTrue);
      provider.dispose();
    });

    test('verification failure is fail-closed', () async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );

      expect(await provider.refresh(), isFalse);
      expect(provider.status, CompanySubscriptionStatus.unknown);
      expect(SubscriptionAccessRegistry.permitsOrderSubmission, isFalse);
      expect(
        SubscriptionAccessRegistry.rejectedOrderResponse()?['code'],
        'SUBSCRIPTION_UNVERIFIED',
      );
      provider.dispose();
    });

    test('uses app-settings fallback when refresh endpoint is unavailable',
        () async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      provider.setFallbackLoader(() async => const CompanySubscription(
            companyId: 10,
            status: CompanySubscriptionStatus.warning,
            message: 'Renew soon',
          ));

      expect(await provider.refresh(), isTrue);
      expect(provider.status, CompanySubscriptionStatus.warning);
      expect(provider.subscription?.message, 'Renew soon');
      expect(SubscriptionAccessRegistry.permitsOrderSubmission, isTrue);
      provider.dispose();
    });

    test('dedicated refresh response takes precedence over fallback', () async {
      var fallbackCalled = false;
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'data': {
                  'subscription': {
                    'company_id': 10,
                    'subscription_status': 'blocked',
                    'message': 'Dedicated API block',
                  },
                },
              }),
              200,
            )),
      );
      provider.setFallbackLoader(() async {
        fallbackCalled = true;
        return const CompanySubscription(
          companyId: 10,
          status: CompanySubscriptionStatus.active,
          message: '',
        );
      });

      expect(await provider.refresh(), isTrue);
      expect(provider.status, CompanySubscriptionStatus.blocked);
      expect(fallbackCalled, isFalse);
      provider.dispose();
    });

    test('backend block updates cache and low-level rejection', () async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      await provider.markBlockedFromBackend(message: 'Payment overdue');

      expect(provider.status, CompanySubscriptionStatus.blocked);
      expect(
        SubscriptionAccessRegistry.rejectedOrderResponse(),
        containsPair('code', 'SUBSCRIPTION_BLOCKED'),
      );
      provider.dispose();
    });
  });

  group('SubscriptionActionGuard', () {
    testWidgets('warning requires explicit continue', (tester) async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(provider.dispose);
      await provider.applyLoginPayload({
        'subscription_status': 'warning',
        'message': 'Renew in three days',
      });
      bool? allowed;

      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  allowed = await SubscriptionActionGuard
                      .ensureOrderSubmissionAllowed(
                    context,
                    refreshIfStale: false,
                  );
                },
                child: const Text('Confirm order'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Confirm order'));
      await tester.pumpAndSettle();
      expect(find.text('Subscription notice'), findsNothing);
      expect(find.text('Renew in three days'), findsOneWidget);
      expect(find.text('Example Company'), findsOneWidget);
      expect(
        find.byKey(const Key('subscription-status-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(allowed, isTrue);
    });

    testWidgets('blocked state denies submission', (tester) async {
      final provider = SubscriptionProvider(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(provider.dispose);
      await provider.applyLoginPayload({
        'subscription_status': 'blocked',
        'message': 'Payment overdue',
      });
      bool? allowed;

      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  allowed = await SubscriptionActionGuard
                      .ensureOrderSubmissionAllowed(
                    context,
                    refreshIfStale: false,
                  );
                },
                child: const Text('Confirm order'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Confirm order'));
      await tester.pumpAndSettle();
      expect(find.text('Subscription blocked'), findsNothing);
      expect(find.text('Payment overdue'), findsOneWidget);

      await tester.tap(find.text('Contact Administrator'));
      await tester.pumpAndSettle();
      expect(allowed, isFalse);
    });
  });
}
