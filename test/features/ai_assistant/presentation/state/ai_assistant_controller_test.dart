import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';
import 'package:pos_machine/features/ai_assistant/presentation/state/ai_assistant_controller.dart';
import 'package:pos_machine/features/ai_assistant/presentation/state/ai_page_context.dart';

const _creds = AiAppCredentials(tenantKey: 'KEY', accessToken: 'tok');

String _sse(List<Map<String, Object?>> events) =>
    events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();

/// A backend that answers every chat with [events]; records request bodies.
({AiAssistantController controller, List<Map<String, dynamic>> bodies}) _setup({
  List<Map<String, Object?>>? events,
  AiPageInfo? page,
  int status = 200,
}) {
  final bodies = <Map<String, dynamic>>[];
  final client = MockClient((request) async {
    if (request.url.path == '/api/session/exchange')
      return http.Response('{"token":"s"}', 200);
    if (request.url.path == '/api/chat') {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (status != 200)
        return http.Response('{"error":"Daily limit reached."}', status);
      return http.Response(
          _sse(events ??
              [
                {'type': 'conversation', 'id': 'c1', 'title': 'Q'},
                {'type': 'status', 'text': 'Ranking products'},
                {
                  'type': 'visual',
                  'visual': {
                    'kind': 'chart',
                    'type': 'bar',
                    'title': 'Top',
                    'labels': ['Tea'],
                    'series': [
                      {
                        'data': [5]
                      }
                    ]
                  },
                },
                {'type': 'answer', 'text': 'Tea leads.'},
                {'type': 'done'},
              ]),
          200);
    }
    if (request.url.path == '/api/conversations/c9') {
      return http.Response(
          '{"messages":[{"role":"user","content":"old q"},{"role":"assistant","content":"old a","visuals":[]}]}',
          200);
    }
    return http.Response('{}', 404);
  });
  final api = AiAssistantApi(
      client: client,
      credentials: () async => _creds,
      baseUrl: 'https://ai.test');
  return (
    controller: AiAssistantController(api: api, pageContext: () => page),
    bodies: bodies
  );
}

