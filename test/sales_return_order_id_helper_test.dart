import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/sales_return_order_id_helper.dart';

void main() {
  group('SalesReturnOrderIdHelper', () {
    test('uses the ID returned by the current item submission', () {
      const completedEarlierReturnId = 583;
      const currentPendingReturnId = 584;

      final result =
          SalesReturnOrderIdHelper.forCompletion(currentPendingReturnId);

      expect(result, currentPendingReturnId);
      expect(result, isNot(completedEarlierReturnId));
    });

    test('does not fall back to an older item-level return ID', () {
      const int? noReturnSubmittedInThisSession = null;

      final result = SalesReturnOrderIdHelper.forCompletion(
        noReturnSubmittedInThisSession,
      );

      expect(result, isNull);
    });
  });
}
