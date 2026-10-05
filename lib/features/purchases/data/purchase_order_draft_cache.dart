import 'package:hive/hive.dart';

class PurchaseOrderDraftCache {
  PurchaseOrderDraftCache({Future<Box> Function()? openBox})
      : _openBox = openBox ?? _openDefault;
  static const boxName = 'purchase_order_draft_box';
  final Future<Box> Function() _openBox;
  Box? _box;
  static Future<Box> _openDefault() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);
  Future<void> open() async {
    _box = await _openBox();
  }

  bool get isOpen => _box?.isOpen ?? false;
  dynamic read() => _box?.get('draft');
  Future<void> write(Map<String, dynamic> value) async {
    await _box?.put('draft', value);
  }

  Future<void> clear() async {
    await _box?.delete('draft');
  }
}
