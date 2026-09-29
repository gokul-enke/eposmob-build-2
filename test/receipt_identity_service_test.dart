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

  test('after a reinstall the operator can resume from the last bill sold',
      () async {
    final service = ReceiptIdentityService.instance;
    await service.setCounterNumber(storeId: 2, counterNumber: 1);
    expect(
      await service.lastIssuedSequenceToday(storeId: 2, counterNumber: 1),
      0,
    );

    await service.raiseLastIssuedSequenceToday(
      storeId: 2,
      counterNumber: 1,
      lastSoldSequence: 10,
    );

    final config = await service.configurationForStore(2);
    expect(await service.nextReceiptNumber(config), matches(r'^2-01-\d{6}-0011$'));
    final next = await service.issue(storeId: 2);
    expect(next.receiptNumber, matches(r'^2-01-\d{6}-0011$'));
    expect(
      await service.lastIssuedSequencesToday(storeId: 2),
      {1: 11},
    );
  });

  test('the last bill sold can never move the sequence backwards', () async {
    final service = ReceiptIdentityService.instance;
    await service.setCounterNumber(storeId: 2, counterNumber: 4);
    await service.issue(storeId: 2);
    await service.issue(storeId: 2);
    await service.issue(storeId: 2);

    expect(
      () => service.raiseLastIssuedSequenceToday(
        storeId: 2,
        counterNumber: 4,
        lastSoldSequence: 2,
      ),
      throwsStateError,
    );
    expect(
      () => service.raiseLastIssuedSequenceToday(
        storeId: 2,
        counterNumber: 4,
        lastSoldSequence: 0,
      ),
      throwsArgumentError,
    );

    // Equal is allowed and changes nothing.
    await service.raiseLastIssuedSequenceToday(
      storeId: 2,
      counterNumber: 4,
      lastSoldSequence: 3,
    );
    final next = await service.issue(storeId: 2);
    expect(next.receiptNumber, matches(r'^2-04-\d{6}-0004$'));
  });

  test('raising one counter does not affect another', () async {
    final service = ReceiptIdentityService.instance;
    await service.raiseLastIssuedSequenceToday(
      storeId: 2,
      counterNumber: 2,
      lastSoldSequence: 50,
    );
    await service.setCounterNumber(storeId: 2, counterNumber: 1);

    final next = await service.issue(storeId: 2);
    expect(next.receiptNumber, matches(r'^2-01-\d{6}-0001$'));
  });
}
