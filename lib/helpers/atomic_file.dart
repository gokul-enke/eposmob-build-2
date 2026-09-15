import 'dart:io';

/// Writes [bytes] beside [target] and renames over it, so a crash or power cut
/// leaves either the old file or the new one, never half of each.
Future<void> writeFileAtomically(File target, List<int> bytes) async {
  final temp = File('${target.path}.tmp');
  await temp.writeAsBytes(bytes, flush: true);
  await temp.rename(target.path);
}
