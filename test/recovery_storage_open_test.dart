import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/main.dart' as app;
import 'test_support/hive_test_teardown.dart';

class _UnknownRecord {}

class _UnknownAdapter extends TypeAdapter<_UnknownRecord> {
  @override
  final typeId = 190;
  @override
  _UnknownRecord read(BinaryReader reader) => _UnknownRecord();
  @override
  void write(BinaryWriter writer, _UnknownRecord obj) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production recovery opener retains cart identity and pending records',
      () async {
    final dir = await Directory.systemTemp.createTemp('recovery_open_');
    addTearDown(() => closeHiveAndDeleteTestDir(dir));
    Hive.init(dir.path);
    await app.openOrderRecoveryStorage();
    final box = Hive.box('order_submissions');
    await box.put('_active_cart_session', 'existing-cart');
    await box.put('pending', {'id': 'pending', 'state': 'pending'});
    await Hive.close();
    await app.openOrderRecoveryStorage();
    expect(Hive.box('order_submissions').get('_active_cart_session'),
        'existing-cart');
    expect(Hive.box('order_submissions').get('pending')['state'], 'pending');
  });

  test('unreadable recovery data is never silently deleted or recreated',
      () async {
    final dir = await Directory.systemTemp.createTemp('recovery_unreadable_');
    addTearDown(() => closeHiveAndDeleteTestDir(dir));
    Hive.init(dir.path);
    Hive.registerAdapter(_UnknownAdapter());
    final box = await Hive.openBox('order_submissions');
    await box.put('unreadable', _UnknownRecord());
    await box.flush();
    final file = File(box.path!);
    await Hive.close();
    Hive.resetAdapters();
    final before = await file.readAsBytes();
    // Hive 2.2.3 also reports each failed open on its private _openingBoxes
    // completer (hive_impl.dart:118). Observe those duplicate errors explicitly;
    // the production call must still fail through its normal error screen path.
    final done = Completer<void>();
    final duplicateErrors = <Object>[];
    runZonedGuarded(() async {
      try {
        await expectLater(app.openOrderRecoveryStorage(),
            throwsA(isA<app.StartupStepException>()));
        done.complete();
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    }, (error, stack) {
      if (error is HiveError && error.message.contains('unknown typeId')) {
        duplicateErrors.add(error);
      } else if (!done.isCompleted) {
        done.completeError(error, stack);
      } else {
        Zone.current.handleUncaughtError(error, stack);
      }
    });
    await done.future;
    expect(duplicateErrors, isNotEmpty);
    expect(await file.readAsBytes(), before);
    expect(Hive.isBoxOpen('order_submissions'), isFalse);
  });
}
