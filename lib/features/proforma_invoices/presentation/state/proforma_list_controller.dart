import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import '../../domain/proforma_list_query.dart';
import '../../data/proforma_list_repository.dart';

class ProformaListController extends ChangeNotifier {
  ProformaListController(this.repository, {required this.readToken}) {
    search = SearchDebouncer(() => fetch());
  }
  final ProformaListRepository repository;
  final String Function() readToken;
  final invoiceNumber = TextEditingController(),
      customerSearch = TextEditingController();
  late final SearchDebouncer search;
  String status = 'All';
  bool loading = false, _disposed = false;
  int _generation = 0, currentPage = 1, lastPage = 1;
  String? errorMessage;
  List<Map<String, dynamic>> rows = [];
  Map<String, String> _loadedFilters = {};
  Map<String, String> get filters => ProformaListQuery(
          invoiceNumber: invoiceNumber.text,
          customerSearch: customerSearch.text,
          status: status)
      .toParameters();
  Future<void> fetch({int page = 1, Map<String, String>? snapshot}) async {
    if (_disposed) return;
    final request = ++_generation;
    final captured = Map<String, String>.of(snapshot ?? filters),
        token = readToken();
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await repository.fetchPage(token, captured, page);
      if (_disposed || request != _generation) return;
      rows = result.rows;
      currentPage = result.current;
      lastPage = result.last;
      _loadedFilters = Map.of(captured);
    } catch (error) {
      if (!_disposed && request == _generation) {
        errorMessage = '$error';
      }
    } finally {
      if (!_disposed && request == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() {
    search.cancel();
    return fetch(page: mapEquals(filters, _loadedFilters) ? currentPage : 1);
  }

  Future<void> goToPage(int page) {
    search.cancel();
    return fetch(page: mapEquals(filters, _loadedFilters) ? page : 1);
  }

  void selectStatus(String? value) {
    if (_disposed) return;
    search.cancel();
    status = value ?? 'All';
    fetch();
  }

  void reset() {
    if (_disposed) return;
    search.cancel();
    invoiceNumber.clear();
    customerSearch.clear();
    status = 'All';
    currentPage = 1;
    fetch();
  }

  Future<List<Map<String, dynamic>>> export(
      {void Function(int, int)? onProgress}) async {
    if (_disposed) throw StateError('Proforma list closed');
    search.cancel();
    final snapshot = filters, token = readToken();
    if (!mapEquals(snapshot, _loadedFilters)) {
      await fetch(snapshot: snapshot);
      if (_disposed || errorMessage != null) {
        throw StateError('Could not apply proforma filters');
      }
    }
    final result =
        await repository.fetchExport(token, snapshot, onProgress: onProgress);
    if (_disposed) throw StateError('Proforma list closed');
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    search.dispose();
    invoiceNumber.dispose();
    customerSearch.dispose();
    super.dispose();
  }
}
