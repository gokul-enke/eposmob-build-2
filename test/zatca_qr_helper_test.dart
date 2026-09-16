import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  setUp(() {
    DateHelper.setTimeZone('Asia/Riyadh');
  });

  test('encodes an unzoned API order date as a Riyadh invoice instant', () {
    final helper = ZatcaQrHelper();
    final encoded = helper.generateQrForInvoice(
      sellerName: 'FUNZCART',
      vatNumber: '312237662400003',
      invoiceDate: '2026-09-16 07:14:00',
      totalAmount: 428,
      vatAmount: 65.2881356,
    );

    final decoded = helper.parseZatcaQrData(encoded);
    expect(decoded['timestamp'], '2026-09-16T04:14:00Z');
    expect(decoded['totalWithVat'], '428.00');
    // Preserve the current offline VAT behavior for now.
    expect(decoded['vatAmount'], '65.29');
  });

  test('preserves an explicitly zoned offline invoice instant', () {
    final helper = ZatcaQrHelper();
    final encoded = helper.generateQrForInvoice(
      sellerName: 'FUNZCART',
      vatNumber: '312237662400003',
      invoiceDate: '2026-09-16T04:14:00.000Z',
      totalAmount: 428,
      vatAmount: 65.2881356,
    );

    final decoded = helper.parseZatcaQrData(encoded);
    expect(decoded['timestamp'], '2026-09-16T04:14:00Z');
  });

  test('prints a UTC offline timestamp in the configured business timezone',
      () {
    expect(
      DateHelper.formatToISODateFromIST('2026-09-16T04:14:00.000Z'),
      '16-09-2026 07:14 AM',
    );
    expect(
      DateHelper.formatToISOTimeOnlyFromISO('2026-09-16T04:14:00.000Z'),
      '07:14 AM',
    );
  });
}
