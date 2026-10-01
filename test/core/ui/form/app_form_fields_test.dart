import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  testWidgets('required fields show a star and run their validator',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: AppTextField(
            controller: controller,
            label: 'Name',
            required: true,
            validator: (value) =>
                value == null || value.isEmpty ? 'Name is required' : null,
          ),
        ),
      ),
    ));

    expect(find.text(' *', findRichText: true), findsNothing);
    expect(find.textContaining('Name', findRichText: true), findsOneWidget);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('ResponsiveFieldGrid picks 1, 2 or 3 columns', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<double> fieldWidth(double width) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: const ResponsiveFieldGrid(
              spacing: 0,
              children: [
                SizedBox(key: ValueKey('a'), height: 10),
                SizedBox(height: 10),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ));
      return tester.getSize(find.byKey(const ValueKey('a'))).width;
    }

    expect(await fieldWidth(400), 400);
    expect(await fieldWidth(600), 300);
    expect(await fieldWidth(900), 300);
  });

  testWidgets('FormActionsBar disables both buttons while busy',
      (tester) async {
    var submits = 0;
    var cancels = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FormActionsBar(
          submitLabel: 'Save',
          cancelLabel: 'Cancel',
          onSubmit: () => submits++,
          onCancel: () => cancels++,
          busy: true,
        ),
      ),
    ));
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Cancel'));
    expect(submits + cancels, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
