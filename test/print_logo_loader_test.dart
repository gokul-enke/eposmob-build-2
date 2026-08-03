import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_machine/screens/print/logo_loader.dart';

void main() {
  test('creates a PDF image from valid raster bytes', () {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    );

    expect(PrintLogoLoader.decodePdfLogoBytes(bytes), isNotNull);
  });

  test('rejects an HTML response instead of throwing', () {
    final bytes = Uint8List.fromList(
      utf8.encode('<html><body>Not an image</body></html>'),
    );

    expect(
      () => PrintLogoLoader.decodePdfLogoBytes(bytes),
      returnsNormally,
    );
    expect(PrintLogoLoader.decodePdfLogoBytes(bytes), isNull);
  });

  test('rejects truncated image data instead of throwing', () {
    final bytes = Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10]);

    expect(PrintLogoLoader.decodePdfLogoBytes(bytes), isNull);
  });
}
