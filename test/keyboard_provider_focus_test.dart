import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyboardProvider', () {
    test('normalizes numeric alias to number', () {
      final keyboardProvider = KeyboardProvider(enablePersistence: false);
      final controller = TextEditingController(text: '1');

      keyboardProvider.show('numeric', controller);
      expect(keyboardProvider.keyboardType, 'number');
      expect(keyboardProvider.showKeyboard, isTrue);
      expect(identical(keyboardProvider.controller, controller), isTrue);

      controller.dispose();
      keyboardProvider.dispose();
    });

    test('treats numberWithOptions as numeric', () {
      expect(
        KeyboardProvider.isNumericKeyboardType(
          const TextInputType.numberWithOptions(decimal: true),
        ),
        isTrue,
      );
      expect(
        KeyboardProvider.isNumericKeyboardType(TextInputType.number),
        isTrue,
      );
      expect(
        KeyboardProvider.isNumericKeyboardType(TextInputType.text),
        isFalse,
      );
    });

    test('show switches controller without requiring hide first', () {
      final keyboardProvider = KeyboardProvider(enablePersistence: false);
      final quantity = TextEditingController(text: '1');
      final price = TextEditingController(text: '5.00');

      keyboardProvider.show('number', quantity);
      expect(identical(keyboardProvider.controller, quantity), isTrue);

      // Simulates the zero-price modal race: quantity briefly focused, then
      // price.requestFocus() must rebind the keyboard to price.
      keyboardProvider.show('number', price, replaceOnFirstInput: true);
      expect(identical(keyboardProvider.controller, price), isTrue);
      expect(keyboardProvider.shouldReplaceOnFirstInput, isTrue);
      expect(keyboardProvider.keyboardType, 'number');

      quantity.dispose();
      price.dispose();
      keyboardProvider.dispose();
    });

    test('hide clears controller binding', () {
      final keyboardProvider = KeyboardProvider(enablePersistence: false);
      final controller = TextEditingController(text: '1');

      keyboardProvider.show('number', controller);
      keyboardProvider.hide();

      expect(keyboardProvider.showKeyboard, isFalse);
      expect(keyboardProvider.controller, isNull);

      controller.dispose();
      keyboardProvider.dispose();
    });
  });

  group('KeyboardProvider focus auto-show', () {
    testWidgets('binds the field that actually has focus, not the first '
        'field in tree order', (tester) async {
      final keyboardProvider = KeyboardProvider(enablePersistence: false)
        ..featureOn();
      final quantity = TextEditingController(text: '1');
      final price = TextEditingController(text: '5.00');
      final priceFocus = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Quantity is first in the tree – the zero-price modal layout.
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: price,
                  focusNode: priceFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      );

      priceFocus.requestFocus();
      await tester.pump(); // apply focus change
      await tester.pump(); // run provider's post-frame focus check

      expect(keyboardProvider.showKeyboard, isTrue);
      expect(identical(keyboardProvider.controller, price), isTrue,
          reason: 'keyboard must be bound to the focused price field');
      expect(keyboardProvider.keyboardType, 'number');

      keyboardProvider.dispose();
      quantity.dispose();
      price.dispose();
      priceFocus.dispose();
    });

    testWidgets('focus on a non-text widget never binds an unrelated field',
        (tester) async {
      final keyboardProvider = KeyboardProvider(enablePersistence: false)
        ..featureOn();
      final search = TextEditingController();
      final listenerFocus = FocusNode();

      // Mirrors the app shell: KeyboardDispatcher's focus node sits above the
      // whole page, with the product search field somewhere below it. When
      // that node regains focus (e.g. after a dialog pops), no keyboard must
      // appear for the search field.
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: listenerFocus,
            child: Scaffold(
              body: TextField(controller: search),
            ),
          ),
        ),
      );

      listenerFocus.requestFocus();
      await tester.pump();
      await tester.pump();

      expect(keyboardProvider.showKeyboard, isFalse,
          reason: 'non-text focus must not auto-open a keyboard');
      expect(keyboardProvider.controller, isNull);

      keyboardProvider.dispose();
      search.dispose();
      listenerFocus.dispose();
    });

    testWidgets('explicit binding survives focus moving to keyboard chrome',
        (tester) async {
      final keyboardProvider = KeyboardProvider(enablePersistence: false)
        ..featureOn();
      final price = TextEditingController(text: '5.00');
      final priceFocus = FocusNode();
      final chromeFocus = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: price,
                  focusNode: priceFocus,
                  keyboardType: TextInputType.number,
                ),
                Focus(focusNode: chromeFocus, child: const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );

      priceFocus.requestFocus();
      await tester.pump();
      await tester.pump();
      keyboardProvider.show('number', price, replaceOnFirstInput: true);

      chromeFocus.requestFocus();
      await tester.pump();
      await tester.pump();

      expect(identical(keyboardProvider.controller, price), isTrue,
          reason: 'binding must persist while tapping keyboard keys');
      expect(keyboardProvider.shouldReplaceOnFirstInput, isTrue);

      keyboardProvider.dispose();
      price.dispose();
      priceFocus.dispose();
      chromeFocus.dispose();
    });
  });
}
