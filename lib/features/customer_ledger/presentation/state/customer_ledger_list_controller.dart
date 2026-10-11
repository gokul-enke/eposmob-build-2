import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import '../../domain/customer_ledger_query.dart';
import '../../data/customer_ledger_repository.dart';

class CustomerLedgerListController extends ChangeNotifier {
  CustomerLedgerListController(this.repository, {required this.readToken});
  final CustomerLedgerRepository repository;
  final String Function() readToken;
  void _publish(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  final amount = TextEditingController(),
      name = TextEditingController(),
      reference = TextEditingController();
  final nameFocus = FocusNode();
  late final SearchDebouncer search = SearchDebouncer(() {
    if (!_disposed) fetch();
  });
  String type = 'All';
  String? customerId;
  DateTime? date;
  bool loading = false, _disposed = false;
  String? error;
  int _generation = 0, currentPage = 1, totalPages = 1;
  List<ListTransaction> rows = [], suggestions = [];
  List<ListTransaction>? _cache;
  CustomerLedgerServerQuery? _cacheKey;
  CustomerLedgerQuery? _loaded;
  bool get hasLoaded => _loaded != null;

  CustomerLedgerQuery get filters => (
        amount: amount.text.trim(),
        name: name.text.trim(),
        reference: reference.text.trim(),
        type: type,
        customerId: customerId,
        date: date == null ? null : DateFormat('yyyy-MM-dd').format(date!)
      );
  void _cancelPending() => search.cancel();
  Future<void> fetch(
      {int page = 1, bool force = false, CustomerLedgerQuery? filters}) async {
    if (_disposed) return;
    final f = filters ?? this.filters;
    final generation = ++_generation;
    final token = readToken();
    _publish(() {
      loading = true;
      error = null;
    });
    try {
      List<ListTransaction> rows;
      List<ListTransaction>? cache;
      int current, last;
      if (needsLocalLedgerMatching(f)) {
        cache = !force && _cacheKey == ledgerServerQuery(f) ? _cache : null;
        cache ??= await repository.snapshot(token, f);
        final filtered = matchCustomerLedger(cache, f);
        last = ((filtered.length + 19) ~/ 20).clamp(1, 2147483647);
        current = page.clamp(1, last);
        rows = filtered.skip((current - 1) * 20).take(20).toList();
      } else {
        final result = await repository.page(token, f, page);
        rows = result.rows;
        current = result.current;
        last = result.last;
      }
      if (_disposed || generation != _generation) return;
      _publish(() {
        this.rows = rows;
        currentPage = current;
        totalPages = last;
        _loaded = f;
        suggestions = cache ?? rows;
        if (force) {
          _cache = null;
          _cacheKey = null;
        }
        if (cache != null) {
          _cache = cache;
          _cacheKey = ledgerServerQuery(f);
        }
      });
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _publish(() => error = 'party_accounts.load_error'.tr);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _publish(() => loading = false);
      }
    }
  }

  Future<void> refresh() async {
    _cancelPending();
    await fetch(force: true);
  }

  void reset() {
    if (_disposed) return;
    _cancelPending();
    amount.clear();
    name.clear();
    reference.clear();
    _publish(() {
      type = 'All';
      customerId = null;
      date = null;
      _cache = null;
      _cacheKey = null;
    });
    fetch();
  }

  Future<List<ListTransaction>> exportRows(
      {void Function(int, int)? onProgress}) async {
    if (_disposed) throw StateError('Customer ledger screen closed.');
    _cancelPending();
    final f = filters;
    if (loading || error != null) {
      throw StateError('Customer ledger is unavailable.');
    }
    final token = readToken();
    if (_loaded != f) {
      await fetch(filters: f);
    }
    if (_disposed || error != null || _loaded != f) {
      throw StateError('Customer ledger filters changed.');
    }
    final all = _cacheKey == ledgerServerQuery(f) && _cache != null
        ? _cache!
        : await repository.snapshot(token, f, onProgress: (p, last) {
            if (!_disposed) onProgress?.call(p, last);
          });
    if (_disposed) throw StateError('Customer ledger screen closed.');
    final rows = matchCustomerLedger(all, f);
    return rows;
  }

  void selectCustomer(ListTransaction r) {
    if (_disposed) return;
    _cancelPending();
    customerId = r.customerId?.toString();
    fetch();
  }

  void editCustomer() {
    if (_disposed) return;
    customerId = null;
    search.schedule();
  }

  void selectType(String? v) {
    if (_disposed) return;
    _cancelPending();
    type = v ?? 'All';
    fetch();
  }

  void selectDate(DateTime picked) {
    if (_disposed) return;
    _cancelPending();
    date = picked;
    fetch();
  }

  void goToPage(int p) {
    if (_disposed) return;
    if (!loading) {
      _cancelPending();
      fetch(page: p);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    search.dispose();
    amount.dispose();
    name.dispose();
    reference.dispose();
    nameFocus.dispose();
    super.dispose();
  }
}
