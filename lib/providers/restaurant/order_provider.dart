import 'package:flutter/foundation.dart';
import '../../models/restaurant/menu_item_model.dart';

class OrderItemSelection {
  final MenuItemModel item;
  final int quantity;
  final Map<String, List<ModifierOption>> selectedModifiers; // groupId -> options
  final String? notes;

  OrderItemSelection({
    required this.item,
    this.quantity = 1,
    Map<String, List<ModifierOption>>? selectedModifiers,
    this.notes,
  }) : selectedModifiers = selectedModifiers ?? {};

  double get totalPrice {
    final base = item.price * quantity;
    double modifiersTotal = 0;
    for (final options in selectedModifiers.values) {
      for (final opt in options) {
        modifiersTotal += opt.additionalPrice * quantity;
      }
    }
    return base + modifiersTotal;
  }

  OrderItemSelection copyWith({
    MenuItemModel? item,
    int? quantity,
    Map<String, List<ModifierOption>>? selectedModifiers,
    String? notes,
  }) {
    return OrderItemSelection(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      notes: notes ?? this.notes,
    );
  }
}

class OrderProvider with ChangeNotifier {
  final Map<String, List<OrderItemSelection>> _ordersByTable = {};
  bool _submitting = false;
  String? _error;

  List<OrderItemSelection> getOrderForTable(String tableId) {
    return List.unmodifiable(_ordersByTable[tableId] ?? []);
  }

  double getOrderTotal(String tableId) {
    return (_ordersByTable[tableId] ?? [])
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void addItem(String tableId, MenuItemModel item,
      {int quantity = 1, Map<String, List<ModifierOption>>? selectedModifiers, String? notes}) {
    final items = _ordersByTable.putIfAbsent(tableId, () => []);
    items.add(OrderItemSelection(
      item: item,
      quantity: quantity,
      selectedModifiers: selectedModifiers,
      notes: notes,
    ));
    notifyListeners();
  }

  void updateItem(String tableId, int index, OrderItemSelection selection) {
    final items = _ordersByTable[tableId];
    if (items == null || index < 0 || index >= items.length) return;
    items[index] = selection;
    notifyListeners();
  }

  void removeItem(String tableId, int index) {
    final items = _ordersByTable[tableId];
    if (items == null || index < 0 || index >= items.length) return;
    items.removeAt(index);
    notifyListeners();
  }

  void clearOrder(String tableId) {
    _ordersByTable.remove(tableId);
    notifyListeners();
  }

  Future<String?> submitOrder(String tableId) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with API integration
      await Future.delayed(const Duration(milliseconds: 600));
      // Return a mock order id
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      return orderId;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  bool get isSubmitting => _submitting;
  String? get error => _error;
} 