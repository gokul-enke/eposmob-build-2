import 'package:flutter/material.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:pos_machine/models/list_receipt.dart';
import '../../data/receipt_list_repository.dart';
import '../../domain/receipt_list_query.dart';

/// Listing inputs and debounce only. Provider remains authoritative for rows.
class ReceiptListController extends ChangeNotifier {
  ReceiptListController(this.repository, {required this.readToken}) {
    search = SearchDebouncer(apply, delay: const Duration(milliseconds: 350));
  }
  final ReceiptListRepository repository;
  final String? Function() readToken;
  late final SearchDebouncer search;
  final name = TextEditingController(),
      receiptNumber = TextEditingController(),
      orderNumber = TextEditingController(),
      paymentReference = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      fromDate = TextEditingController(),
      toDate = TextEditingController();
  String? status, paymentMethod;
  bool initialized = false, _disposed = false;
  List<TextEditingController> get inputs =>
      [
        receiptNumber,
        orderNumber,
        paymentReference,
        name,
        phone,
        email,
        fromDate,
        toDate
      ];
  ReceiptListQuery get query => ReceiptListQuery(
      name: name.text,
      receiptNumber: receiptNumber.text,
      orderNumber: orderNumber.text,
      paymentReference: paymentReference.text,
      phone: phone.text,
      email: email.text,
      fromDate: fromDate.text,
      toDate: toDate.text,
      status: status,
      paymentMethod: paymentMethod);
  String requireToken() {
    final token = readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token');
    }
    return token;
  }

  Future<void> load() async {
    if (_disposed || initialized) return;
    await repository.load(requireToken());
    if (!_disposed) {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await repository.load(requireToken());
  }

  void apply() {
    if (_disposed) return;
    search.cancel();
    repository.apply(query);
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    search.cancel();
    for (final input in inputs) {
      input.clear();
    }
    status = null;
    paymentMethod = null;
    repository.reset();
    notifyListeners();
  }

  void goToPage(int page) {
    if (_disposed) return;
    // Preserve the existing pending-search-wins pagination behavior.
    if (search.isPending) {
      search.flush();
      return;
    }
    repository.goToPage(page);
  }

  Future<List<Receipt>> export({void Function(int, int)? onProgress}) async {
    if (_disposed) throw StateError('Receipt list closed.');
    search.flushPending();
    final captured = query, token = requireToken();
    final rows =
        await repository.export(token, captured, onProgress: onProgress);
    if (_disposed) throw StateError('Receipt list closed.');
    return rows;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    search.dispose();
    for (final input in inputs) {
      input.dispose();
    }
    super.dispose();
  }
}
