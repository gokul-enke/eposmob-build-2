import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/order_submission_status.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'test_support/memory_submission_store.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
        'narrow $language recovery stays readable without globally blocking input',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'api_key': 'test'});
      await LocalizationService.updateLocale(Locale(language));
      addTearDown(() => LocalizationService.updateLocale(const Locale('en')));
      final coordinator =
          OrderSubmissionCoordinator(store: MemorySubmissionStore());
      final auth = AuthModel()..login('test', 1);
      final stores = StoreSessionProvider();
      var edits = 0;
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: stores),
          ],
          child: MaterialApp(
              builder: (context, child) => OrderSubmissionStatus(
                  coordinator: coordinator, child: child!),
              home: Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => edits++,
                        child: const Text('Edit cart'))),
              ))));
      await tester.pump();
      final response = Completer<http.Response>();
      final endpoint = Uri.parse(APPUrl.addToOrderUrl);
      final result = coordinator.submit(
          endpoint: endpoint,
          payload: const {
            'items': [
              {'product_id': 15446, 'quantity': 1, 'price': 3}
            ],
            'total': 3,
          },
          headers: const {},
          scope: OrderSubmissionCoordinator.scopeFor(endpoint, 'test', null),
          send: () => response.future);
      await tester.pump();
      await tester.pump();
      expect(coordinator.phase, SubmissionPhase.submitting);
      await tester.tap(find.text('Edit cart'), warnIfMissed: false);
      expect(edits, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(coordinator.phase, SubmissionPhase.slow);
      expect(find.byKey(const ValueKey('submission-notice')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 15));
      await result;
      await tester.pump();
      expect(coordinator.phase, SubmissionPhase.unknown);
      expect(find.byKey(const ValueKey('submission-notice')), findsNothing);
      auth.logout();
      await tester.pump();
      auth.login('test', 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('submission-notice')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Edit cart'));
      expect(edits, 2);
      response.complete(http.Response('{"order_id":77}', 201));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('submission-notice')), findsNothing);
      expect(coordinator.ordersToReview.single['order_id'], '77');
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => Directionality(
              textDirection:
                  language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child!),
          home: OrdersToReviewPage(coordinator: coordinator)));
      await tester.pumpAndSettle();
      expect(find.text(language == 'ar' ? 'تم تأكيد الطلب' : 'Order confirmed'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('View orders'), findsNothing);
      await tester.tap(find.byKey(ValueKey(
          'review-details-${coordinator.ordersToReview.single['id']}')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('#15446'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      final remove = find.byKey(
          ValueKey('review-remove-${coordinator.ordersToReview.single['id']}'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
      expect(coordinator.ordersToReview.length, 1);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-remove-confirm')));
      await tester.pumpAndSettle();
      expect(
          find.text(language == 'ar'
              ? 'لا توجد طلبات تحتاج إلى مراجعة.'
              : 'No orders need review.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      coordinator.dispose();
      auth.dispose();
      stores.dispose();
    });
  }
}
