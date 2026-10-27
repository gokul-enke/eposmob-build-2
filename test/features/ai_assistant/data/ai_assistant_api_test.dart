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
