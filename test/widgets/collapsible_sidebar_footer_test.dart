import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/widgets/collapsible_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _footer = ValueKey('test-footer');
const _footerSlot = ValueKey('navigation-sidebar-footer');

Future<GlobalKey<CollapsibleSidebarState>> _pump(WidgetTester tester,
    {required bool pinned}) async {
  SharedPreferences.setMockInitialValues({
    SharedPreferenceProvider.navigationSidebarExpandedKey: pinned,
  });
  final key = GlobalKey<CollapsibleSidebarState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CollapsibleSidebar(
        key: key,
        sidebarContent:
            ListView(children: const [ListTile(title: Text('Home'))]),
        footer: const SizedBox(key: _footer, width: 48, height: 48),
        child: const Center(child: Text('Page')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return key;
}

void main() {
  testWidgets('the footer shows at the bottom while the sidebar is pinned open',
      (tester) async {
    await _pump(tester, pinned: true);
    expect(find.byKey(_footer), findsOneWidget);
    final footer = tester.getRect(find.byKey(_footerSlot));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(footer.bottom, screen.bottom, reason: 'pinned to the bottom');
    expect(footer.right, lessThanOrEqualTo(200),
        reason: 'inside the sidebar on the left');
  });

  testWidgets(
      'a collapsed sidebar hides the footer until the mouse reveals the sidebar',
      (tester) async {
    final sidebar = await _pump(tester, pinned: false);
    expect(find.byKey(_footer), findsNothing,
        reason: 'the icon rail never shows it, so no content is covered');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 300));
    await mouse.moveTo(const Offset(30, 300));
    await tester.pumpAndSettle();
    expect(sidebar.currentState!.isExpanded, isTrue);
    expect(find.byKey(_footer), findsOneWidget);

    await mouse.moveTo(const Offset(500, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(_footer), findsNothing);
    await mouse.removePointer();
  });
}
