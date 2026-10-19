import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

void main() {
  const width = 580.0;
  const fontSize = 24.0;

  test('short bilingual names share one line', () {
    final row = BilingualNameRow(arabic: '1. شاي', english: '     Tea');
    expect(row.isSingleLine(width, fontSize), isTrue);
    final stacked = ReceiptTableRow([
          ReceiptTableColumn('1. شاي', weight: 1, align: TextAlign.right)
        ]).calculateHeight(width, fontSize, TextDirection.rtl) *
        2;
    expect(row.calculateHeight(width, fontSize, TextDirection.rtl),
        lessThan(stacked));
  });

  test('long bilingual names fall back to two lines', () {
    final row = BilingualNameRow(
      arabic: 'مشروب الشاي الأخضر بالنعناع الطازج والليمون',
      english: 'Fresh Mint And Lemon Green Tea Beverage Large',
    );
    expect(row.isSingleLine(width, fontSize), isFalse);
    final arabicLine = ReceiptTableRow([
      ReceiptTableColumn(row.arabic, weight: 1, align: TextAlign.right)
    ]).calculateHeight(width, fontSize, TextDirection.rtl);
    final englishLine = ReceiptTableRow([
      ReceiptTableColumn(row.english,
          weight: 1, align: TextAlign.left, textDirection: TextDirection.ltr)
    ]).calculateHeight(width, fontSize, TextDirection.rtl);
    expect(row.calculateHeight(width, fontSize, TextDirection.rtl),
        arabicLine + englishLine);
  });

  test('the split point follows the paper width', () {
    final row = BilingualNameRow(arabic: 'قهوة عربية', english: 'Arabic Coffee');
    expect(row.isSingleLine(580, fontSize), isTrue);
    expect(row.isSingleLine(150, fontSize), isFalse);
  });

  testWidgets('single line paints English left and Arabic right',
      (tester) async {
    await tester.runAsync(() async {
      final image = await ArabicPrinterHelper.renderReceiptToImage(
        rows: [BilingualNameRow(arabic: 'شاي', english: 'Tea')],
        width: width,
        fontSize: fontSize,
      );
      final row = BilingualNameRow(arabic: 'شاي', english: 'Tea');
      expect(image.height,
          row.calculateHeight(width, fontSize, TextDirection.rtl).toInt());
      bool inked(int fromX, int toX) {
        for (var x = fromX; x < toX; x++) {
          for (var y = 0; y < image.height; y++) {
            if (image.getPixel(x, y).r < 128) return true;
          }
        }
        return false;
      }

      expect(inked(0, 100), isTrue, reason: 'English at the left edge');
      expect(inked(width.toInt() - 100, width.toInt()), isTrue,
          reason: 'Arabic at the right edge');
      expect(inked(200, 380), isFalse, reason: 'blank gap between names');
    });
  });
}
