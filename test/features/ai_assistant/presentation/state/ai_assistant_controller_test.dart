import 'dart:convert';

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
