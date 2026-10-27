import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_models.dart';
import 'ai_sse_parser.dart';

/// Base URL of the CloudPOS AI service (overridable for white-label builds).
const String kAiAssistantBaseUrl = String.fromEnvironment(
  'AI_ASSISTANT_URL',
  defaultValue: 'https://ai.cloudposai.com',
);

/// The POS login the assistant reuses, so users never sign in twice.
class AiAppCredentials {
  const AiAppCredentials({
    required this.tenantKey,
    required this.accessToken,
    this.storeId,
    this.company,
    this.role,
    this.timeZone,
    this.stores = const [],
  });

  final String tenantKey;
  final String accessToken;
  final int? storeId;
  final String? company;
  final String? role;
  final String? timeZone;
  final List<({int id, String name})> stores;

  /// Same login and store means the cached AI session is still valid.
  String get identity => '$tenantKey|$accessToken|${storeId ?? ''}';

  static Future<AiAppCredentials?> fromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantKey = prefs.getString('api_key')?.trim() ?? '';
    final accessToken = prefs.getString('access_token')?.trim() ?? '';
    if (tenantKey.isEmpty || accessToken.isEmpty) return null;
    final stores = <({int id, String name})>[];
    try {
      final raw = jsonDecode(prefs.getString('stores') ?? '[]');
      if (raw is List) {
        for (final s in raw.whereType<Map>()) {
          final id = int.tryParse('${s['store_id'] ?? s['id'] ?? ''}');
          if (id != null)
            stores.add((id: id, name: '${s['store_name'] ?? s['name'] ?? ''}'));
        }
      }
    } on FormatException {
      // Stores are display-only hints; continue without them.
    }
    return AiAppCredentials(
      tenantKey: tenantKey,
      accessToken: accessToken,
      storeId: prefs.getInt('active_store_id'),
      company: prefs.getString('company_name'),
      role: prefs.getString('user_role') ?? prefs.getString('userRole'),
      timeZone: prefs.getString('time_zone'),
      stores: stores,
    );
  }
}

class AiAssistantException implements Exception {
  const AiAssistantException(this.message, {this.signInRequired = false});

  final String message;

  /// The POS login itself is no longer valid.
  final bool signInRequired;

  @override
  String toString() => message;
}

/// HTTP client for ai.cloudposai.com. Holds the AI session token in memory
/// only; it is re-created from the POS login whenever needed.
class AiAssistantApi {
  AiAssistantApi({
    http.Client? client,
    Future<AiAppCredentials?> Function()? credentials,
    String baseUrl = kAiAssistantBaseUrl,
  })  : _client = client ?? http.Client(),
        _credentials = credentials ?? AiAppCredentials.fromPreferences,
        _base = Uri.parse(baseUrl);

  final http.Client _client;
  final Future<AiAppCredentials?> Function() _credentials;
  final Uri _base;

  String? _session;
  String? _sessionFor;

