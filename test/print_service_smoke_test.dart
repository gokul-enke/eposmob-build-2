import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/services/print_service.dart';

void main() {
  test('print service can be constructed', () {
    expect(const PrintService(), isA<PrintService>());
  });
}
