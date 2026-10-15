import 'package:flutter/material.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:pos_machine/models/list_invoice.dart';
import '../../data/invoice_list_repository.dart';
import '../../domain/invoice_list_query.dart';

/// Owns only the listing inputs, debounce, selection and list lifecycle.
/// Shared provider request-generation guards remain the source of truth for
/// visible rows because existing invoice actions update that same state.
class InvoiceListController extends ChangeNotifier {
  InvoiceListController(this.repository, {required this.readToken}) {
    search = SearchDebouncer(apply, delay: const Duration(milliseconds: 350));
  }
  final InvoiceListRepository repository;
  final String? Function() readToken;
  late final SearchDebouncer search;
  final name = TextEditingController(),
      invoiceNumber = TextEditingController(),
      phone = TextEditingController(),
      fromDate = TextEditingController(),
      toDate = TextEditingController();
  final selectedIds = <int>{};
  String? status, zatcaStatus;
  bool initialized = false, _disposed = false;
  List<TextEditingController> get inputs =>
      [invoiceNumber, name, phone, fromDate, toDate];
  InvoiceListQuery get query => InvoiceListQuery(
      name: name.text,
      invoiceNumber: invoiceNumber.text,
      phone: phone.text,
      fromDate: fromDate.text,
      toDate: toDate.text,
      status: status,
      zatcaStatus: zatcaStatus);
  String requireToken() {
    final token = readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token.');
    }
    return token;
  }

  Future<void> load() async {
    if (_disposed || initialized) return;
    await repository.load(requireToken(), zatcaStatus: zatcaStatus);
    if (!_disposed) {
      initialized = true;
      notifyListeners();
    }
  }

  void apply() {
    if (_disposed) return;
    selectedIds.clear();
    repository.apply(query);
    notifyListeners();
  }

  void clearSelection() {
    if (_disposed || selectedIds.isEmpty) return;
    selectedIds.clear();
    notifyListeners();
  }

  void select(int id, bool selected) {
    if (_disposed) return;
    selected ? selectedIds.add(id) : selectedIds.remove(id);
    notifyListeners();
  }

  void selectPage(Iterable<int> ids) {
    if (_disposed) return;
    selectedIds.addAll(ids);
    notifyListeners();
  }

  void clearControls() {
    search.cancel();
    for (final input in inputs) {
      input.clear();
    }
    status = null;
    zatcaStatus = null;
    selectedIds.clear();
  }

  void reset({bool reload = true, bool notifyProvider = true}) {
    if (_disposed) return;
    clearControls();
    repository.reset(reload: reload, notify: notifyProvider);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final token = readToken();
    if (token == null || token.isEmpty) return;
    search.cancel();
    clearSelection();
    await repository.load(token, page: repository.provider.currentPage);
  }

  void goToPage(int page) {
    if (_disposed) return;
    search.cancel();
    clearSelection();
    repository.goToPage(page);
  }

  Future<List<Invoice>> export(
      {required bool showZatca, void Function(int, int)? onProgress}) async {
    if (_disposed) throw StateError('Invoice list closed.');
    search.flushPending();
    final captured = query, token = requireToken();
    final rows = await repository.export(token, captured,
        showZatca: showZatca, onProgress: onProgress);
    if (_disposed) throw StateError('Invoice list closed.');
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
