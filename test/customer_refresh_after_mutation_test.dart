import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/customer_provider.dart';

class _ControlledCustomerProvider extends CustomerProvider {
  final refreshStarted = Completer<String>();
  final allowRefreshToFinish = Completer<void>();

  @override
  Future<void> refreshAfterMutation(String accessToken) async {
    refreshStarted.complete(accessToken);
    await allowRefreshToFinish.future;
  }
}

void main() {
  test('customer refresh is deferred and does not block mutation completion',
      () async {
    final provider = _ControlledCustomerProvider();

    provider.refreshAfterMutationInBackground('  test-token  ');

    expect(provider.refreshStarted.isCompleted, isFalse);
    expect(await provider.refreshStarted.future, 'test-token');

    provider.allowRefreshToFinish.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('customer refresh ignores an empty access token', () async {
    final provider = _ControlledCustomerProvider();

    provider.refreshAfterMutationInBackground('   ');
    await Future<void>.delayed(Duration.zero);

    expect(provider.refreshStarted.isCompleted, isFalse);
  });
}
