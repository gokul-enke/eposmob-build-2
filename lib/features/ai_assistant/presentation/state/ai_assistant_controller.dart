import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/ai_assistant_api.dart';
import '../../domain/ai_models.dart';
import 'ai_page_context.dart';

/// [closed]: only the CloudPOS button in the sidebar shows. [open]: the panel.
enum AiPanelState { closed, open }

/// App-wide state of the assistant. One instance lives for the whole app
/// session, so closing the panel or changing page never loses the chat; an
/// answer keeps streaming while the panel is closed.
class AiAssistantController extends ChangeNotifier {
  AiAssistantController(
      {AiAssistantApi? api, AiPageInfo? Function()? pageContext})
      : _api = api ?? AiAssistantApi(),
        _pageContext = pageContext ?? AiPageContext.instance.current;

  static final AiAssistantController instance = AiAssistantController();

  final AiAssistantApi _api;
  final AiPageInfo? Function() _pageContext;

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

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _busy) return;
    _busy = true;
    _showHistory = false;
    final answer = AiMessage(role: AiRole.assistant, pending: true);
    _messages
      ..add(AiMessage(role: AiRole.user, text: message))
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
