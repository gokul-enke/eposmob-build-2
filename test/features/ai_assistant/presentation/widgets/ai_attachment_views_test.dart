import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';
import 'package:pos_machine/features/ai_assistant/presentation/widgets/ai_attachment_views.dart';
import 'package:pos_machine/features/ai_assistant/presentation/widgets/ai_message_view.dart';

final _png = Uint8List.fromList(img.encodePng(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(200, 30, 30))));

Widget _host(Widget child) =>
    GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets(
      'the strip shows image and PDF tiles with progress, retry and remove',
      (tester) async {
    final drafts = [
      AiDraftAttachment(
          key: 1,
          kind: AiAttachmentKind.image,
          name: 'shelf.jpg',
          bytes: _png,
          preview: _png),
      AiDraftAttachment(
          key: 2, kind: AiAttachmentKind.pdf, name: 'menu.pdf', bytes: _png)
        ..status = AiUploadStatus.ready
        ..uploaded = const AiAttachment(
            id: 'p', kind: AiAttachmentKind.pdf, name: 'menu.pdf', pages: 3),
      AiDraftAttachment(
          key: 3, kind: AiAttachmentKind.pdf, name: 'big.pdf', bytes: _png)
        ..status = AiUploadStatus.failed
        ..error = 'Too large',
    ];
    final removed = <int>[];
    final retried = <int>[];
    await tester.pumpWidget(_host(AiAttachmentStrip(
        attachments: drafts, onRemove: removed.add, onRetry: retried.add)));

    expect(find.byKey(const ValueKey('ai-attachment-strip')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('ai-attachment-tile-$i')), findsOneWidget);
    }
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('ai-attachment-tile-0')),
            matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
        reason: 'the image is still uploading');
    expect(find.text('menu.pdf'), findsOneWidget);
    expect(find.text('PDF · 3 pages'), findsOneWidget);
    expect(find.text("Couldn't attach"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-attachment-retry-2')));
    await tester.tap(find.byKey(const ValueKey('ai-attachment-remove-1')));
    expect(retried, [3]);
    expect(removed, [2]);
  });

  testWidgets('a question shows its images and PDFs; images open full screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final message =
        AiMessage(role: AiRole.user, text: 'What is this?', attachments: [
      AiAttachment(
          id: 'i1',
          kind: AiAttachmentKind.image,
          name: 'shot.png',
          preview: _png),
      const AiAttachment(
          id: 'p1', kind: AiAttachmentKind.pdf, name: 'menu.pdf', pages: 2),
      const AiAttachment(
          id: 'i2', kind: AiAttachmentKind.image, name: 'old.png'),
    ]);
    final loads = <String>[];
    await tester.pumpWidget(_host(AiMessageView(
        message: message,
        loadAttachment: (id) async {
          loads.add(id);
          return _png;
        })));
    await tester.pump();

    expect(
        find.byKey(const ValueKey('ai-message-attachment-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ai-message-attachment-1')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ai-message-attachment-2')), findsOneWidget);
    expect(find.text('menu.pdf'), findsOneWidget);
    expect(find.text('What is this?'), findsOneWidget);
    expect(loads, ['i2'], reason: 'only reloaded images are fetched');

    await tester.tap(find.byKey(const ValueKey('ai-message-attachment-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-image-viewer')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-image-viewer-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai-image-viewer')), findsNothing);
  });

  testWidgets('docs screenshots render as cards with caption and page link',
      (tester) async {
    final answer =
        AiMessage(role: AiRole.assistant, text: 'Open Settings.', visuals: [
      const AiDocImage(
          src: 'https://docs.cloudposai.com/img/printer.png',
          alt: 'Printer settings screen',
          page: 'Set up a printer',
          link: 'https://docs.cloudposai.com/docs/printer'),
      const AiTable(title: 'Stock', columns: [
        'Product'
      ], rows: [
        ['Milk']
      ]),
      const AiDocImage(
          src: 'https://docs.cloudposai.com/img/kiosk.png',
          alt: '',
          page: 'Kiosk mode'),
    ]);
    await tester.pumpWidget(_host(AiMessageView(message: answer)));

    expect(find.byKey(const ValueKey('ai-doc-image-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-doc-image-1')), findsOneWidget);
    expect(find.text('Printer settings screen'), findsOneWidget);
    expect(find.text('Kiosk mode'), findsOneWidget,
        reason: 'the page title is the caption when there is no alt text');
    expect(find.text('Open page'), findsOneWidget,
        reason: 'only screenshots with a docs link offer it');
    expect(find.text('Milk'), findsOneWidget, reason: 'tables still render');

    // Test HTTP answers 400, so the image shows its error placeholder.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('Image unavailable'), findsNWidgets(2));
  });
}
