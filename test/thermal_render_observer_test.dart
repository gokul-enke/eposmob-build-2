import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

class _PaintWitness extends ReceiptRow {
  bool painted = false;

  @override
  double calculateHeight(double width, double fontSize, TextDirection direction) => 20;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection direction) {
    painted = true;
    canvas.drawRect(Rect.fromLTWH(0, y, 10, 10), Paint()..color = Colors.black);
  }
}

void main() {
  testWidgets('thermal observer sees completed painting without replacing pixels', (tester) async {
    final row = _PaintWitness();
    var calls = 0;
    addTearDown(() => ArabicPrinterHelper.debugRenderedRowsObserver = null);
    ArabicPrinterHelper.debugRenderedRowsObserver = (rows, width, size, direction) {
      expect(row.painted, isTrue);
      expect(rows.single, same(row));
      expect(() => rows.clear(), throwsUnsupportedError);
      expect(width, 40);
      expect(direction, TextDirection.ltr);
      calls++;
    };
    await tester.runAsync(() async {
      final image = await ArabicPrinterHelper.renderReceiptToImage(
          rows: [row], width: 40, fontSize: 12, textDirection: TextDirection.ltr);
      expect(calls, 1);
      expect(image.width, 40);
      expect(image.height, 20);
      expect(image.getPixel(5, 5).r, 0);
      expect(image.getPixel(30, 15).r, 255);
    });
  });
}
