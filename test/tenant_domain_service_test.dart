import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/services/tenant_domain_service.dart';

void main() {
  group('TenantDomainService.discoverDomain', () {
    test('returns the verified normalized tenant domain', () async {
      final client = MockClient((request) async {
        expect(request.headers['X-Tenant-Key'], 'tenant-key');
        return http.Response(
          '{"status":200,"data":{"domain":"epos.example.com/"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final domain = await TenantDomainService.discoverDomain(
        ' tenant-key ',
        client: client,
      );

      expect(domain, 'https://epos.example.com');
    });

    test('does not fall back when tenant verification fails', () async {
      final client = MockClient((_) async => http.Response(
            '{"status":404,"message":"Tenant not found"}',
            404,
          ));

      expect(
        () => TenantDomainService.discoverDomain(
          'bad-key',
          client: client,
        ),
        throwsA(
          isA<TenantDomainException>().having(
            (error) => error.message,
            'message',
            'Tenant not found',
          ),
        ),
      );
    });

    test('rejects a successful response with no domain', () async {
      final client = MockClient((_) async => http.Response(
            '{"status":200,"data":{}}',
            200,
          ));

      expect(
        () => TenantDomainService.discoverDomain(
          'tenant-key',
          client: client,
        ),
        throwsA(isA<TenantDomainException>()),
      );
    });
  });
}
