import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';
import 'package:pos_machine/features/ai_assistant/presentation/state/ai_assistant_controller.dart';
import 'package:pos_machine/features/ai_assistant/presentation/widgets/ai_assistant_overlay.dart';

AiAssistantController _controller() {
  final client = MockClient((request) async {
    if (request.url.path == '/api/session/exchange')
      return http.Response('{"token":"s"}', 200);
    return http.Response(
      [
        {
          'type': 'answer',
          'text':
              '**Kiosk mode** lets customers order. See [docs](https://docs.cloudposai.com/docs/pos-app/kiosk).'
        },
        {'type': 'done'},
      ].map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
      200,
    );
  });
  return AiAssistantController(
    api: AiAssistantApi(
      client: client,
      credentials: () async =>
          const AiAppCredentials(tenantKey: 'K', accessToken: 't'),
      baseUrl: 'https://ai.test',
    ),
    pageContext: () => const AiPageInfo(screen: 'Sales order details'),
  );
}

Widget _app(AiAssistantController c, {Size size = const Size(1280, 800)}) =>
    GetMaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Stack(children: [
          const Scaffold(body: Text('Current page')),
          AiAssistantOverlay(controller: c)
        ]),
      ),
    );

void main() {
  testWidgets('nothing shows until the signed-in shell is up', (tester) async {
    final c = _controller();
    await tester.pumpWidget(_app(c));
    expect(find.byKey(const ValueKey('ai-assistant-launcher')), findsNothing);
    c.attachShell();
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-launcher')), findsOneWidget);
  });

  testWidgets(
      'the button opens the panel over the page; closing returns to the button with the chat kept',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _controller()..attachShell();
    await tester.pumpWidget(_app(c));
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ai-assistant-launcher')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsOneWidget);
    expect(find.text('Current page'), findsOneWidget,
        reason: 'the page stays underneath');
    expect(find.byKey(const ValueKey('ai-assistant-page-context')),
        findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ai-assistant-input')),
        'How does kiosk mode work?');
    await tester.tap(find.byKey(const ValueKey('ai-assistant-send')));
    await tester.pumpAndSettle();
    expect(find.text('How does kiosk mode work?'), findsOneWidget);
    expect(find.textContaining('lets customers order', findRichText: true),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-assistant-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsNothing);
    expect(find.byKey(const ValueKey('ai-assistant-launcher')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-assistant-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('How does kiosk mode work?'), findsOneWidget,
        reason: 'chat continues after reopening');
    expect(c.messages, hasLength(2));
  });

  testWidgets('the button can be dragged but never leaves the screen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _controller()..attachShell();
    await tester.pumpWidget(_app(c));
    final launcher = find.byKey(const ValueKey('ai-assistant-launcher'));
    final home = tester.getCenter(launcher);
    await tester.drag(launcher, const Offset(-300, -200));
    await tester.pump();
    final moved = tester.getCenter(launcher);
    // The first few pixels are touch slop before the drag starts.
    expect(home.dx - moved.dx, inInclusiveRange(250, 300));
    expect(home.dy - moved.dy, inInclusiveRange(150, 200));
    await tester.drag(launcher, const Offset(-5000, -5000));
    await tester.pump();
    final corner = tester.getTopLeft(launcher);
    expect(corner.dx, greaterThanOrEqualTo(0));
    expect(corner.dy, greaterThanOrEqualTo(0));
  });

  testWidgets('fills the screen on phones', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _controller()
      ..attachShell()
      ..open();
    await tester.pumpWidget(_app(c, size: const Size(390, 800)));
    await tester.pump();
    final panel =
        tester.getSize(find.byKey(const ValueKey('ai-assistant-panel')));
    expect(panel.width, 390);
  });
}
