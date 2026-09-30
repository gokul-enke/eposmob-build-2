import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/services/print_output_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  test('does not select Open PDF by default', () async {
    expect(
      await PrintOutputSettings.shouldOpenPdfForTarget(
        'default_printer',
        preferences: preferences,
      ),
      isFalse,
    );
  });

  test('keeps target choices independent and preserves explicit false',
      () async {
    await PrintOutputSettings.setOpenPdfForTarget(
      'default_printer',
      selected: true,
      preferences: preferences,
    );
    expect(
      await PrintOutputSettings.shouldOpenPdfForTarget(
        'quotation_printer',
        fallbackPrinterPreferenceKey: 'default_printer',
        preferences: preferences,
      ),
      isTrue,
    );

    await PrintOutputSettings.setOpenPdfForTarget(
      'quotation_printer',
      selected: false,
      preferences: preferences,
    );
    expect(
      await PrintOutputSettings.shouldOpenPdfForTarget(
        'quotation_printer',
        fallbackPrinterPreferenceKey: 'default_printer',
        preferences: preferences,
      ),
      isFalse,
    );
    expect(
      await PrintOutputSettings.shouldOpenPdfForTarget(
        'kot_printer',
        fallbackPrinterPreferenceKey: 'default_printer',
        preferences: preferences,
      ),
      isTrue,
    );
  });

  test('clearing a target restores fallback resolution', () async {
    await PrintOutputSettings.setOpenPdfForTarget(
      'quotation_printer',
      selected: false,
      preferences: preferences,
    );
    await PrintOutputSettings.setOpenPdfForTarget(
      'default_printer',
      selected: true,
      preferences: preferences,
    );
    await PrintOutputSettings.clearForTarget(
      'quotation_printer',
      preferences: preferences,
    );

    expect(
      await PrintOutputSettings.shouldOpenPdfForTarget(
        'quotation_printer',
        fallbackPrinterPreferenceKey: 'default_printer',
        preferences: preferences,
      ),
      isTrue,
    );
  });

  test('recognizes only A4 and A5 as standard PDF paper sizes', () {
    expect(PrintOutputSettings.isStandardPdfPaperSize('A4'), isTrue);
    expect(PrintOutputSettings.isStandardPdfPaperSize('a5'), isTrue);
    expect(PrintOutputSettings.isStandardPdfPaperSize('80mm'), isFalse);
    expect(PrintOutputSettings.isStandardPdfPaperSize(null), isFalse);
  });
}
