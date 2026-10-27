import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/form/controller_owner.dart';

void main() {
  bool isDisposed(TextEditingController controller) {
    try {
      controller.addListener(() {});
      return false;
    } on FlutterError {
      return true;
    }
  }

  testWidgets(
      'keeps dialog controllers alive through the exit animation, then disposes them',
      (tester) async {
    final controller = TextEditingController(text: 'NO ICE');
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const SizedBox();
      }),
    ));

    final result = showDialog<String>(
      context: pageContext,
      builder: (dialogContext) => ControllerOwner(
        controllers: [controller],
        child: AlertDialog(
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    // The route is popped and the caller has its value, but the dialog is
    // still animating out: its text field must still be able to rebuild.
    expect(await result, 'NO ICE');
    expect(controller.text, 'NO ICE');
    expect(isDisposed(controller), isFalse);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(isDisposed(controller), isTrue);
  });
}
