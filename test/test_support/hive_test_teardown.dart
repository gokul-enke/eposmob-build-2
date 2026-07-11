import 'dart:io';

import 'package:hive/hive.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Drains async Hive box writes kicked off without `await` (e.g.
/// [LocalProductProvider] `_saveProductsToHive` calling `box.clear()`).
/// Call from unit-test `tearDown` so pending I/O finishes before
/// [closeHiveAndDeleteTestDir] runs.
Future<void> awaitPendingHiveBoxWrites() async {
  await LocalProductProvider.flushPendingPersistence();
}

/// Closes Hive and deletes its temp test directory, tolerating the Windows
/// file-lock race where the OS briefly holds a handle on the directory right
/// after `Hive.close()` returns (antivirus/indexer scan). This is test
/// cleanup, not an assertion, so failures here must never fail the suite.
Future<void> closeHiveAndDeleteTestDir(Directory hiveDir) async {
  try {
    await Hive.close().timeout(const Duration(seconds: 3));
  } on Object {
    // Ignore Hive lock issues when other test isolates are still shutting down.
  }

  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
      return;
    } on Object {
      if (attempt == 4) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
