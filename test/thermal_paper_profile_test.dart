import 'package:flutter_test/flutter_test.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/screens/print/thermal/thermal_paper_profile.dart';

void main() {
  group('ThermalPaperProfile', () {
    test('keeps the real raster widths for every thermal size', () {
      expect(ThermalPaperProfile.fromSelection('58mm').rasterWidthPx, 384);
      expect(ThermalPaperProfile.fromSelection('80mm').rasterWidthPx, 576);
      expect(ThermalPaperProfile.fromSelection('112mm').rasterWidthPx, 832);
    });

    test('112mm is explicitly raster-only and never a native text profile', () {
      final profile = ThermalPaperProfile.fromSelection('112 mm');

      expect(profile.is112mm, isTrue);
      expect(profile.isRasterOnly, isTrue);
      expect(profile.supportsNativeText, isFalse);
      // This is an unavoidable package implementation detail, not the
      // selected receipt width. Bitmap width remains 832 above.
      expect(profile.escPosPaperSize, PaperSize.mm80);
      expect(profile.requireNativeTextSupport, throwsUnsupportedError);
    });

    test('58mm and 80mm remain native-compatible', () {
      for (final selection in const ['58mm', '80mm']) {
        final profile = ThermalPaperProfile.fromSelection(selection);
        expect(profile.supportsNativeText, isTrue);
        expect(profile.isRasterOnly, isFalse);
        expect(() => profile.requireNativeTextSupport(), returnsNormally);
      }
    });

    test('unknown values preserve the existing 80mm fallback', () {
      final profile = ThermalPaperProfile.fromSelection('unexpected');

      expect(profile.id, '80mm');
      expect(profile.rasterWidthPx, 576);
    });
  });
}
