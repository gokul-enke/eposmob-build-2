import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/ai_assistant_api.dart';
import '../../data/ai_image_shrink.dart';
import '../../domain/ai_models.dart';
import 'ai_page_context.dart';

/// [closed]: only the CloudPOS button in the sidebar shows. [open]: the panel.
enum AiPanelState { closed, open }

/// App-wide state of the assistant. One instance lives for the whole app
/// session, so closing the panel or changing page never loses the chat; an
/// answer keeps streaming while the panel is closed.
class AiAssistantController extends ChangeNotifier {
  AiAssistantController({
    AiAssistantApi? api,
    AiPageInfo? Function()? pageContext,
    Future<Uint8List> Function(Uint8List bytes)? shrinkImage,
  })  : _api = api ?? AiAssistantApi(),
        _pageContext = pageContext ?? AiPageContext.instance.current,
        _shrinkImage = shrinkImage ?? shrinkAiImage;

  static final AiAssistantController instance = AiAssistantController();

  final AiAssistantApi _api;
  final AiPageInfo? Function() _pageContext;
  final Future<Uint8List> Function(Uint8List bytes) _shrinkImage;

  final List<AiDraftAttachment> _drafts = [];
  int _nextDraftKey = 1;
  String? _attachNote;

  /// Files waiting in the composer for the next question.
  List<AiDraftAttachment> get attachments => List.unmodifiable(_drafts);

  /// A short note about files that were refused or failed to upload.
  String? get attachNote => _attachNote;

  /// Send waits until every file has finished uploading.
  bool get uploading =>
      _drafts.any((d) => d.status == AiUploadStatus.uploading);

  /// Whether the composer can send [text] with the attached files.
  bool canSend(String text) =>
      !_busy &&
      !uploading &&
      (text.trim().isNotEmpty ||
          _drafts.any((d) => d.status == AiUploadStatus.ready));

  AiPanelState _state = AiPanelState.closed;
  final List<AiMessage> _messages = [];
  String? _conversationId;
  bool _busy = false;
  bool _usePageContext = true;
  bool _showHistory = false;
  bool _historyLoading = false;
  String? _historyError;
  List<AiConversationSummary> _history = const [];
  StreamSubscription<AiChatEvent>? _stream;
  bool _disposed = false;

  AiPanelState get state => _state;
  List<AiMessage> get messages => List.unmodifiable(_messages);
  String? get conversationId => _conversationId;
  bool get busy => _busy;
  bool get showHistory => _showHistory;
  bool get historyLoading => _historyLoading;
  String? get historyError => _historyError;
  List<AiConversationSummary> get history => _history;

  /// Whether questions include the current screen.
  bool get usePageContext => _usePageContext;

  /// The screen that will be sent with the next question.
  AiPageInfo? get currentPage => _pageContext();

  /// True while an unseen answer arrived with the panel closed (button dot).
  bool get hasUnread => _unread;
  bool _unread = false;

  /// Signed-in app screens currently showing; the button only appears then.
  int _shells = 0;
  bool get available => _shells > 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Called by the signed-in shell (MainScreen) after it mounts.
  void attachShell() {
    _shells++;
    _notify();
  }

  /// Called after the signed-in shell goes away (logout, back to login).
  void detachShell() {
    if (_shells > 0) _shells--;
    if (!available) _state = AiPanelState.closed;
    _notify();
  }

  void open() {
    _state = AiPanelState.open;
    _unread = false;
    _notify();
  }

  /// Folds the panel back into the button; the chat stays and reopening
  /// continues it.
  void close() {
    _state = AiPanelState.closed;
    _showHistory = false;
    _notify();
  }

  void toggle() => _state == AiPanelState.open ? close() : open();

  void setUsePageContext(bool value) {
    _usePageContext = value;
    _notify();
  }

  void newChat() {
    if (_busy) return;
    _messages.clear();
    _conversationId = null;
    _showHistory = false;
    _notify();
  }

  /// Adds picked or pasted files to the composer and starts uploading them.
  /// Unsupported files and files over the per-message limits are refused
  /// with a note. A [name] of null means a pasted image.
  void addFiles(List<({Uint8List bytes, String? name})> files) {
    final notes = <String>{};
    for (final file in files) {
      final kind = file.name == null
          ? AiAttachmentKind.image
          : sniffAiAttachment(file.bytes);
      final name = file.name ?? 'ai_assistant.pasted_image'.tr;
      if (kind == null) {
        notes.add('ai_assistant.attach_unsupported'.trParams({'name': name}));
        continue;
      }
      final image = kind == AiAttachmentKind.image;
      final count = _drafts.where((d) => d.kind == kind).length;
      if (count >=
          (image
              ? AiUploadLimits.imagesPerMessage
              : AiUploadLimits.pdfsPerMessage)) {
        notes.add((image
                ? 'ai_assistant.attach_too_many_images'
                : 'ai_assistant.attach_too_many_pdfs')
            .trParams({
          'count':
              '${image ? AiUploadLimits.imagesPerMessage : AiUploadLimits.pdfsPerMessage}'
        }));
        continue;
      }
      if (!image && file.bytes.length > AiUploadLimits.pdfBytes) {
        notes.add('ai_assistant.attach_pdf_too_large'.trParams({'name': name}));
        continue;
      }
      final draft = AiDraftAttachment(
          key: _nextDraftKey++,
          kind: kind,
          name: name,
          bytes: file.bytes,
          preview: image ? file.bytes : null);
      _drafts.add(draft);
      _upload(draft);
    }
    _attachNote = notes.isEmpty ? null : notes.join(' ');
    _notify();
  }

