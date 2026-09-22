import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// The `pdf` package only shapes Arabic (joins letters into presentation forms
// and reorders them) when a Text widget's resolved direction is RTL. Arabic
// drawn LTR comes out as isolated letters in reversed order. Worse, once one
// document holds both raw and shaped Arabic, the package's TTF subsetter maps
// glyphs shared by a base letter and its isolated form (e.g. U+0644 / U+FEDD)
// to an unrelated glyph, corrupting even correctly-shaped text. Every Text
// that can carry Arabic must therefore go through [pdfText].

final RegExp _arabicRegex = RegExp(
  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

bool pdfHasArabic(String? text) => text != null && _arabicRegex.hasMatch(text);

/// RTL when [text] carries any Arabic, otherwise LTR. Forcing RTL on
/// pure-Latin text would reverse its word order, hence the detection.
pw.TextDirection pdfTextDirectionOf(String? text) =>
    pdfHasArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

/// Drop-in replacement for [pw.Text] that always renders Arabic RTL (so it is
/// shaped), even if the caller asked for LTR. Non-Arabic text keeps the given
/// [textDirection], or inherits the page direction when it is null.
pw.Widget pdfText(
  String text, {
  pw.TextStyle? style,
  pw.TextAlign? textAlign,
  pw.TextDirection? textDirection,
  bool? softWrap,
  bool tightBounds = false,
  double textScaleFactor = 1.0,
  int? maxLines,
  pw.TextOverflow? overflow,
}) {
  final direction = pdfHasArabic(text) ? pw.TextDirection.rtl : textDirection;

  pw.Text build(pw.TextStyle? effectiveStyle) => pw.Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        textDirection: direction,
        softWrap: softWrap,
        tightBounds: tightBounds,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        overflow: overflow,
      );

  final decoration = style?.decoration;
  if (decoration == null || !decoration.contains(pw.TextDecoration.underline)) {
    return build(style);
  }

  // The package measures an underline from the first word's left edge to the
  // last word's right edge. RTL mirrors the words, so that span collapses to
  // the gaps between them ("word_word"). Draw RTL underlines as a bottom
  // border instead; it also clears Arabic descenders.
  return pw.Builder(builder: (context) {
    final resolved = direction ?? pw.Directionality.of(context);
    if (resolved != pw.TextDirection.rtl) return build(style);
    final fontSize = style!.fontSize ?? 12;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: style.decorationColor ?? style.color ?? PdfColors.black,
            width: (style.decorationThickness ?? 1) * fontSize * 0.05,
          ),
        ),
      ),
      child: build(style.copyWith(decoration: pw.TextDecoration.none)),
    );
  });
}
