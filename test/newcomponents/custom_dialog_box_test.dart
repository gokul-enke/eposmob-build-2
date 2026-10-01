import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/build_dialog_box.dart' as old_components;
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

/// The two legacy message files are thin wrappers over AppToast /
/// AppLoadingOverlay and must share one message slot and one position.
void main() {
  late BuildContext pageContext;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
  }

  testWidgets('showScaffold and showScaffoldError use AppToast',
      (tester) async {
    await pumpApp(tester);
    showScaffold(context: pageContext, message: 'Saved');
    await tester.pump();
    expect(find.byIcon(AppToastType.success.icon), findsOneWidget);

    showScaffoldError(context: pageContext, message: 'Failed');
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
    expect(find.byIcon(AppToastType.error.icon), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('both legacy files share one message on screen', (tester) async {
    await pumpApp(tester);
    old_components.showScaffold(context: pageContext, message: 'From old');
    await tester.pump();
    showScaffoldError(context: pageContext, message: 'From new');
    await tester.pump();

    expect(find.text('From old'), findsNothing);
    expect(find.text('From new'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a dynamic null message no longer crashes', (tester) async {
    await pumpApp(tester);
    final Map<String, dynamic> response = {'status': 'success'};
    showScaffold(context: pageContext, message: response['message']);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(AppToast.isShowing, isFalse);
  });

  testWidgets('the action button still works', (tester) async {
    await pumpApp(tester);
    var undone = false;
    showScaffold(
      context: pageContext,
      message: 'Removed',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await tester.pump();
    await tester.tap(find.text('Undo'));
    expect(undone, isTrue);
  });

  test('setNotificationPosition from either file sets the one position', () {
    old_components.setNotificationPosition('right');
    expect(AppToast.position, AppToastPosition.end);
    setNotificationPosition('center');
    expect(AppToast.position, AppToastPosition.center);
    setNotificationPosition('left');
  });

  testWidgets('loading overlay helpers delegate', (tester) async {
    await pumpApp(tester);
    old_components.showLoadingOverlay(pageContext, message: 'Wait');
    await tester.pump();
    expect(AppLoadingOverlay.isShowing, isTrue);
    hideLoadingOverlay();
    await tester.pump();
    expect(find.text('Wait'), findsNothing);
  });
}
