import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  late BuildContext pageContext;

  setUp(() => AppToast.position = AppToastPosition.start);

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    TextDirection direction = TextDirection.ltr,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
  }

  Finder toast() => find.byKey(AppToast.toastKey);

  Color toastColor(WidgetTester tester) => tester
      .widget<Material>(
          find.descendant(of: toast(), matching: find.byType(Material)).first)
      .color!;

  testWidgets('success shows, then disappears after 2 seconds', (tester) async {
    await pumpApp(tester);
    AppToast.success(pageContext, 'Saved');
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(toastColor(tester), AppToastType.success.background);
    expect(find.byIcon(AppToastType.success.icon), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1999));
    expect(AppToast.isShowing, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(AppToast.isShowing, isFalse);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('each type has its own colour, icon and duration',
      (tester) async {
    await pumpApp(tester);
    for (final type in AppToastType.values) {
      AppToast.show(pageContext, type.name, type: type);
      await tester.pump();
      expect(toastColor(tester), type.background);
      expect(find.byIcon(type.icon), findsOneWidget);
      await tester.pump(type.duration - const Duration(milliseconds: 1));
      expect(AppToast.isShowing, isTrue, reason: type.name);
      await tester.pump(const Duration(milliseconds: 1));
      expect(AppToast.isShowing, isFalse, reason: type.name);
    }
    expect(AppToastType.error.duration, const Duration(seconds: 4));
  });

  testWidgets('a new message replaces the current one and its timer',
      (tester) async {
    await pumpApp(tester);
    AppToast.success(pageContext, 'First');
    await tester.pump(const Duration(milliseconds: 1500));
    AppToast.error(pageContext, 'Second');
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    // The first message's timer must not cut the second one short.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(AppToast.isShowing, isFalse);
  });

  testWidgets('close button dismisses at once', (tester) async {
    await pumpApp(tester);
    AppToast.error(pageContext, 'Oops');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(AppToast.isShowing, isFalse);
  });

  // Regression: a toast replaced before its first frame was not built yet, so
  // it was forgotten but never removed, and stayed on screen for good.
  testWidgets('two messages in the same frame leave only the second',
      (tester) async {
    await pumpApp(tester);
    AppToast.success(pageContext, 'Receipt theme saved');
    AppToast.success(pageContext, 'Paper size saved');
    await tester.pump();

    expect(find.text('Receipt theme saved'), findsNothing);
    expect(find.text('Paper size saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(AppToast.toastKey), findsNothing);
  });

  testWidgets('an action runs, dismisses, and stays 5 seconds by default',
      (tester) async {
    await pumpApp(tester);
    var undone = 0;
    AppToast.show(pageContext, 'Removed',
        actionLabel: 'Undo', onAction: () => undone++);
    await tester.pump(const Duration(milliseconds: 4900));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, 1);
    expect(AppToast.isShowing, isFalse);
  });

  testWidgets('null and blank messages are ignored', (tester) async {
    await pumpApp(tester);
    AppToast.success(pageContext, null);
    AppToast.error(pageContext, '   ');
    await tester.pump();
    expect(AppToast.isShowing, isFalse);
  });

  testWidgets('non-string messages are shown as text', (tester) async {
    await pumpApp(tester);
    AppToast.error(pageContext, 404);
    await tester.pump();
    expect(find.text('404'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('stays visible above an open dialog', (tester) async {
    await pumpApp(tester);
    showDialog<void>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        content: Builder(builder: (context) {
          return TextButton(
            onPressed: () => AppToast.success(context, 'From dialog'),
            child: const Text('Save'),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('From dialog').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  group('placement', () {
    testWidgets('phones: full width with 16 px margins', (tester) async {
      await pumpApp(tester, size: const Size(375, 812));
      AppToast.success(pageContext, 'Hi');
      await tester.pump();
      final rect = tester.getRect(toast());
      expect(rect.left, 16);
      expect(rect.right, 375 - 16);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('wide: start, center and end', (tester) async {
      await pumpApp(tester);
      Future<Rect> rectAt(AppToastPosition position) async {
        AppToast.position = position;
        AppToast.success(pageContext, 'Hi');
        await tester.pump();
        return tester.getRect(toast());
      }

      final start = await rectAt(AppToastPosition.start);
      expect(start.left, 16);
      expect(start.width, AppToast.maxWidth);
      final center = await rectAt(AppToastPosition.center);
      expect(center.center.dx, 640);
      final end = await rectAt(AppToastPosition.end);
      expect(end.right, 1280 - 16);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('right-to-left mirrors start to the right edge',
        (tester) async {
      await pumpApp(tester, direction: TextDirection.rtl);
      AppToast.success(pageContext, 'مرحبا');
      await tester.pump();
      expect(tester.getRect(toast()).right, 1280 - 16);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('sits above the on-screen keyboard', (tester) async {
      await pumpApp(tester,
          size: const Size(375, 812),
          viewInsets: const EdgeInsets.only(bottom: 300));
      AppToast.success(pageContext, 'Hi');
      await tester.pump();
      expect(tester.getRect(toast()).bottom, 812 - 300 - 20);
      await tester.pump(const Duration(seconds: 2));
    });

    test('settings strings map to positions', () {
      expect(AppToastPosition.fromSetting('left'), AppToastPosition.start);
      expect(AppToastPosition.fromSetting('center'), AppToastPosition.center);
      expect(AppToastPosition.fromSetting('right'), AppToastPosition.end);
      expect(AppToastPosition.fromSetting('bogus'), AppToastPosition.start);
    });
  });

  group('AppLoadingOverlay', () {
    testWidgets('shows a blocking overlay with a message, then hides',
        (tester) async {
      await pumpApp(tester);
      AppLoadingOverlay.show(pageContext, message: 'Saving...');
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);

      AppLoadingOverlay.show(pageContext, message: 'Still saving...');
      await tester.pump();
      expect(find.text('Saving...'), findsNothing);
      expect(find.byKey(AppLoadingOverlay.overlayKey), findsOneWidget);

      AppLoadingOverlay.hide();
      await tester.pump();
      expect(AppLoadingOverlay.isShowing, isFalse);
      expect(find.text('Still saving...'), findsNothing);
    });

    testWidgets('defaults to the translated "please wait"', (tester) async {
      await pumpApp(tester);
      AppLoadingOverlay.show(pageContext);
      await tester.pump();
      expect(find.text('Please wait...'), findsOneWidget);
      AppLoadingOverlay.hide();
    });
  });
}