void main() {
  test('a question streams steps, charts and the answer into one message',
      () async {
    final s = _setup(page: const AiPageInfo(screen: 'Products'));
    s.controller.open();
    await s.controller.send('  Top products?  ');
    final msgs = s.controller.messages;
    expect(msgs, hasLength(2));
    expect(msgs[0].text, 'Top products?');
    expect(msgs[1].text, 'Tea leads.');
    expect(msgs[1].steps, ['Ranking products']);
    expect(msgs[1].visuals.single, isA<AiChart>());
    expect(msgs[1].pending, isFalse);
    expect(s.controller.busy, isFalse);
    expect(s.controller.conversationId, 'c1');
    expect(s.bodies.single['context'], {'screen': 'Products'});
  });

  test(
      'follow-ups stay in the same conversation; page context can be turned off',
      () async {
    final s = _setup(page: const AiPageInfo(screen: 'Products'));
    await s.controller.send('one');
    s.controller.setUsePageContext(false);
    await s.controller.send('two');
    expect(s.bodies[1]['conversationId'], 'c1');
    expect(s.bodies[1].containsKey('context'), isFalse);
  });

  test('closing keeps the chat; an answer while closed marks unread', () async {
    final s = _setup();
    s.controller.open();
    s.controller.close();
    await s.controller.send('hi');
    expect(s.controller.hasUnread, isTrue);
    expect(s.controller.state, AiPanelState.closed);
    expect(s.controller.messages, hasLength(2));
    s.controller.open();
    expect(s.controller.hasUnread, isFalse);
    expect(s.controller.messages, hasLength(2));
  });

  test('the button is only available while the signed-in shell is shown', () {
    final s = _setup();
    expect(s.controller.available, isFalse);
    s.controller.attachShell();
    s.controller.open();
    expect(s.controller.available, isTrue);
    s.controller.detachShell();
    expect(s.controller.available, isFalse);
    expect(s.controller.state, AiPanelState.closed,
        reason: 'leaving the app shell closes the panel');
  });

  test('a refused request shows the server message on the answer', () async {
    final s = _setup(status: 429);
    await s.controller.send('hi');
    expect(s.controller.messages.last.error, 'Daily limit reached.');
    expect(s.controller.busy, isFalse);
  });

  test(
      'new chat clears; opening a stored chat restores it; reset forgets everything',
      () async {
    final s = _setup();
    await s.controller.send('hi');
    s.controller.newChat();
    expect(s.controller.messages, isEmpty);
    expect(s.controller.conversationId, isNull);
    await s.controller.openConversation('c9');
    expect(s.controller.messages.map((m) => m.text), ['old q', 'old a']);
    expect(s.controller.conversationId, 'c9');
    s.controller.open();
    s.controller.reset();
    expect(s.controller.messages, isEmpty);
    expect(s.controller.state, AiPanelState.closed);
  });

  group('attachments', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 menu'));

    /// A backend that stores uploads as a1, a2, …; [fail] answers uploads
    /// with that error instead (until cleared).
    ({
      AiAssistantController controller,
      List<Map<String, dynamic>> chats,
      List<String> uploads,
      void Function(String?) setFail,
    }) attachSetup() {
      final chats = <Map<String, dynamic>>[];
      final uploads = <String>[];
      String? fail;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session/exchange') {
          return http.Response('{"token":"s"}', 200);
        }
        if (request.url.path == '/api/uploads') {
          if (fail != null) return http.Response('{"error":"$fail"}', 413);
          final name = RegExp(r'filename="([^"]+)"')
              .firstMatch(latin1.decode(request.bodyBytes))!
              .group(1)!;
          uploads.add(name);
          final kind = name.endsWith('.pdf') ? 'pdf' : 'image';
          return http.Response(
              jsonEncode({
                'attachment': {
                  'id': 'a${uploads.length}',
                  'kind': kind,
                  'name': name,
                  'size': 3,
                  if (kind == 'pdf') 'pages': 2,
                }
              }),
              200);
        }
        chats.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
            _sse([
              {'type': 'answer', 'text': 'Seen.'},
              {'type': 'done'}
            ]),
            200);
      });
      final controller = AiAssistantController(
        api: AiAssistantApi(
            client: client,
            credentials: () async => _creds,
            baseUrl: 'https://ai.test'),
        pageContext: () => null,
        // Shrinking runs on an isolate in the app; here it only tags the bytes.
        shrinkImage: (bytes) async => Uint8List.fromList([...bytes, 9]),
      );
      return (
        controller: controller,
        chats: chats,
        uploads: uploads,
        setFail: (v) => fail = v,
      );
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero)
        .then((_) => Future<void>.delayed(const Duration(milliseconds: 5)));

    test('files upload as soon as they are added; send carries their ids',
        () async {
      final s = attachSetup();
      final c = s.controller;
      c.addFiles([
        (bytes: jpeg, name: 'shelf.png'),
        (bytes: pdf, name: 'menu.pdf'),
      ]);
      expect(c.attachments, hasLength(2));
      expect(c.uploading, isTrue);
      expect(c.canSend(''), isFalse, reason: 'send waits for uploads');
      await settle();
      expect(c.uploading, isFalse);
      expect(c.attachments.map((d) => d.status),
          everyElement(AiUploadStatus.ready));
      expect(s.uploads, unorderedEquals(['shelf.jpg', 'menu.pdf']),
          reason: 'images are re-encoded as JPEG before upload');
      expect(c.attachments.first.preview!.last, 9,
          reason: 'the thumbnail shows the shrunk image');
      expect(c.canSend(''), isTrue, reason: 'files alone can be sent');

      final ids = [for (final d in c.attachments) d.uploaded!.id];
      expect(ids, unorderedEquals(['a1', 'a2']));
      await c.send('', withAttachments: true);
      // Sent in the order they were added, whichever finished uploading first.
      expect(s.chats.single['attachments'], ids);
      expect(s.chats.single['message'], '');
      expect(c.attachments, isEmpty);
      final question = c.messages.first;
      expect(question.attachments.map((a) => a.id), ids);
      expect(question.attachments.map((a) => a.kind),
          [AiAttachmentKind.image, AiAttachmentKind.pdf]);
      expect(question.attachments.first.preview, isNotNull);
      expect(question.attachments.last.pages, 2);
      expect(c.messages.last.text, 'Seen.');
    });

    test('suggestion-style sends leave the attached files in the composer',
        () async {
      final s = attachSetup();
      s.controller.addFiles([(bytes: jpeg, name: 'a.jpg')]);
      await settle();
      await s.controller.send('Explain what I am looking at');
      expect(s.chats.single.containsKey('attachments'), isFalse);
      expect(s.controller.attachments, hasLength(1));
    });

    test('per-message limits and unsupported types are refused with a note',
        () async {
      final s = attachSetup();
      final c = s.controller;
      c.addFiles([
        for (var i = 0; i < 5; i++) (bytes: jpeg, name: 'p$i.jpg'),
        for (var i = 0; i < 3; i++) (bytes: pdf, name: 'd$i.pdf'),
        (bytes: Uint8List.fromList(utf8.encode('GIF89a')), name: 'x.gif'),
      ]);
      expect(c.attachments.where((d) => d.kind == AiAttachmentKind.image),
          hasLength(AiUploadLimits.imagesPerMessage));
      expect(c.attachments.where((d) => d.kind == AiAttachmentKind.pdf),
          hasLength(AiUploadLimits.pdfsPerMessage));
      expect(c.attachNote, contains('up to 4 images'));
      expect(c.attachNote, contains('up to 2 PDFs'));
      expect(c.attachNote, contains('x.gif'));

      final big = Uint8List(AiUploadLimits.pdfBytes + 1)
        ..setAll(0, utf8.encode('%PDF-'));
      c.removeAttachment(c.attachments.last.key);
      c.addFiles([(bytes: big, name: 'huge.pdf')]);
      expect(c.attachNote, contains('huge.pdf is larger than 10 MB'));
      await settle();
    });

    test('a pasted image has no name and is always treated as an image',
        () async {
      final s = attachSetup();
      s.controller.addFiles([
        (bytes: Uint8List.fromList([1, 2, 3]), name: null)
      ]);
      await settle();
      expect(s.controller.attachments.single.kind, AiAttachmentKind.image);
      expect(s.controller.attachments.single.status, AiUploadStatus.ready);
    });

    test('a failed upload shows the server message, can be retried or removed',
        () async {
      final s = attachSetup();
      final c = s.controller;
      s.setFail('That image is too large. The limit is 4 MB.');
      c.addFiles([(bytes: jpeg, name: 'a.jpg')]);
      await settle();
      final draft = c.attachments.single;
      expect(draft.status, AiUploadStatus.failed);
      expect(draft.error, contains('4 MB'));
      expect(c.attachNote, contains('a.jpg'));
      expect(c.canSend(''), isFalse);

      s.setFail(null);
      c.retryAttachment(draft.key);
      expect(c.attachNote, isNull);
      await settle();
      expect(c.attachments.single.status, AiUploadStatus.ready);

      c.removeAttachment(draft.key);
      expect(c.attachments, isEmpty);
      expect(c.canSend(''), isFalse);
    });

    test('unreadable images fail without reaching the server', () async {
      final chats = <String>[];
      final c = AiAssistantController(
        api: AiAssistantApi(
            client: MockClient((r) async {
              chats.add(r.url.path);
              return http.Response('{"token":"s"}', 200);
            }),
            credentials: () async => _creds,
            baseUrl: 'https://ai.test'),
        pageContext: () => null,
        shrinkImage: (_) async => throw const FormatException('bad'),
      );
      c.addFiles([(bytes: jpeg, name: 'a.jpg')]);
      await settle();
      expect(c.attachments.single.status, AiUploadStatus.failed);
      expect(c.attachments.single.error, contains("Couldn't read"));
      expect(chats, isNot(contains('/api/uploads')));
    });

    test('signed out: the upload fails with the sign-in message', () async {
      final c = AiAssistantController(
        api: AiAssistantApi(
            client: MockClient((_) async => http.Response('', 500)),
            credentials: () async => null,
            baseUrl: 'https://ai.test'),
        pageContext: () => null,
        shrinkImage: (b) async => b,
      );
      c.addFiles([(bytes: pdf, name: 'menu.pdf')]);
      await settle();
      expect(c.attachments.single.status, AiUploadStatus.failed);
      expect(c.attachments.single.error, contains('sign in'));
    });

    test('reset clears attached files', () async {
      final s = attachSetup();
      s.controller.addFiles([(bytes: pdf, name: 'menu.pdf')]);
      await settle();
      s.controller.reset();
      expect(s.controller.attachments, isEmpty);
    });
  });

  group('page context', () {
    tearDown(() => AiPageContext.instance.resetForTest());

    test('screen names are readable', () {
      expect(
          humanizeScreenName('/SalesOrderDetailsPage'), 'Sales order details');
      expect(humanizeScreenName('/() => ProductListPage'), 'Product list');
      expect(humanizeScreenName('BillingPageResponsive'), 'Billing');
      expect(humanizeScreenName('/'), isNull);
    });

    testWidgets(
        'a page scope wins over the sidebar section and is removed on dispose',
        (tester) async {
      AiPageContext.instance.sectionLabel = () => 'Dashboard';
      expect(AiPageContext.instance.current()!.screen, 'Dashboard');
      await tester.pumpWidget(const AiPageContextScope(
        screen: 'Sales order details',
        details: 'Order 42',
        child: SizedBox(),
      ));
      final info = AiPageContext.instance.current()!;
      expect(info.screen, 'Sales order details');
      expect(info.details, 'Order 42');
      await tester.pumpWidget(const SizedBox());
      expect(AiPageContext.instance.current()!.screen, 'Dashboard');
    });
  });
}
