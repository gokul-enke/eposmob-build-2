import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/widgets/collapsible_sidebar.dart';
import 'package:pos_machine/widgets/drawer_list_tile_expandable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pageKey = ValueKey('test-page');
const _toggleKey = ValueKey('test-toggle');
const _hoverKey = ValueKey('navigation-sidebar-hover-region');

Widget _app({
  GlobalKey<CollapsibleSidebarState>? sidebarKey,
  SharedPreferenceProvider? preferences,
  VoidCallback? onMenuInit,
  VoidCallback? onNavigation,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CollapsibleSidebar(
        key: sidebarKey,
        preferences: preferences,
        sidebarContent: _TestMenu(
          onInit: onMenuInit,
          onNavigation: onNavigation,
        ),
        child: const _TestPage(key: _pageKey),
      ),
    ),
  );
}

class _TestMenu extends StatefulWidget {
  final VoidCallback? onInit;
  final VoidCallback? onNavigation;

  const _TestMenu({this.onInit, this.onNavigation});

  @override
  State<_TestMenu> createState() => _TestMenuState();
}

class _TestMenuState extends State<_TestMenu> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sidebar = CollapsibleSidebar.of(context)!;
    return Column(
      children: [
        IconButton(
          key: _toggleKey,
          tooltip: sidebar.isPinnedExpanded ? 'Collapse' : 'Expand',
          onPressed: sidebar.toggleSidebar,
          icon: const Icon(Icons.menu),
        ),
        if (sidebar.isExpanded) const Text('Navigation labels'),
        DrawerListTileExpandableColumn(
          title: 'Reports',
          iconPath: 'assets/icons/drawer.svg',
          selected: true,
          listTitle1: 'Sales report',
          onTap: () {},
          onTapTitle1: widget.onNavigation ?? () {},
        ),
      ],
    );
  }
}

class _TestPage extends StatefulWidget {
  const _TestPage({super.key});

