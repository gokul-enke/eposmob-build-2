import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';
import 'package:pos_machine/features/ai_assistant/presentation/state/ai_assistant_controller.dart';
import 'package:pos_machine/features/ai_assistant/presentation/widgets/ai_assistant_launcher.dart';
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
          // The launcher normally sits in the sidebar footer.
          Scaffold(
            body: Stack(children: [
              const Text('Current page'),
              Align(
                alignment: Alignment.bottomLeft,
                child: AiAssistantLauncher(controller: c),
              ),
            ]),
          ),
          AiAssistantOverlay(controller: c)
        ]),
      ),
    );

void main() {
  testWidgets('the panel only shows inside the signed-in app', (tester) async {
    final c = _controller()..open();
    await tester.pumpWidget(_app(c));
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsNothing);
    c.attachShell();
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsOneWidget);
    c.detachShell();
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-panel')), findsNothing);
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

  testWidgets('an answer that arrives while closed puts a dot on the button',
      (tester) async {
    final c = _controller()..attachShell();
    await tester.pumpWidget(_app(c));
    expect(find.byKey(const ValueKey('ai-assistant-unread')), findsNothing);
    await c.send('How does kiosk mode work?');
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-unread')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-assistant-launcher')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-assistant-unread')), findsNothing);
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
