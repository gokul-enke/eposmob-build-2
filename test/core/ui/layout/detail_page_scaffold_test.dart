import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

enum _Tab { one, two, three }

void main() {
  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var selected = _Tab.one;
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DetailPageScaffold<_Tab>(
              title: 'Profile',
              backLabel: 'All items',
              onBack: () => backs++,
              summary: const Text('Summary'),
              tabs: const [
                DetailTab(id: _Tab.one, label: 'First', icon: Icons.looks_one),
                DetailTab(id: _Tab.two, label: 'Second', icon: Icons.looks_two),
                DetailTab(id: _Tab.three, label: 'Third', icon: Icons.looks_3),
              ],
              selectedTab: selected,
              onTabSelected: (tab) => setState(() => selected = tab),
              content: Text('Content ${selected.name}'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('All items'));
    expect(backs, 1);
  }

  testWidgets('wide layout: sidebar tabs switch the content', (tester) async {
    await pumpPage(tester, const Size(1280, 800));

    expect(find.text('Summary'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Content one'), findsOneWidget);

    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(find.text('Content three'), findsOneWidget);
  });

  testWidgets('mobile layout: chip tabs switch the content', (tester) async {
    await pumpPage(tester, const Size(375, 812));

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.text('Content two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
