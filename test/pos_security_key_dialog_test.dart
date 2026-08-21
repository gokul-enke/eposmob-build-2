import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/presentation/widgets/pos_security_key_dialog.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  _FakeAppSettingsProvider(this.settings);

  final AppSettings settings;

  @override
  AppSettings? get appSettings => settings;

  @override
  Future<void> fetchAppSettings() async {}
}

AppSettings _settings({required bool enabled, String key = ''}) {
  return AppSettings.fromJson({
    'data': [
      {
        'code': 'POS_AUTHENTICATE_CLEARCART',
        'status': enabled,
        'value': key,
      },
    ],
  });
}

Widget _host(AppSettings settings, void Function(Future<bool>) onStarted) {
  return ChangeNotifierProvider<AppSettingsProvider>.value(
    value: _FakeAppSettingsProvider(settings),
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              onStarted(PosSecurityKeyDialog.verify(
                context,
                action: 'clear the cart',
              ));
            },
            child: const Text('Start'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('does not show the modal when the setting is disabled',
      (tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      _host(_settings(enabled: false), (started) => result = started),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Security Key Required'), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('requires the configured four-digit key', (tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      _host(
          _settings(enabled: true, key: '0427'), (started) => result = started),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Security Key Required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey(PosSecurityKeyDialog.inputKey)),
      '0000',
    );
    await tester.tap(
      find.byKey(const ValueKey(PosSecurityKeyDialog.verifyButtonKey)),
    );
    await tester.pump();

    expect(find.text('Incorrect security key.'), findsOneWidget);
    expect(find.text('Security Key Required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey(PosSecurityKeyDialog.inputKey)),
      '0427',
    );
    await tester.tap(
      find.byKey(const ValueKey(PosSecurityKeyDialog.verifyButtonKey)),
    );
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });
}