  @override
  State<_TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<_TestPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Page count: $count'),
            ElevatedButton(
              onPressed: () => setState(() => count++),
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayedPreferences extends SharedPreferenceProvider {
  final restored = Completer<bool>();
  final writes = <bool>[];
  final saves = <Completer<void>>[];
  bool delaySaves = false;

  @override
  Future<bool> getNavigationSidebarExpanded() => restored.future;

  @override
  Future<void> saveNavigationSidebarExpanded(bool isExpanded) async {
    writes.add(isExpanded);
    if (delaySaves) {
      final save = Completer<void>();
      saves.add(save);
      await save.future;
    }
  }
}

class _UnavailablePreferences extends SharedPreferenceProvider {
  int saves = 0;

  @override
  Future<bool> getNavigationSidebarExpanded() async =>
      throw StateError('Read failed');

  @override
  Future<void> saveNavigationSidebarExpanded(bool isExpanded) async {
    saves++;
    throw StateError('Write failed');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new installation defaults to expanded and stores both choices',
      () async {
    final provider = SharedPreferenceProvider();
    expect(await provider.getNavigationSidebarExpanded(), isTrue);
    await provider.saveNavigationSidebarExpanded(false);
    expect(await SharedPreferenceProvider().getNavigationSidebarExpanded(),
        isFalse);
    await provider.saveNavigationSidebarExpanded(true);
    expect(await SharedPreferenceProvider().getNavigationSidebarExpanded(),
        isTrue);
  });

  testWidgets('restores collapsed state before mounting the page',
      (tester) async {
    final preferences = _DelayedPreferences();
    await tester.pumpWidget(_app(preferences: preferences));
    expect(find.byKey(_pageKey), findsNothing);
    preferences.restored.complete(false);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_pageKey)).left, 60);
    expect(find.text('Navigation labels'), findsNothing);
  });

  testWidgets('explicit choice survives widget recreation in both modes',
      (tester) async {
    var menuMounts = 0;
    await tester.pumpWidget(_app(onMenuInit: () => menuMounts++));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_pageKey)).left, 200);
    await tester.tap(find.text('Increment'));
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.text('Page count: 1'), findsOneWidget);
    expect(menuMounts, 1);
    expect(tester.getRect(find.byKey(_pageKey)).left, 60);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_pageKey)).left, 60);
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_pageKey)).left, 200);
  });

  testWidgets('hover overlays the page and leaves the saved choice collapsed',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceProvider.navigationSidebarExpandedKey: false,
    });
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    var menuMounts = 0;
    var navigationCount = 0;
    await tester.pumpWidget(_app(
      sidebarKey: sidebarKey,
      onMenuInit: () => menuMounts++,
      onNavigation: () => navigationCount++,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Increment'));
    final pageRect = tester.getRect(find.byKey(_pageKey));
    final pageState = tester.state(find.byKey(_pageKey));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(30, 120));
    await tester.pump();
    expect(sidebarKey.currentState!.isExpanded, isTrue);
    expect(sidebarKey.currentState!.isPinnedExpanded, isFalse);
    expect(tester.getRect(find.byKey(_pageKey)), pageRect);

    // Cross into the area outside the rail before the animation finishes.
    await mouse.moveTo(const Offset(180, 120));
    await tester.pump(const Duration(milliseconds: 80));
    expect(sidebarKey.currentState!.isExpanded, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_hoverKey)).width, 200);
    expect(find.text('Sales report'), findsOneWidget);
    await tester.tap(find.text('Sales report'));
    expect(navigationCount, 1);
    expect(tester.getRect(find.byKey(_pageKey)), pageRect);
    expect(tester.state(find.byKey(_pageKey)), same(pageState));
    expect(find.text('Page count: 1'), findsOneWidget);
    expect(menuMounts, 1);
    expect(await SharedPreferenceProvider().getNavigationSidebarExpanded(),
        isFalse);

    await mouse.moveTo(const Offset(400, 120));
    await tester.pump();
    expect(sidebarKey.currentState!.isExpanded, isFalse);
    expect(find.text('Navigation labels'), findsNothing);
    expect(tester.getRect(find.byKey(_pageKey)), pageRect);
    await tester.tap(find.text('Increment'));
    await tester.pumpAndSettle();
    expect(find.text('Page count: 2'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('hover toggle pins open; explicit collapse waits for re-entry',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceProvider.navigationSidebarExpandedKey: false,
    });
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    await tester.pumpWidget(_app(sidebarKey: sidebarKey));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(30, 120));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand'), findsOneWidget);
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isPinnedExpanded, isTrue);
    expect(tester.getRect(find.byKey(_pageKey)).left, 200);
    expect(await SharedPreferenceProvider().getNavigationSidebarExpanded(),
        isTrue);

    await mouse.moveTo(const Offset(30, 120));
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isExpanded, isFalse);
    await mouse.moveTo(const Offset(31, 120));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isExpanded, isFalse);
    await mouse.moveTo(const Offset(500, 500));
    await mouse.moveTo(const Offset(30, 120));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isExpanded, isTrue);
    expect(sidebarKey.currentState!.isPinnedExpanded, isFalse);
    await mouse.removePointer();
  });

  testWidgets('preserves submenu expansion across hover previews',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceProvider.navigationSidebarExpandedKey: false,
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 500));
    await mouse.moveTo(const Offset(30, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Sales report'), findsNothing);
    await mouse.moveTo(const Offset(500, 500));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(30, 120));
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Sales report'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('late restore cannot overwrite an explicit choice',
      (tester) async {
    final preferences = _DelayedPreferences();
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    await tester
        .pumpWidget(_app(sidebarKey: sidebarKey, preferences: preferences));
    final save = sidebarKey.currentState!.toggleSidebar();
    await tester.pump();
    preferences.restored.complete(true);
    await tester.pumpAndSettle();
    await save;
    expect(sidebarKey.currentState!.isPinnedExpanded, isFalse);
    expect(preferences.writes, [false]);
  });

  testWidgets('serializes rapid saves so the final choice wins',
      (tester) async {
    final preferences = _DelayedPreferences()..delaySaves = true;
    preferences.restored.complete(true);
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    await tester
        .pumpWidget(_app(sidebarKey: sidebarKey, preferences: preferences));
    await tester.pumpAndSettle();
    sidebarKey.currentState!.toggleSidebar();
    sidebarKey.currentState!.toggleSidebar();
    final lastSave = sidebarKey.currentState!.toggleSidebar();
    await tester.pumpAndSettle();
    expect(preferences.writes, [false]);
    preferences.saves[0].complete();
    await tester.pump();
    expect(preferences.writes, [false, true]);
    preferences.saves[1].complete();
    await tester.pump();
    expect(preferences.writes, [false, true, false]);
    preferences.saves[2].complete();
    await tester.pumpAndSettle();
    await lastSave;
    expect(sidebarKey.currentState!.isPinnedExpanded, isFalse);
  });

  testWidgets('does not update a disposed widget after restoration',
      (tester) async {
    final preferences = _DelayedPreferences();
    await tester.pumpWidget(_app(preferences: preferences));
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.restored.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preference failures leave controls usable', (tester) async {
    final preferences = _UnavailablePreferences();
    final sidebarKey = GlobalKey<CollapsibleSidebarState>();
    await tester
        .pumpWidget(_app(sidebarKey: sidebarKey, preferences: preferences));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isPinnedExpanded, isTrue);
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(sidebarKey.currentState!.isPinnedExpanded, isTrue);
    expect(preferences.saves, 2);
    expect(tester.takeException(), isNull);
  });
}
