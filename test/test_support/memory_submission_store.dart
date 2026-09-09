import 'dart:convert';
import 'package:pos_machine/services/order_submission_coordinator.dart';

class MemorySubmissionStore implements SubmissionStore {
  final Map<String, Map<String, dynamic>> records = {};
  bool failWrites = false;
  bool failRemovals = false;
  @override
  Future<List<Map<String, dynamic>>> readAll() async => records.values
      .map((r) => Map<String, dynamic>.from(jsonDecode(jsonEncode(r)) as Map))
      .toList();
  @override
  Future<void> write(Map<String, dynamic> record) async {
    if (failWrites) throw StateError('disk full');
    records[record['id'] as String] =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(record)) as Map);
  }

  @override
  Future<void> remove(String id) async {
    if (failRemovals) throw StateError('disk failure');
    records.remove(id);
  }
}
