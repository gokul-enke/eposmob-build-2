import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_assistant_api.dart';
import 'package:pos_machine/features/ai_assistant/data/ai_sse_parser.dart';
import 'package:pos_machine/features/ai_assistant/domain/ai_models.dart';

const _creds = AiAppCredentials(
  tenantKey: 'KEY',
  accessToken: 'app-token',
  storeId: 7,
  company: 'Acme',
  stores: [(id: 7, name: 'Main')],
);

String _sse(List<Map<String, Object?>> events) =>
    events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();

void main() {
  group('parseAiEvents', () {
    test(
        'handles events split across chunks, including inside UTF-8 characters',
        () async {
      final body = utf8.encode(_sse([
        {'type': 'status', 'text': 'Thinking'},
        {'type': 'answer', 'text': 'مرحبا **world**'},
        {'type': 'done'},
      ]));
      final chunks = [
        for (var i = 0; i < body.length; i += 7)
          body.sublist(i, i + 7 > body.length ? body.length : i + 7)
      ];
      final events = await parseAiEvents(Stream.fromIterable(chunks)).toList();
      expect(events, hasLength(3));
      expect((events[1] as AiAnswerEvent).text, 'مرحبا **world**');
      expect(events.last, isA<AiDoneEvent>());
    });

    test('parses charts and tables, ignores unknown or broken events',
        () async {
      final events = await parseAiEvents(Stream.value(utf8.encode(
        '${_sse([
              {
                'type': 'visual',
                'visual': {
                  'kind': 'chart',
                  'type': 'bar',
                  'title': 'Top',
                  'labels': ['Tea'],
                  'series': [
                    {
                      'name': 'Revenue',
                      'data': [80]
                    }
                  ],
                  'format': 'money',
                  'currency': 'SAR'
                },
              },
              {
                'type': 'visual',
                'visual': {
                  'kind': 'table',
                  'title': 'Stock',
                  'columns': ['Product', 'Stock'],
                  'rows': [
                    ['Milk', 2]
                  ]
                },
              },
              {'type': 'mystery'},
            ])}data: {not json\n\n',
      ))).toList();
      expect(events, hasLength(2));
      final chart = (events[0] as AiVisualEvent).visual as AiChart;
      expect(chart.values, [80.0]);
      expect(chart.isMoney, isTrue);
      final table = (events[1] as AiVisualEvent).visual as AiTable;
      expect(table.rows.single, ['Milk', 2]);
    });

    test('parses docs screenshots; drops images that are not https', () async {
      final events = await parseAiEvents(Stream.value(utf8.encode(_sse([
        {
          'type': 'visual',
          'visual': {
            'kind': 'image',
            'src': 'https://docs.cloudposai.com/img/printer.png',
            'alt': 'Printer settings',
            'page': 'Set up a printer',
            'link': 'https://docs.cloudposai.com/docs/printer',
          },
        },
        {
          'type': 'visual',
          'visual': {
            'kind': 'image',
            'src': 'http://evil.test/x.png',
            'alt': 'x',
            'page': 'x',
            'link': 'x'
          },
        },
        {
          'type': 'visual',
          'visual': {
            'kind': 'image',
            'src': 'https://docs.cloudposai.com/img/a.png',
            'alt': '',
            'page': 'Kiosk',
            'link': 'javascript:alert(1)'
          },
        },
      ])))).toList();
      expect(events, hasLength(2));
      final shot = (events[0] as AiVisualEvent).visual as AiDocImage;
      expect(shot.src, 'https://docs.cloudposai.com/img/printer.png');
      expect(shot.alt, 'Printer settings');
      expect(shot.page, 'Set up a printer');
      expect(shot.link, 'https://docs.cloudposai.com/docs/printer');
      expect(((events[1] as AiVisualEvent).visual as AiDocImage).link, isNull);
    });

    test('stored messages keep their attachments', () {
      final m = AiMessage.fromStored({
        'role': 'user',
        'content': '',
        'attachments': [
          {'id': 'i1', 'kind': 'image', 'name': 'shot.jpg', 'size': 10},
          {
            'id': 'p1',
            'kind': 'pdf',
            'name': 'menu.pdf',
            'size': 20,
            'pages': 2
          },
        ],
      });
      expect(m.role, AiRole.user);
      expect(m.attachments.map((a) => a.kind),
          [AiAttachmentKind.image, AiAttachmentKind.pdf]);
      expect(m.attachments.last.pages, 2);
      expect(m.attachments.first.preview, isNull);
    });

    test('file types are sniffed from their first bytes', () {
      expect(
          sniffAiAttachment([0xff, 0xd8, 0xff, 0xe0]), AiAttachmentKind.image);
      expect(
          sniffAiAttachment([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
          AiAttachmentKind.image);
      expect(sniffAiAttachment(utf8.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')),
          AiAttachmentKind.image);
      expect(sniffAiAttachment(utf8.encode('%PDF-1.7')), AiAttachmentKind.pdf);
      expect(sniffAiAttachment(utf8.encode('GIF89a')), isNull);
      expect(sniffAiAttachment(const []), isNull);
    });
  });

  group('AiAssistantApi', () {
    test('exchanges the POS login once and sends the page context', () async {
      var exchanges = 0;
      Map<String, dynamic>? chatBody;
      final client = MockClient.streaming((request, bodyStream) async {
        final body = await bodyStream.bytesToString();
        if (request.url.path == '/api/session/exchange') {
          exchanges++;
          final json = jsonDecode(body) as Map<String, dynamic>;
          expect(json['tenantKey'], 'KEY');
          expect(json['accessToken'], 'app-token');
          expect(json['storeId'], 7);
          expect((json['hints'] as Map)['stores'], [
            {'id': 7, 'name': 'Main'}
          ]);
          return http.StreamedResponse(
              Stream.value(utf8.encode('{"token":"ai-session"}')), 200);
        }
        expect(request.headers['Authorization'], 'Bearer ai-session');
        chatBody = jsonDecode(body) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(utf8.encode(_sse([
            {'type': 'conversation', 'id': 'c1', 'title': 'Hi'},
            {'type': 'answer', 'text': 'Hello'},
          ]))),
          200,
        );
      });
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      final events = await api
          .chat(
              message: 'Hi',
              page: const AiPageInfo(
                  screen: 'Sales order details', details: 'Order 1'))
          .toList();
      await api.chat(message: 'Again', conversationId: 'c1').toList();
      expect(exchanges, 1);
      expect(events.whereType<AiAnswerEvent>().single.text, 'Hello');
      expect(chatBody!['conversationId'], 'c1');
      expect(chatBody!.containsKey('context'), isFalse);
    });

    test('re-exchanges once when the AI session expired', () async {
      var exchanges = 0;
      var chats = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session/exchange') {
          exchanges++;
          return http.Response('{"token":"s$exchanges"}', 200);
        }
        chats++;
        if (request.headers['Authorization'] == 'Bearer s1') {
          return http.Response(
              '{"error":"expired","code":"session_expired"}', 401);
        }
        return http.Response(
            '{"conversations":[{"id":"a","title":"T","updated_at":0}]}', 200);
      });
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      final list = await api.conversations();
      expect(list.single.title, 'T');
      expect(exchanges, 2);
      expect(chats, 2);
    });

    test('uploads a file as multipart "file" and returns the attachment',
        () async {
      http.BaseRequest? upload;
      List<int>? uploadBody;
      final client = MockClient.streaming((request, bodyStream) async {
        final body = await bodyStream.toBytes();
        if (request.url.path == '/api/session/exchange') {
          return http.StreamedResponse(
              Stream.value(utf8.encode('{"token":"ai-session"}')), 200);
        }
        upload = request;
        uploadBody = body;
        return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'attachment': {
                'id': 'a1',
                'kind': 'pdf',
                'name': 'menu.pdf',
                'size': 1234,
                'pages': 3
              }
            }))),
            200);
      });
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      final ref = await api.upload(
          bytes: utf8.encode('%PDF-1.4 test'), filename: 'menu.pdf');
      expect(ref.id, 'a1');
      expect(ref.kind, AiAttachmentKind.pdf);
      expect(ref.pages, 3);
      expect(upload!.method, 'POST');
      expect(upload!.url.path, '/api/uploads');
      expect(upload!.headers['Authorization'], 'Bearer ai-session');
      expect(upload!.headers['content-type'],
          startsWith('multipart/form-data; boundary='));
      final text = latin1.decode(uploadBody!);
      expect(text, contains('name="file"; filename="menu.pdf"'));
      expect(text, contains('%PDF-1.4 test'));
    });

    test('upload re-exchanges an expired session; sign-in errors are flagged',
        () async {
      var exchanges = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session/exchange') {
          exchanges++;
          return http.Response('{"token":"s$exchanges"}', 200);
        }
        if (request.headers['Authorization'] == 'Bearer s1') {
          return http.Response(
              '{"error":"expired","code":"session_expired"}', 401);
        }
        return http.Response(
            '{"error":"Please sign in to attach files.","code":"sign_in_required"}',
            401);
      });
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      await expectLater(
        api.upload(bytes: const [0xff, 0xd8, 0xff], filename: 'a.jpg'),
        throwsA(isA<AiAssistantException>()
            .having((e) => e.signInRequired, 'signInRequired', isTrue)
            .having((e) => e.message, 'message', contains('sign in'))),
      );
      expect(exchanges, 2);
    });

    test('surfaces upload limits from the server', () async {
      final client = MockClient((request) async => request.url.path ==
              '/api/session/exchange'
          ? http.Response('{"token":"s"}', 200)
          : http.Response(
              '{"error":"That image is too large. The limit is 4 MB."}', 413));
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      await expectLater(
        api.upload(bytes: const [1, 2, 3], filename: 'a.jpg'),
        throwsA(isA<AiAssistantException>()
            .having((e) => e.message, 'message', contains('4 MB'))),
      );
    });

    test('chat sends attachment ids; files read back with the session',
        () async {
      Map<String, dynamic>? chatBody;
      var reads = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/session/exchange') {
          return http.Response('{"token":"s"}', 200);
        }
        if (request.url.path == '/api/uploads/a1') {
          reads++;
          expect(request.headers['Authorization'], 'Bearer s');
          return http.Response.bytes([1, 2, 3], 200);
        }
        chatBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
            _sse([
              {'type': 'done'}
            ]),
            200);
      });
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      await api.chat(message: '', attachments: ['a1', 'a2']).toList();
      expect(chatBody!['attachments'], ['a1', 'a2']);
      expect(chatBody!['message'], '');
      expect(await api.attachmentBytes('a1'), [1, 2, 3]);
      expect(await api.attachmentBytes('a1'), [1, 2, 3]);
      expect(reads, 1, reason: 'read once, then kept in memory');
      await api.chat(message: 'no files').toList();
      expect(chatBody!.containsKey('attachments'), isFalse);
    });

    test('asks to sign in when there is no POS login', () async {
      final api = AiAssistantApi(
        client: MockClient((_) async => http.Response('', 500)),
        credentials: () async => null,
        baseUrl: 'https://ai.test',
      );
      await expectLater(
        api.chat(message: 'hi').toList(),
        throwsA(isA<AiAssistantException>()
            .having((e) => e.signInRequired, 'signInRequired', isTrue)),
      );
    });

    test('surfaces the server message for rate limits', () async {
      final client = MockClient((request) async =>
          request.url.path == '/api/session/exchange'
              ? http.Response('{"token":"s"}', 200)
              : http.Response(
                  '{"error":"Too many messages. Please wait a minute."}', 429));
      final api = AiAssistantApi(
          client: client,
          credentials: () async => _creds,
          baseUrl: 'https://ai.test');
      await expectLater(
        api.chat(message: 'hi').toList(),
        throwsA(isA<AiAssistantException>()
            .having((e) => e.message, 'message', contains('Too many'))),
      );
    });
  });
}
