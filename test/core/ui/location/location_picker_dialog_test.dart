import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/location/location_picker_dialog.dart';
import 'package:pos_machine/core/ui/location/location_picker_footer.dart';

// LocationPickerDialog itself needs geolocator and a platform WebView
// (webview_flutter / webview_windows), which have no test implementation;
// these tests cover the parts that do not.
void main() {
  test('LocationResult round-trips through JSON with defaults', () {
    final json = {
      'formatted_address': '1 Main Rd, Kochi',
      'latitude': 9,
      'longitude': 76.25,
      'place_id': 'abc',
      'landmark': 'Temple',
      'country': 'India',
      'state': 'Kerala',
      'city': 'Kochi',
      'pincode': '682001',
    };

    final result = LocationResult.fromJson(json);

    expect(result.latitude, 9.0);
    expect(result.toJson(), {...json, 'latitude': 9.0});
    expect(LocationResult.fromJson(const {}).formattedAddress, '');
    expect(LocationResult.fromJson(const {}).latitude, 0.0);
  });

  Future<void> pumpFooter(
    WidgetTester tester, {
    String? address,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPickerFooter(
            address: address,
            emptyLabel: 'Nothing picked',
            cancelLabel: 'Cancel',
            confirmLabel: 'Confirm',
            onCancel: onCancel ?? () {},
            onConfirm: onConfirm,
          ),
        ),
      ),
    );
  }

  testWidgets('footer shows the empty label and disables confirm',
      (tester) async {
    await pumpFooter(tester);

    expect(find.text('Nothing picked'), findsOneWidget);
    final confirm = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Confirm'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('footer shows the picked address and confirms', (tester) async {
    var confirmed = 0;
    var cancelled = 0;
    await pumpFooter(
      tester,
      address: '1 Main Rd, Kochi',
      onConfirm: () => confirmed++,
      onCancel: () => cancelled++,
    );

    expect(find.text('1 Main Rd, Kochi'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.tap(find.text('Cancel'));

    expect(confirmed, 1);
    expect(cancelled, 1);
  });
}
