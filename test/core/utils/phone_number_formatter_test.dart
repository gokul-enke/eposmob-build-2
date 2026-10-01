import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/utils/phone_number_formatter.dart';

void main() {
  test('groups digits as 3-3-rest and drops other characters', () {
    expect(PhoneNumberFormatter.format('12'), '12');
    expect(PhoneNumberFormatter.format('1234'), '123-4');
    expect(PhoneNumberFormatter.format('12345678'), '123-456-78');
    expect(PhoneNumberFormatter.format('(123) 456 7890'), '123-456-7890');
  });

  test('formatEditUpdate puts the caret at the end', () {
    final value = const PhoneNumberFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '5551234'),
    );
    expect(value.text, '555-123-4');
    expect(value.selection, const TextSelection.collapsed(offset: 9));
  });
}
