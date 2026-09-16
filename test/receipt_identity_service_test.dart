import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/services/receipt_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(tz.initializeTimeZones);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DateHelper.setTimeZone('Asia/Riyadh');
  });

  test('persists a store-scoped counter configuration and device id', () async {
    final service = ReceiptIdentityService.instance;

    final defaultConfiguration = await service.configurationForStore(2);
    expect(defaultConfiguration.counterNumber, 1);
    expect(defaultConfiguration.isConfigured, isFalse);

    final configured = await service.setCounterNumber(
      storeId: 2,
      counterNumber: 3,
    );
    expect(configured.counterNumber, 3);
    expect(configured.isConfigured, isTrue);
    expect(configured.deviceId, defaultConfiguration.deviceId);

    final otherStore = await service.configurationForStore(9);
    expect(otherStore.counterNumber, 1);
    expect(otherStore.isConfigured, isFalse);
    expect(otherStore.deviceId, configured.deviceId);
  });

  test('issues short sequential receipt references and UUIDv7 identities',
      () async {
    final service = ReceiptIdentityService.instance;
    await service.setCounterNumber(storeId: 2, counterNumber: 3);

    final first = await service.issue(storeId: 2);
    final second = await service.issue(storeId: 2);

    expect(first.receiptNumber, matches(r'^2-03-\d{6}-0001$'));
    expect(second.receiptNumber, matches(r'^2-03-\d{6}-0002$'));
    expect(first.receiptNumber.length, lessThanOrEqualTo(18));
    expect(first.clientSaleId, isNot(second.clientSaleId));
    expect(first.clientSaleId, matches(r'^[0-9a-f-]{36}$'));
    expect(first.deviceId, second.deviceId);
    expect(first.counterNumber, 3);
    expect(DateTime.parse(first.issuedAt).isUtc, isTrue);
  });

  test('keeps stable receipt numbers intact in PDF invoice formatting', () {
    expect(
      ReceiptIdentityService.printableInvoiceNumberComponent(
        '2-03-260916-0001',
      ),
      '2-03-260916-0001',
    );
    expect(
      ReceiptIdentityService.printableInvoiceNumberComponent('CONF-19'),
      '19',
    );
    expect(
      ReceiptIdentityService.printableInvoiceNumberComponent('ORD-004645'),
      '4645',
    );
  });

  test('rejects invalid store and counter identifiers', () async {
    final service = ReceiptIdentityService.instance;
    expect(
      () => service.configurationForStore(0),
      throwsArgumentError,
    );
    expect(
      () => service.setCounterNumber(storeId: 2, counterNumber: 1000),
      throwsArgumentError,
    );
  });
}
