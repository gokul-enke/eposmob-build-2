import 'dart:convert';

import '../domain/ai_models.dart';

/// Turns the backend's `text/event-stream` body into [AiChatEvent]s.
/// Events are `data: {json}` blocks separated by a blank line; chunks can
/// split anywhere, including inside a UTF-8 character.
Stream<AiChatEvent> parseAiEvents(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final chunk in bytes.transform(utf8.decoder)) {
    buffer += chunk.replaceAll('\r\n', '\n');
    var split = buffer.indexOf('\n\n');
    while (split >= 0) {
      final block = buffer.substring(0, split);
      buffer = buffer.substring(split + 2);
      final event = _parseBlock(block);
      if (event != null) yield event;
      split = buffer.indexOf('\n\n');
    }
  }
  final tail = _parseBlock(buffer);
  if (tail != null) yield tail;
}

AiChatEvent? _parseBlock(String block) {
  for (final line in block.split('\n')) {
    if (!line.startsWith('data: ')) continue;
    try {
      final json = jsonDecode(line.substring(6));
      if (json is Map<String, dynamic>) return AiChatEvent.fromJson(json);
    } on FormatException {
      return null;
    }
  }
  return null;
}
