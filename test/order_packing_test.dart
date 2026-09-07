import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_details.dart';

void main() {
  test('uses packing_photo_paths for displayed packing photos', () {
    final packing = OrderDetailsModelDataPacking.fromJson({
      'packing_photo_paths': ['https://example.com/packing-1.jpg'],
    });

    expect(packing.photosForDisplay, ['https://example.com/packing-1.jpg']);
    expect(packing.hasDetails, isTrue);
  });

  test('combines both packing photo fields without duplicates', () {
    final packing = OrderDetailsModelDataPacking.fromJson({
      'packing_photos': [
        'https://example.com/packing-1.jpg',
        'https://example.com/packing-2.jpg',
      ],
      'packing_photo_paths': [
        'https://example.com/packing-2.jpg',
        'https://example.com/packing-3.jpg',
      ],
    });

    expect(packing.photosForDisplay, [
      'https://example.com/packing-1.jpg',
      'https://example.com/packing-2.jpg',
      'https://example.com/packing-3.jpg',
    ]);
  });
}
