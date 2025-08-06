import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/restaurant/table_model.dart';

class TableProvider with ChangeNotifier {
  final List<TableModel> _tables = [];
  bool _isLoading = false;
  String? _error;

  List<TableModel> get tables => List.unmodifiable(_tables);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTables({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with API call when ready
      await Future.delayed(const Duration(milliseconds: 400));
      if (forceRefresh || _tables.isEmpty) {
        _tables
          ..clear()
          ..addAll(_mockTables());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateTableStatus(String tableId, TableStatus status) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx].copyWith(status: status);
      notifyListeners();
    }
  }

  void assignServer(String tableId, String serverId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx].copyWith(assignedServerId: serverId);
      notifyListeners();
    }
  }

  void setCurrentOrder(String tableId, String orderId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx].copyWith(currentOrderId: orderId, status: TableStatus.occupied);
      notifyListeners();
    }
  }

  TableModel? getById(String id) {
    return _tables.firstWhere((e) => e.id == id, orElse: () => _tables.isNotEmpty ? _tables.first : _mockTables().first);
  }

  List<TableModel> _mockTables() {
    return List.generate(12, (i) {
      return TableModel(
        id: 'T${i + 1}',
        name: 'Table ${i + 1}',
        capacity: i % 4 + 2,
        status: i % 3 == 0 ? TableStatus.available : TableStatus.occupied,
        assignedServerId: i % 3 == 0 ? null : 'S${(i % 3) + 1}',
        currentOrderId: i % 3 == 0 ? null : 'O${i + 100}',
        reservationTime: null,
        section: 1,
      );
    });
  }
} 