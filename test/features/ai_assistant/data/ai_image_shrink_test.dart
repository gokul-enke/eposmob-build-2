import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_machine/features/ai_assistant/data/ai_image_shrink.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';

void main() {
  test('large images become a JPEG of at most 1600 px on the longest edge',
      () async {
    final png = img.encodePng(img.Image(width: 3200, height: 1000)
      ..clear(img.ColorRgb8(20, 120, 220)));
    final out = await shrinkAiImage(png);
    expect(sniffAiAttachment(out), AiAttachmentKind.image);
    expect(out.sublist(0, 3), [0xff, 0xd8, 0xff], reason: 'JPEG');
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 500);
  });

  test('small images keep their size; transparency becomes white', () async {
    final png = img.encodePng(img.Image(width: 40, height: 30, numChannels: 4)
      ..clear(img.ColorRgba8(0, 0, 0, 0)));
    final decoded = img.decodeJpg(await shrinkAiImage(png))!;
    expect(decoded.width, 40);
    expect(decoded.height, 30);
    expect(decoded.getPixel(5, 5).r, greaterThan(240));
  });

  test('bytes that are not an image are refused', () async {
    await expectLater(
        shrinkAiImage(
            img.encodePng(img.Image(width: 1, height: 1)).sublist(0, 10)),
        throwsA(anything));
  });
}
