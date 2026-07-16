import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_filter_panel.dart';

void main() {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  setUp(() {
    nameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
  });

  tearDown(() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    VoidCallback? onSearch,
    ValueChanged<String?>? onBalanceChanged,
    VoidCallback? onReset,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: CustomerFilterPanel(
              nameController: nameController,
              emailController: emailController,
              phoneController: phoneController,
              selectedBalanceFilter: 'All',
              onSearch: onSearch ?? () {},
              onBalanceChanged: onBalanceChanged ?? (_) {},
              onReset: onReset ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder fieldWithController(TextEditingController controller) {
    return find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller == controller,
    );
  }

  bool fieldHasFocus(
    WidgetTester tester,
    TextEditingController controller,
  ) {
    final editableText = find.descendant(
      of: fieldWithController(controller),
      matching: find.byType(EditableText),
    );
    return tester.widget<EditableText>(editableText).focusNode.hasFocus;
  }

  testWidgets('renders the customer filter controls', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Name'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Phone'), findsWidgets);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('typing in each text field triggers search', (tester) async {
    var searchCount = 0;
    await pumpPanel(tester, onSearch: () => searchCount++);

    await tester.enterText(fieldWithController(nameController), 'Alice');
    await tester.enterText(fieldWithController(emailController), 'a@b.com');
    await tester.enterText(fieldWithController(phoneController), '12345');

    expect(nameController.text, 'Alice');
    expect(emailController.text, 'a@b.com');
    expect(phoneController.text, '12345');
    expect(searchCount, 3);
  });

  testWidgets('changing balance reports the selected filter', (tester) async {
    String? selectedBalance;
    await pumpPanel(
      tester,
      onBalanceChanged: (value) => selectedBalance = value,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Positive (+ve)').last);
    await tester.pumpAndSettle();

    expect(selectedBalance, 'Positive (+ve)');
  });

  testWidgets('Reset calls the reset callback', (tester) async {
    var resetCount = 0;
    await pumpPanel(tester, onReset: () => resetCount++);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(resetCount, 1);
  });

  testWidgets('Tab moves focus from Name to Email to Phone', (tester) async {
    final nameField = fieldWithController(nameController);

    await pumpPanel(tester);
    await tester.tap(nameField);
    await tester.pump();

    expect(fieldHasFocus(tester, nameController), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fieldHasFocus(tester, emailController), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fieldHasFocus(tester, phoneController), isTrue);
  });
}
