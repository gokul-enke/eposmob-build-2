import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  Future<void> pumpList(WidgetTester tester, List<String> items) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCardList<String>(
            items: items,
            rowNumberOf: (index) => index + 11,
            emptyState: const Text('Empty'),
            cardBuilder: (item, number) => AppListCard(
              title: item,
              subtitle: '#$number',
              actionLabel: 'Open',
              onAction: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('builds a card per item with its row number', (tester) async {
    await pumpList(tester, ['Ann', 'Bob']);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('#11'), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);
    expect(find.text('Open'), findsNWidgets(2));
  });

  testWidgets('shows the empty state for no items', (tester) async {
    await pumpList(tester, const []);
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('AppListCard action button fires', (tester) async {
    var actions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppListCard(
          title: 'T',
          actionLabel: 'Go',
          actionIcon: Icons.open_in_new,
          onAction: () => actions++,
        ),
      ),
    ));
    await tester.tap(find.text('Go'));
    expect(actions, 1);
  });
}
