import 'package:flutter/foundation.dart';
import '../../domain/models/purchase_return.dart';

class PurchaseReturnDetailController extends ChangeNotifier {
  PurchaseReturnDetailController({required this.initial, required this.fetch});
  final PurchaseReturnData initial;
  final Future<PurchaseReturnData?> Function(int) fetch;
  PurchaseReturnData? _details;
  bool isLoading = false;
  bool _disposed = false;
  PurchaseReturnData get displayData => _details ?? initial;
  Future<void> loadDetails() async {
    if (_disposed || initial.id == null || isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      final details = await fetch(initial.id!);
      if (!_disposed) _details = details;
    } catch (_) {
      // Preserve the existing dialog's summary fallback on detail failure.
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
