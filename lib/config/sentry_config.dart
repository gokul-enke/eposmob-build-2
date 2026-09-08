import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sentry project `eposmob` in org `enke-consulting-services-llp`.
///
/// Override at build time with `--dart-define=SENTRY_DSN=...`.
/// Force another debug test event with `--dart-define=SENTRY_SEND_TEST=true`.
class SentryConfig {
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://30a44208503ca0836ac3aebc30666c13@o4512049118838784.ingest.us.sentry.io/4512049310334976',
  );

  static const bool _forceSendTest = bool.fromEnvironment('SENTRY_SEND_TEST');
  static const String _testEventSentKey = 'sentry_test_event_sent';

  static Future<void> init() async {
    if (dsn.isEmpty) {
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.environment = kDebugMode ? 'development' : 'production';
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
    });
  }

  static void setAppUrl(String appUrl) {
    Sentry.configureScope((scope) {
      scope.setTag('app_url', appUrl);
    });
  }

  /// Sends one test exception in debug so Issues and the high-priority
  /// email alert can be verified. Production builds never send this.
  static Future<void> sendDebugTestExceptionOnce() async {
    if (!kDebugMode) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool(_testEventSentKey) ?? false;
    if (alreadySent && !_forceSendTest) {
      return;
    }

    try {
      throw StateError('Sentry Flutter test exception from eposmob');
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      await prefs.setBool(_testEventSentKey, true);
      debugPrint('Sentry test exception sent to eposmob');
    }
  }
}
