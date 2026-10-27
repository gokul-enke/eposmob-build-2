/// Models for the in-app AI assistant (CloudPOS AI on ai.cloudposai.com).
/// Pure Dart: shapes of what the backend streams and stores.
library;

/// One chart or table the backend computed for an answer.
sealed class AiVisual {
  const AiVisual({required this.title});

  final String title;

  static AiVisual? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title']?.toString() ?? '';
    if (raw['kind'] == 'table') {
      final columns =
          (raw['columns'] as List? ?? const []).map((c) => '$c').toList();
      final rows = (raw['rows'] as List? ?? const [])
          .whereType<List>()
          .map((r) => r.map((c) => c is num ? c : '${c ?? ''}').toList())
          .toList();
      final money = (raw['money'] as List? ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet();
      return AiTable(
          title: title,
          columns: columns,
          rows: rows,
          moneyColumns: money,
          currency: raw['currency']?.toString());
    }
    if (raw['kind'] == 'chart') {
      final labels =
          (raw['labels'] as List? ?? const []).map((l) => '$l').toList();
      final series = raw['series'] is List && (raw['series'] as List).isNotEmpty
          ? (raw['series'] as List).first
          : null;
      final data = (series is Map ? series['data'] as List? : null)
              ?.map((v) => v is num ? v.toDouble() : 0.0)
              .toList() ??
          const <double>[];
      final type = switch (raw['type']) {
        'line' => AiChartType.line,
        'pie' => AiChartType.pie,
        _ => AiChartType.bar
      };
      return AiChart(
        title: title,
        type: type,
        labels: labels,
        values: data,
        isMoney: raw['format'] == 'money',
        currency: raw['currency']?.toString(),
      );
    }
    return null;
  }
}

enum AiChartType { bar, line, pie }

class AiChart extends AiVisual {
  const AiChart({
    required super.title,
    required this.type,
    required this.labels,
    required this.values,
    required this.isMoney,
    this.currency,
  });

  final AiChartType type;
  final List<String> labels;
  final List<double> values;
  final bool isMoney;
  final String? currency;
}

class AiTable extends AiVisual {
  const AiTable({
    required super.title,
    required this.columns,
    required this.rows,
    this.moneyColumns = const {},
    this.currency,
  });

  final List<String> columns;
  final List<List<Object>> rows;
  final Set<int> moneyColumns;
  final String? currency;
}

/// Events streamed by POST /api/chat.
sealed class AiChatEvent {
  const AiChatEvent();

  static AiChatEvent? fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'conversation' => AiConversationEvent(
          id: '${json['id']}', title: '${json['title'] ?? ''}'),
      'status' => AiStatusEvent('${json['text'] ?? ''}'),
      'visual' => switch (AiVisual.fromJson(json['visual'])) {
          final v? => AiVisualEvent(v),
          null => null
        },
      'answer' => AiAnswerEvent('${json['text'] ?? ''}'),
      'error' => AiErrorEvent('${json['text'] ?? ''}'),
      'done' => const AiDoneEvent(),
      _ => null,
    };
  }
}

class AiConversationEvent extends AiChatEvent {
  const AiConversationEvent({required this.id, required this.title});
  final String id;
  final String title;
}

class AiStatusEvent extends AiChatEvent {
  const AiStatusEvent(this.text);
  final String text;
}

class AiVisualEvent extends AiChatEvent {
  const AiVisualEvent(this.visual);
  final AiVisual visual;
}

class AiAnswerEvent extends AiChatEvent {
  const AiAnswerEvent(this.text);
  final String text;
}

class AiErrorEvent extends AiChatEvent {
  const AiErrorEvent(this.text);
  final String text;
}

class AiDoneEvent extends AiChatEvent {
  const AiDoneEvent();
}

enum AiRole { user, assistant }

/// One turn of a conversation as shown in the panel.
class AiMessage {
  AiMessage({
    required this.role,
    this.text = '',
    List<AiVisual>? visuals,
    List<String>? steps,
    this.error,
    this.pending = false,
  })  : visuals = visuals ?? [],
        steps = steps ?? [];

  final AiRole role;
  String text;
  final List<AiVisual> visuals;

  /// Progress labels ("Searching the CloudPOS docs") while it works.
  final List<String> steps;
  String? error;
  bool pending;

  static AiMessage fromStored(Map<String, dynamic> json) => AiMessage(
        role: json['role'] == 'user' ? AiRole.user : AiRole.assistant,
        text: '${json['content'] ?? ''}',
        visuals: (json['visuals'] as List? ?? const [])
            .map(AiVisual.fromJson)
            .whereType<AiVisual>()
            .toList(),
      );
}

class AiConversationSummary {
  const AiConversationSummary(
      {required this.id, required this.title, required this.updatedAt});

  final String id;
  final String title;
  final DateTime updatedAt;

  static AiConversationSummary fromJson(Map<String, dynamic> json) =>
      AiConversationSummary(
        id: '${json['id']}',
        title: '${json['title'] ?? ''}',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['updated_at'] as num?)?.toInt() ?? 0),
      );
}

/// What the user has open, sent with each question.
class AiPageInfo {
  const AiPageInfo({required this.screen, this.details});

  final String screen;
  final String? details;

  Map<String, String> toJson() => {
        'screen': screen,
        if (details != null && details!.isNotEmpty) 'details': details!,
      };
}