  Future<void> _upload(AiDraftAttachment draft) async {
    draft
      ..status = AiUploadStatus.uploading
      ..error = null;
    _notify();
    try {
      var bytes = draft.bytes;
      var filename = draft.name;
      if (draft.kind == AiAttachmentKind.image) {
        try {
          bytes = await _shrinkImage(draft.bytes);
        } catch (_) {
          throw AiAssistantException('ai_assistant.attach_unreadable'.tr);
        }
        if (bytes.length > AiUploadLimits.imageBytes) {
          throw AiAssistantException('ai_assistant.attach_image_too_large'.tr);
        }
        draft.preview = bytes;
        filename = '${draft.name.replaceFirst(RegExp(r'\.\w+$'), '')}.jpg';
      }
      final uploaded = await _api.upload(bytes: bytes, filename: filename);
      draft
        ..uploaded = uploaded.withPreview(draft.preview)
        ..status = AiUploadStatus.ready;
    } catch (e) {
      draft
        ..status = AiUploadStatus.failed
        ..error = _describe(e);
    }
    if (!_drafts.contains(draft)) return;
    final failed = _drafts.where((d) => d.status == AiUploadStatus.failed);
    if (failed.isNotEmpty) {
      _attachNote = '${failed.last.name}: ${failed.last.error}';
    }
    _notify();
  }

  void retryAttachment(int key) {
    final draft = _drafts.where((d) => d.key == key).firstOrNull;
    if (draft == null || draft.status != AiUploadStatus.failed) return;
    _attachNote = null;
    _upload(draft);
  }

  void removeAttachment(int key) {
    _drafts.removeWhere((d) => d.key == key);
    if (!_drafts.any((d) => d.status == AiUploadStatus.failed)) {
      _attachNote = null;
    }
    _notify();
  }

  void _clearDrafts() {
    _drafts.clear();
    _attachNote = null;
  }

  /// Bytes of a file sent earlier (thumbnails of reloaded chats).
  Future<Uint8List> attachmentBytes(String id) => _api.attachmentBytes(id);

  /// Sends [text]; [withAttachments] also sends the composer's uploaded files
  /// (suggestion chips never do). Text may be empty when files are attached.
  Future<void> send(String text, {bool withAttachments = false}) async {
    final message = text.trim();
    if (_busy || (withAttachments && uploading)) return;
    final files = withAttachments
        ? _drafts
            .where((d) => d.status == AiUploadStatus.ready)
            .map((d) => d.uploaded!)
            .toList()
        : const <AiAttachment>[];
    if (message.isEmpty && files.isEmpty) return;
    if (withAttachments) _clearDrafts();
    _busy = true;
    _showHistory = false;
    final answer = AiMessage(role: AiRole.assistant, pending: true);
    _messages
      ..add(AiMessage(role: AiRole.user, text: message, attachments: files))
      ..add(answer);
    _notify();

    final done = Completer<void>();
    void finish({String? error}) {
      if (done.isCompleted) return;
      if (error != null && answer.text.isEmpty) answer.error = error;
      answer.pending = false;
      _busy = false;
      if (_state != AiPanelState.open) _unread = true;
      _notify();
      done.complete();
    }

    try {
      final events = _api.chat(
        message: message,
        conversationId: _conversationId,
        page: _usePageContext ? _pageContext() : null,
        attachments: [for (final f in files) f.id],
      );
      _stream = events.listen(
        (event) {
          switch (event) {
            case AiConversationEvent(:final id):
              _conversationId = id;
            case AiStatusEvent(:final text):
              if (text.isNotEmpty && !answer.steps.contains(text))
                answer.steps.add(text);
            case AiVisualEvent(:final visual):
              answer.visuals.add(visual);
            case AiAnswerEvent(:final text):
              answer.text = text;
            case AiErrorEvent(:final text):
              answer.error = text;
            case AiDoneEvent():
              break;
          }
          _notify();
        },
        onError: (Object e) => finish(error: _describe(e)),
        onDone: finish,
        cancelOnError: true,
      );
    } catch (e) {
      finish(error: _describe(e));
    }
    await done.future;
    _stream = null;
  }

  static String _describe(Object e) {
    if (e is AiAssistantException) return e.message;
    if (e is TimeoutException)
      return 'The assistant took too long to respond. Please try again.';
    return 'Could not reach the assistant. Check your internet connection and try again.';
  }

  Future<void> toggleHistory() async {
    _showHistory = !_showHistory;
    _notify();
    if (_showHistory) await loadHistory();
  }

  Future<void> loadHistory() async {
    _historyLoading = true;
    _historyError = null;
    _notify();
    try {
      _history = await _api.conversations();
    } catch (e) {
      _historyError = _describe(e);
    } finally {
      _historyLoading = false;
      _notify();
    }
  }

  Future<void> openConversation(String id) async {
    if (_busy) return;
    _historyLoading = true;
    _notify();
    try {
      final stored = await _api.messages(id);
      _messages
        ..clear()
        ..addAll(stored);
      _conversationId = id;
      _showHistory = false;
    } catch (e) {
      _historyError = _describe(e);
    } finally {
      _historyLoading = false;
      _notify();
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _api.deleteConversation(id);
      _history = _history.where((c) => c.id != id).toList();
      if (_conversationId == id) {
        _messages.clear();
        _conversationId = null;
      }
    } catch (e) {
      _historyError = _describe(e);
    }
    _notify();
  }

  /// After logout: forget the session and the chat on screen.
  void reset() {
    _stream?.cancel();
    _stream = null;
    _api.reset();
    _clearDrafts();
    _messages.clear();
    _conversationId = null;
    _history = const [];
    _busy = false;
    _state = AiPanelState.closed;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stream?.cancel();
    super.dispose();
  }
}