  static const _timeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 90);

  Uri _uri(String path) => _base.replace(path: path);

  Future<String> _sessionToken({bool refresh = false}) async {
    final creds = await _credentials();
    if (creds == null) {
      throw const AiAssistantException(
          'Please sign in to CloudPOS to use the assistant.',
          signInRequired: true);
    }
    if (!refresh && _session != null && _sessionFor == creds.identity)
      return _session!;
    final res = await _client
        .post(
          _uri('/api/session/exchange'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({
            'tenantKey': creds.tenantKey,
            'accessToken': creds.accessToken,
            if (creds.storeId != null) 'storeId': creds.storeId,
            'hints': {
              if (creds.company != null) 'company': creds.company,
              if (creds.role != null) 'role': creds.role,
              if (creds.timeZone != null) 'timeZone': creds.timeZone,
              'stores': [
                for (final s in creds.stores) {'id': s.id, 'name': s.name}
              ],
            },
          }),
        )
        .timeout(_timeout);
    final body = _decode(res.body);
    final token = body['token'];
    if (res.statusCode != 200 || token is! String) {
      throw AiAssistantException(
        '${body['error'] ?? 'The assistant is unavailable right now.'}',
        signInRequired: res.statusCode == 401,
      );
    }
    _session = token;
    _sessionFor = creds.identity;
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  static Map<String, dynamic> _decode(String text) {
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Runs [send]; on an expired AI session, re-exchanges the login once.
  Future<T> _authed<T>(Future<T> Function(String token) send) async {
    try {
      return await send(await _sessionToken());
    } on _SessionExpired {
      return send(await _sessionToken(refresh: true));
    }
  }

  void _check(int status, Map<String, dynamic> body) {
    if (status == 401 && body['code'] == 'session_expired')
      throw const _SessionExpired();
    if (status >= 400) {
      throw AiAssistantException(
          '${body['error'] ?? 'Something went wrong (HTTP $status).'}',
          signInRequired: body['code'] == 'sign_in_required');
    }
  }

  /// Uploads one image or PDF for the next question (multipart "file").
  /// PDFs are read server-side, so this can take a while.
  Future<AiAttachment> upload(
          {required List<int> bytes, required String filename}) =>
      _authed((token) async {
        final request = http.MultipartRequest('POST', _uri('/api/uploads'))
          ..headers.addAll(_headers(token))
          ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename));
        final res = await http.Response.fromStream(
            await _client.send(request).timeout(_uploadTimeout));
        final body = _decode(res.body);
        _check(res.statusCode, body);
        final attachment = AiAttachment.fromJson(body['attachment']);
        if (attachment == null) {
          throw const AiAssistantException('Upload failed. Please try again.');
        }
        return attachment;
      });

  final Map<String, Future<Uint8List>> _files = {};

  /// The bytes of an uploaded file (owner only), e.g. thumbnails of earlier
  /// questions. Kept in memory for the app session; failures are retried.
  Future<Uint8List> attachmentBytes(String id) {
    final cached = _files[id];
    if (cached != null) return cached;
    final load = _authed((token) async {
      final res = await _client
          .get(_uri('/api/uploads/${Uri.encodeComponent(id)}'),
              headers: _headers(token))
          .timeout(_timeout);
      if (res.statusCode != 200) {
        _check(res.statusCode, _decode(res.body));
        throw const AiAssistantException('This file is no longer available.');
      }
      return res.bodyBytes;
    });
    _files[id] = load;
    load.then((_) {}, onError: (Object _) {
      _files.remove(id);
    });
    return load;
  }

  /// Streams the assistant's progress, charts and answer for [message], with
  /// the uploaded [attachments] (ids from [upload]).
  Stream<AiChatEvent> chat(
      {required String message,
      String? conversationId,
      AiPageInfo? page,
      List<String> attachments = const []}) async* {
    final response = await _authed((token) async {
      final request = http.Request('POST', _uri('/api/chat'))
        ..headers.addAll({
          ..._headers(token),
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream'
        })
        ..body = jsonEncode({
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
          if (attachments.isNotEmpty) 'attachments': attachments,
          if (page != null) 'context': page.toJson(),
        });
      final res = await _client.send(request).timeout(_timeout);
      if (res.statusCode != 200) {
        _check(res.statusCode, _decode(await res.stream.bytesToString()));
      }
      return res;
    });
    yield* parseAiEvents(response.stream);
  }

  Future<List<AiConversationSummary>> conversations() => _authed((token) async {
        final res = await _client
            .get(_uri('/api/conversations'), headers: _headers(token))
            .timeout(_timeout);
        final body = _decode(res.body);
        _check(res.statusCode, body);
        return (body['conversations'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AiConversationSummary.fromJson)
            .toList();
      });

  Future<List<AiMessage>> messages(String id) => _authed((token) async {
        final res = await _client
            .get(_uri('/api/conversations/${Uri.encodeComponent(id)}'),
                headers: _headers(token))
            .timeout(_timeout);
        final body = _decode(res.body);
        _check(res.statusCode, body);
        return (body['messages'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AiMessage.fromStored)
            .toList();
      });

  Future<void> deleteConversation(String id) => _authed((token) async {
        final res = await _client
            .delete(_uri('/api/conversations/${Uri.encodeComponent(id)}'),
                headers: _headers(token))
            .timeout(_timeout);
        _check(res.statusCode, _decode(res.body));
      });

  /// Forget the AI session (e.g. after logout).
  void reset() {
    _session = null;
    _sessionFor = null;
    _files.clear();
  }
}

class _SessionExpired implements Exception {
  const _SessionExpired();
}
