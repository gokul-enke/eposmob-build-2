import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses zero margin by default', () async {
    expect(await CommonPrintSettings.loadMarginMm(), 0);
  });

  test('persists and clamps the shared margin', () async {
    await CommonPrintSettings.saveMarginMm(4.5);
    expect(await CommonPrintSettings.loadMarginMm(), 4.5);

    await CommonPrintSettings.saveMarginMm(999);
    expect(
      await CommonPrintSettings.loadMarginMm(),
      CommonPrintSettings.maxMarginMm,
    );
  });

  test('adds the shared value to every PDF edge', () {
    final margins = CommonPrintSettings.addToPdfMargins(
      const pw.EdgeInsets.only(left: 10, right: 11, top: 12, bottom: 13),
      3,
    );
    final extra = 3 * PdfPageFormat.mm;

    expect(margins.left, closeTo(10 + extra, 0.0001));
    expect(margins.right, closeTo(11 + extra, 0.0001));
    expect(margins.top, closeTo(12 + extra, 0.0001));
    expect(margins.bottom, closeTo(13 + extra, 0.0001));
  });
}
