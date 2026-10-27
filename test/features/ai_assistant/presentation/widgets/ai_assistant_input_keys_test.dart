import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/presentation/state/ai_assistant_controller.dart';
import 'package:pos_machine/features/ai_assistant/presentation/widgets/ai_assistant_overlay.dart';

void main() {
  testWidgets('Backspace and Ctrl+V edit the assistant box', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = AiAssistantController(
      api: AiAssistantApi(
        client: MockClient((_) async => http.Response('', 500)),
        credentials: () async =>
            const AiAppCredentials(tenantKey: 'K', accessToken: 't'),
        baseUrl: 'https://ai.test',
      ),
    )
      ..attachShell()
      ..open();
    // Placed like main.dart: above the Navigator, in the app builder.
    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: TextField(key: ValueKey('page-field'))),
      builder: (context, child) =>
          Stack(children: [child!, AiAssistantOverlay(controller: c)]),
    ));
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('ai-assistant-input'));
    await tester.tap(input);
    await tester.enterText(input, 'hello');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'hell');

    String? clip = 'pasted';
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': clip};
      if (call.method == 'Clipboard.hasStrings') return {'value': true};
      return null;
    });
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'hellpasted');
  });
}
