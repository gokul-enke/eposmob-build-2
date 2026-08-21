import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/screens/print/pdf_share_settings.dart';
import 'package:pos_machine/screens/print/widgets/printer_settings_responsive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('defaults shared PDFs to A4 classic', () async {
    final prefs = await preferences({});

    final profile = PdfShareSettings.resolve(prefs, isB2B: false);

    expect(profile.paperSize, 'A4');
    expect(profile.theme, 'classic');
  });

  test('dedicated B2C settings override billing printer settings', () async {
    final prefs = await preferences({
      PdfShareSettings.paperSizeKey: 'A5',
      PdfShareSettings.themeKey: 'simplified_tax_invoice',
      'default_paper_size': 'A4',
      'billing_receipt_theme': 'classic',
    });

    final profile = PdfShareSettings.resolve(prefs, isB2B: false);

    expect(profile.paperSize, 'A5');
    expect(profile.theme, 'simplified_tax_invoice');
  });

  test('B2B falls back to the dedicated B2C sharing profile', () async {
    final prefs = await preferences({
      PdfShareSettings.paperSizeKey: 'A5',
      PdfShareSettings.themeKey: 'boxed_header_tax_invoice',
      'default_paper_size_b2b': 'A4',
      'billing_receipt_theme_b2b': 'classic',
    });

    final profile = PdfShareSettings.resolve(prefs, isB2B: true);

    expect(profile.paperSize, 'A5');
    expect(profile.theme, 'boxed_header_tax_invoice');
  });

  test('legacy thermal paper is ignored and document theme remains usable',
      () async {
    final prefs = await preferences({
      'default_paper_size': '80mm',
      'billing_receipt_theme': 'premium2_bilingual',
    });

    final profile = PdfShareSettings.resolve(
      prefs,
      isB2B: false,
      documentTheme: 'corporate_tax_invoice',
    );

    expect(profile.paperSize, 'A4');
    expect(profile.theme, 'classic');
  });

  test('PDF sharing exposes only the six supported A4/A5 templates', () {
    expect(
      PdfShareSettings.themes.map((theme) => theme['id']),
      orderedEquals(const [
        'classic',
        'simplified_tax_invoice',
        'centered_simplified_tax_invoice',
        'bilingual_centered_tax_invoice',
        'boxed_bilingual_tax_invoice',
        'boxed_header_tax_invoice',
      ]),
    );
    expect(PdfShareSettings.isSupportedTheme('corporate_tax_invoice'), isFalse);
    expect(
        PdfShareSettings.isSupportedTheme('letterhead_tax_invoice'), isFalse);
  });

  testWidgets('printer settings exposes a dedicated PDF Sharing tab',
      (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrinterTabSelector(
            selectedType: 'Billing',
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('PDF Sharing'), findsOneWidget);
    await tester.tap(find.text('PDF Sharing'));
    expect(selected, 'PDF Sharing');
  });
}
