import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pos_machine/widgets/drawer_list_tile_expandable.dart';

void main() {
  testWidgets('extra sub-items show after the numbered ones when allowed',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DrawerListTileExpandableColumn(
      title: 'Reports',
      icon: FontAwesomeIcons.chartPie,
      selected: true,
      onTap: () {},
      listTitle1: 'Sales Executive Reports',
      onTapTitle1: () => taps.add('1'),
      listTitle8: 'Consumed Stocks Report',
      onTapTitle8: () => taps.add('8'),
      extraItems: [
        DrawerSubItem(title: 'Sales Report', onTap: () => taps.add('sales')),
        DrawerSubItem(
            title: 'Discount Sale Report',
            onTap: () => taps.add('discount'),
            show: false),
      ],
    )))));
    await tester.pumpAndSettle();

    expect(find.text('Consumed Stocks Report'), findsOneWidget);
    expect(find.text('Sales Report'), findsOneWidget);
    expect(find.text('Discount Sale Report'), findsNothing);
    expect(
        tester.getTopLeft(find.text('Sales Report')).dy,
        greaterThan(
            tester.getTopLeft(find.text('Consumed Stocks Report')).dy));

    await tester.tap(find.text('Sales Report'));
    await tester.pumpAndSettle();
    expect(taps, ['sales']);
    final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Sales Report'));
    expect(tile.selected, isTrue);
  });
}
