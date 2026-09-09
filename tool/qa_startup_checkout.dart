// Disposable Windows QA entrypoint. Uses the real app/UI and a separate data
// directory. Never used by the release target lib/main.dart.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:pos_machine/main.dart' as app;
import 'package:pos_machine/services/order_submission_coordinator.dart';

class _QaPaths extends PathProviderWindows {
  bool _delayed = false;
  @override
  Future<String> getApplicationSupportPath() async {
    if (!_delayed) {
      _delayed = true;
      await Future<void>.delayed(const Duration(
          seconds: int.fromEnvironment('QA_STARTUP_DELAY_SECONDS')));
    }
    final path = '${Directory.current.path}/.tools/qa-data';
    await Directory(path).create(recursive: true);
    return path;
  }
}

class _QaClient extends http.BaseClient {
  final _client = IOClient(HttpClient());
  String mode = 'normal';
  int orderRequests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' &&
        request.url.path.endsWith('/order/add-to-order')) {
      if (request.url.host != 'eposdemo.yougoit.in') {
        throw StateError(
            'QA order writes are restricted to the disposable demo tenant.');
      }
      orderRequests++;
      final responseMode = mode;
      if (responseMode == 'hold')
        return Completer<http.StreamedResponse>().future;
      if (responseMode == 'reject') {
        return http.StreamedResponse(
            Stream.value(
                '{"status":"failure","message":"QA stock rejection: no order was created."}'
                    .codeUnits),
            422);
      }
      if (responseMode == 'slow')
        await Future<void>.delayed(const Duration(seconds: 7));
      if (responseMode == 'late')
        await Future<void>.delayed(const Duration(seconds: 25));
      return _client.send(request);
    }
    return _client.send(request);
  }

  @override
  void close() {/* http's top-level helpers close this shared zone client. */}
}

void main() {
  if (!kDebugMode) throw StateError('This QA entrypoint is debug-only.');
  final paths = _QaPaths();
  PathProviderPlatform.instance = paths;
  SharedPreferencesStorePlatform.instance = SharedPreferencesWindows()
    ..pathProvider = paths;
  final client = _QaClient();
  http.runWithClient(() {
    app.main();
    registerMarionetteExtension(
        name: 'cloudposQa.checkout',
        callback: (params) async {
          final mode = params['mode'];
          if (mode != null) {
            if (!['normal', 'slow', 'late', 'reject', 'hold'].contains(mode)) {
              return const MarionetteExtensionResult.invalidParams(
                  'Expected normal, slow, late, reject or hold');
            }
            client.mode = mode;
          }
          final coordinator = OrderSubmissionCoordinator.instance;
          return MarionetteExtensionResult.success({
            'mode': client.mode,
            'order_requests': client.orderRequests,
            'phase': coordinator.phase.name,
            'submission_id': coordinator.pending?['id'],
            'order_id': coordinator.pending?['order_id'],
          });
        });
  }, () => client);
}
