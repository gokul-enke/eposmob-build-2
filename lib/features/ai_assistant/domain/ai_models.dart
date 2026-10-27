/// Models for the in-app AI assistant (CloudPOS AI on ai.cloudposai.com).
/// Pure Dart: shapes of what the backend streams and stores.
library;

import 'dart:typed_data';

/// One chart, table or docs screenshot the backend added to an answer.
sealed class AiVisual {
  const AiVisual({required this.title});

  final String title;

  static AiVisual? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title']?.toString() ?? '';
    if (raw['kind'] == 'image') {
      // Only https screenshots (from the docs site); anything else is dropped.
      final src = raw['src']?.toString() ?? '';
      if (!src.startsWith('https://')) return null;
      final link = raw['link']?.toString() ?? '';
      return AiDocImage(
        src: src,
        alt: raw['alt']?.toString() ?? '',
        page: raw['page']?.toString() ?? '',
        link: link.startsWith('https://') ? link : null,
      );
    }
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

/// A screenshot from the CloudPOS docs, shown with how-to answers.
class AiDocImage extends AiVisual {
  const AiDocImage(
      {required this.src, required this.alt, required this.page, this.link})
      : super(title: page);

  /// Absolute https URL of the screenshot on the docs site.
  final String src;
  final String alt;

  /// Title of the docs page it comes from.
  final String page;

  /// The docs page itself, when known.
  final String? link;
}

/// Files that can be attached to a question (checked again server-side).
enum AiAttachmentKind { image, pdf }

/// The backend's UPLOAD_LIMITS; images are shrunk before upload.
abstract final class AiUploadLimits {
  static const imagesPerMessage = 4;
  static const pdfsPerMessage = 2;
  static const imageBytes = 4000000;
  static const pdfBytes = 10000000;

  /// Longest edge of an image after shrinking, as the web chat does.
  static const imageEdge = 1600;
}

/// The real file type from its first bytes (JPEG, PNG, WebP or PDF), the
/// same check the backend makes; null for anything else.
AiAttachmentKind? sniffAiAttachment(List<int> bytes) {
  bool at(int i, List<int> values) {
    if (bytes.length < i + values.length) return false;
    for (var j = 0; j < values.length; j++) {
      if (bytes[i + j] != values[j]) return false;
    }
    return true;
  }

  if (at(0, const [0xff, 0xd8, 0xff]) ||
      at(0, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) ||
      (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
          at(8, const [0x57, 0x45, 0x42, 0x50]))) {
    return AiAttachmentKind.image;
  }
  if (at(0, const [0x25, 0x50, 0x44, 0x46, 0x2d])) return AiAttachmentKind.pdf;
  return null;
}

/// An uploaded file as the backend describes it (upload reply and history).
class AiAttachment {
  const AiAttachment({
    required this.id,
    required this.kind,
    required this.name,
    this.size = 0,
    this.pages,
    this.preview,
  });

  final String id;
  final AiAttachmentKind kind;
  final String name;
  final int size;

  /// PDF page count, when the backend could count them.
  final int? pages;

  /// Local image bytes for the thumbnail; null for reloaded history, whose
  /// images load from GET /api/uploads/{id}.
  final Uint8List? preview;

  AiAttachment withPreview(Uint8List? bytes) => AiAttachment(
      id: id, kind: kind, name: name, size: size, pages: pages, preview: bytes);

  static AiAttachment? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    return AiAttachment(
      id: '${raw['id']}',
      kind:
          raw['kind'] == 'pdf' ? AiAttachmentKind.pdf : AiAttachmentKind.image,
      name: '${raw['name'] ?? ''}',
      size: (raw['size'] as num?)?.toInt() ?? 0,
      pages: (raw['pages'] as num?)?.toInt(),
    );
  }
}

enum AiUploadStatus { uploading, ready, failed }

/// A file in the composer, waiting to be sent with the next question.
class AiDraftAttachment {
  AiDraftAttachment({
    required this.key,
    required this.kind,
    required this.name,
    required this.bytes,
    this.preview,
  });

  /// Stable identity while it sits in the composer.
  final int key;
  final AiAttachmentKind kind;
  final String name;

  /// The file as picked or pasted (kept for retry).
  final Uint8List bytes;

  /// Image thumbnail bytes (the shrunk JPEG once it is ready).
  Uint8List? preview;
  AiUploadStatus status = AiUploadStatus.uploading;

  /// Set once uploaded.
  AiAttachment? uploaded;
  String? error;
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
    List<AiAttachment>? attachments,
    this.error,
    this.pending = false,
  })  : visuals = visuals ?? [],
        steps = steps ?? [],
        attachments = attachments ?? [];

  final AiRole role;
  String text;
  final List<AiVisual> visuals;

  /// Images and PDFs sent with a question.
  final List<AiAttachment> attachments;

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
        attachments: (json['attachments'] as List? ?? const [])
            .map(AiAttachment.fromJson)
            .whereType<AiAttachment>()
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
