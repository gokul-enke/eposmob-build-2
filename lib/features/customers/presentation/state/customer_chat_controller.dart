import 'package:flutter/foundation.dart';

/// One message in a customer conversation.
@immutable
class CustomerChatMessage {
  const CustomerChatMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isFromMe,
  });

  final String id;
  final String text;
  final DateTime sentAt;

  /// True for messages sent by the store, false for the customer's.
  final bool isFromMe;
}

/// Loads the conversation with the customer [customerId].
typedef CustomerChatHistoryLoader = Future<List<CustomerChatMessage>> Function(
  int? customerId,
);

/// State of the customer chat tab: history loading and locally sent
/// messages.
///
/// There is no chat backend yet, so the default loader returns an empty
/// history and sent messages are kept in memory only.
class CustomerChatController extends ChangeNotifier {
  CustomerChatController({
    required this.customerId,
    CustomerChatHistoryLoader? loadHistory,
    DateTime Function()? clock,
  })  : _loadHistory = loadHistory ?? _noHistory,
        _clock = clock ?? DateTime.now;

  final int? customerId;
  final CustomerChatHistoryLoader _loadHistory;
  final DateTime Function() _clock;

  static Future<List<CustomerChatMessage>> _noHistory(int? _) async => const [];

  List<CustomerChatMessage> _messages = const [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _disposed = false;

  List<CustomerChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  /// True when the last [load] failed.
  bool get hasError => _hasError;

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    _notify();
    try {
      _messages = List.of(await _loadHistory(customerId));
    } catch (error) {
      debugPrint('CustomerChatController.load failed: $error');
      _hasError = true;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Appends [text] as a message from the store. Blank text is ignored.
  /// Returns whether a message was added.
  bool send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    _messages = [
      ..._messages,
      CustomerChatMessage(
        id: '${_messages.length + 1}',
        text: trimmed,
        sentAt: _clock(),
        isFromMe: true,
      ),
    ];
    _notify();
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
