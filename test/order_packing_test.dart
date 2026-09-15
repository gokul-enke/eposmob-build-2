import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('uses packing_photo_paths for displayed packing photos', () {
    final packing = OrderDetailsModelDataPacking.fromJson({
      'packing_photo_paths': ['https://example.com/packing-1.jpg'],
    });

    expect(packing.photosForDisplay, ['https://example.com/packing-1.jpg']);
    expect(packing.hasDetails, isTrue);
  });

  test('prefers display URLs while retaining stored photo paths', () {
    final packing = OrderDetailsModelDataPacking.fromJson({
      'packing_photos': [
        'https://example.com/packing-1.jpg',
        'https://example.com/packing-2.jpg',
      ],
      'packing_photo_paths': [
        'orders/packing/photos/packing-1.jpg',
        'orders/packing/photos/packing-2.jpg',
      ],
    });

    expect(packing.photosForDisplay, [
      'https://example.com/packing-1.jpg',
      'https://example.com/packing-2.jpg',
    ]);
    expect(packing.packingPhotoPaths, [
      'orders/packing/photos/packing-1.jpg',
      'orders/packing/photos/packing-2.jpg',
    ]);
  });

  test('uses the configured business timezone for packing timestamps', () {
    DateHelper.setTimeZone('Asia/Riyadh');

    expect(
      DateHelper.nowInConfiguredTimeZone().timeZoneOffset,
      const Duration(hours: 3),
    );
    expect(
      DateHelper.formatISODateTimeForInput('2026-09-08T09:00:00Z'),
      '2026-09-08 12:00',
    );
    expect(
      DateHelper.configuredDateTimeToUtcIso('2026-09-08 12:00'),
      '2026-09-08T09:00:00.000Z',
    );
  });
}
