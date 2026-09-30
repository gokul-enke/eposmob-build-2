/// A printable line whose label and business value must not share a bidi run.
/// Plain text remains literal; no separator parsing or hidden Unicode markers.
class ReceiptTextLine {
  const ReceiptTextLine.text(String text)
      : label = '',
        value = text,
        separator = '';

  const ReceiptTextLine.field(this.label, this.value, {this.separator = ': '});

  final String label;
  final String value;
  final String separator;

  bool get hasLabel => label.isNotEmpty;
  String get text => hasLabel ? '$label$separator$value' : value;
}
