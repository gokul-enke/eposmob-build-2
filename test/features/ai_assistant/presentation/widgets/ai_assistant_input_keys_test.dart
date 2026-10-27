import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';
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

  testWidgets('Ctrl+V with an image on the clipboard attaches it',
      (tester) async {
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
      pageContext: () => null,
      shrinkImage: (b) async => b,
    )
      ..attachShell()
      ..open();
    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(body: SizedBox()),
      builder: (context, child) =>
          Stack(children: [child!, AiAssistantOverlay(controller: c)]),
    ));
    await tester.pumpAndSettle();

    final png = img.encodePng(img.Image(width: 4, height: 4));
    // On Windows the plugin hands over a temp file path; elsewhere the bytes.
    final tmp = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('ai_paste');
      return File('${dir.path}/clip.png')..writeAsBytesSync(png);
    });
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return null;
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'),
        (call) async {
      if (call.method != 'image') return null;
      return Platform.isWindows ? tmp!.path : Uint8List.fromList(png);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('pasteboard'), null));

    await tester.tap(find.byKey(const ValueKey('ai-assistant-input')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // The plugin reads (and deletes) a temp file: real IO, a step at a time.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(c.attachments, hasLength(1));
    expect(c.attachments.single.kind, AiAttachmentKind.image);
    expect(find.byKey(const ValueKey('ai-attachment-tile-0')), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-assistant-input')))
            .controller!
            .text,
        isEmpty);
  });
}
