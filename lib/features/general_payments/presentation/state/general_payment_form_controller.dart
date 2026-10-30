import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:pos_machine/helpers/date_helper.dart';
import '../../domain/general_payment_entry.dart';
import '../../domain/general_payment_method_rules.dart';
import '../../domain/general_payment_type.dart';

typedef GeneralPaymentAccountsLoader = Future<GeneralPaymentAccounts> Function(
    GeneralPaymentType type, GeneralPaymentLoan? loan);
typedef GeneralPaymentCategoriesLoader = Future<List<GeneralPaymentOption>>
    Function(GeneralPaymentType type);
typedef GeneralPaymentSave = Future<GeneralPaymentSaveResult> Function(
    Map<String, dynamic> payload);

/// The New Entry form: entry type (and loan direction), date, category,
/// debit and credit accounts, amount, payment method and texts. Changing the
/// type or loan direction reloads that kind's accounts and clears choices it
/// does not offer; a newer load always wins.
class GeneralPaymentFormController extends ChangeNotifier {
  GeneralPaymentFormController({
    required this.loadAccounts,
    required this.loadCategories,
    required this.loadPaymentMethods,
    required this.save,
    this.loadAllowedMethods,
    GeneralPaymentType type = GeneralPaymentType.expense,
    Map<String, String> nextReferences = const {},
    DateTime Function()? clock,
  })  : _type = type,
        _loan = type == GeneralPaymentType.loan
            ? GeneralPaymentLoan.received
            : null,
        _references = Map.of(nextReferences),
        _clock = clock ?? DateTime.now {
    final now = _clock();
    _date = DateTime(now.year, now.month, now.day);
    dateText.text = DateHelper.formatYearMonthDay(_date);
    _showReference();
  }

  /// The expected next number of this kind's series (repayments: LRP).
  void _showReference() => reference.text =
      _references[generalPaymentReferencePrefix(_type, _loan)] ?? '';

  final GeneralPaymentAccountsLoader loadAccounts;
  final GeneralPaymentCategoriesLoader loadCategories;
  final Future<List<GeneralPaymentOption>> Function() loadPaymentMethods;
  final GeneralPaymentSave save;

  /// Account name → the payment methods it allows (Company Accounts setup).
  final Future<Map<String, List<String>>> Function()? loadAllowedMethods;
  final DateTime Function() _clock;
  final Map<String, String> _references;

  /// Read-only fields: the expected reference number and the chosen date.
  final reference = TextEditingController();
  final dateText = TextEditingController();
  final description = TextEditingController();
  final amount = TextEditingController();
  final usefulLife = TextEditingController();
  final notes = TextEditingController();

  GeneralPaymentType _type;
  GeneralPaymentLoan? _loan;
  late DateTime _date;
  String? _categoryId, _debitId, _creditId, _paymentMethodId;
  List<GeneralPaymentOption> _debitOptions = const [],
      _creditOptions = const [],
      _categories = const [],
      _paymentMethods = const [];
  final _categoryCache = <GeneralPaymentType, List<GeneralPaymentOption>>{};
  GeneralPaymentMethodRules _methodRules = GeneralPaymentMethodRules.none;
  bool _loadingAccounts = false, _loadingCategories = false;
  bool _loadingMethods = false, _busy = false, _disposed = false;
  bool _accountsFailed = false, _categoriesFailed = false;
  bool _methodsFailed = false;
  int _accountsRequest = 0, _categoriesRequest = 0;

  GeneralPaymentType get type => _type;
  GeneralPaymentLoan? get loan => _loan;
  DateTime get date => _date;
  String? get categoryId => _categoryId;
  String? get debitAccountId => _debitId;
  String? get creditAccountId => _creditId;
  String? get paymentMethodId => _paymentMethodId;
  List<GeneralPaymentOption> get debitOptions => _debitOptions;
  List<GeneralPaymentOption> get creditOptions => _creditOptions;
  List<GeneralPaymentOption> get categories => _categories;

  /// The cash or bank account the money moves through, whose Company
  /// Accounts rule picks the payment methods.
  String? get _moneyAccount =>
      GeneralPaymentMethodRules.receivesOnDebit(_type, _loan)
          ? debitAccountName
          : creditAccountName;

  /// The methods that account allows (UPI is not paid from the Cash
  /// Account), as Create Expense offers them; all while it has no rule.
  List<GeneralPaymentOption> get paymentMethods =>
      _methodRules.methodsFor(_moneyAccount, _paymentMethods);

  /// Drops a method the money account does not allow, and picks the method
  /// when the account allows only one.
  void _fitPaymentMethod() {
    final methods = paymentMethods;
    if (!methods.any((method) => method.id == _paymentMethodId)) {
      _paymentMethodId = null;
    }
    if (_paymentMethodId == null &&
        _methodRules.limits(_moneyAccount) &&
        methods.length == 1) {
      _paymentMethodId = methods.single.id;
    }
  }

  bool get loadingAccounts => _loadingAccounts;
  bool get loadingCategories => _loadingCategories;
  bool get loadingPaymentMethods => _loadingMethods;
  bool get busy => _busy;

  /// Some choices could not be loaded (shown with Retry).
  bool get optionsFailed =>
      _accountsFailed || _categoriesFailed || _methodsFailed;

  /// The entry's amount, or null while it is not a positive number.
  double? get amountValue {
    final value = double.tryParse(amount.text.trim());
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  static String? _label(List<GeneralPaymentOption> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return null;
  }

  String? get debitAccountName => _label(_debitOptions, _debitId);
  String? get creditAccountName => _label(_creditOptions, _creditId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads the first kind's accounts and categories, the payment methods
  /// and which accounts allow which methods.
  Future<void> initialize() => Future.wait(
      [_loadAccounts(), _loadCategories(), _loadMethods(), _loadMethodRules()]);

  Future<void> _loadMethodRules() async {
    final load = loadAllowedMethods;
    if (load == null) return;
    try {
      final rules = GeneralPaymentMethodRules(await load());
      if (_disposed) return;
      _methodRules = rules;
      _fitPaymentMethod();
      _notify();
    } catch (_) {
      // Without the rules every method stays available.
    }
  }

  /// A new type keeps the date, amount, payment method and texts; its
  /// category and accounts are chosen again.
  Future<void> setType(GeneralPaymentType value) {
    if (_disposed || _busy || value == _type) return Future.value();
    _type = value;
    _loan =
        value == GeneralPaymentType.loan ? GeneralPaymentLoan.received : null;
    _categoryId = _debitId = _creditId = null;
    _showReference();
    _notify();
    return Future.wait([_loadAccounts(), _loadCategories()]);
  }

  /// Received and repaid loans swap their accounts.
  Future<void> setLoan(GeneralPaymentLoan value) {
    if (_disposed || _busy || _type != GeneralPaymentType.loan) {
      return Future.value();
    }
    if (value == _loan) return Future.value();
    _loan = value;
    _showReference();
    _debitId = _creditId = null;
    _notify();
    return _loadAccounts();
  }

  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    dateText.text = DateHelper.formatYearMonthDay(_date);
    _notify();
  }

  void setCategory(String? id) => _set(() => _categoryId = id);
  void setDebitAccount(String? id) => _set(() {
        _debitId = id;
        _fitPaymentMethod();
      });
  void setCreditAccount(String? id) => _set(() {
        _creditId = id;
        _fitPaymentMethod();
      });

  /// A method the money account does not allow (picked from a list opened
  /// before the account changed) is dropped again.
  void setPaymentMethod(String? id) => _set(() {
        _paymentMethodId = id;
        _fitPaymentMethod();
      });

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    _notify();
  }

  Future<void> _loadAccounts() async {
    final request = ++_accountsRequest, type = _type, loan = _loan;
    bool current() => !_disposed && request == _accountsRequest;
    _loadingAccounts = true;
    _accountsFailed = false;
    _debitOptions = _creditOptions = const [];
    _notify();
    try {
      final accounts = await loadAccounts(type, loan);
      if (!current()) return;
      _debitOptions = List.unmodifiable(accounts.debit);
      _creditOptions = List.unmodifiable(accounts.credit);
      // A side with one account (Fixed Asset, Loan Account) needs no choice.
      if (_debitOptions.length == 1) _debitId = _debitOptions.single.id;
      if (_creditOptions.length == 1) _creditId = _creditOptions.single.id;
      _fitPaymentMethod();
      if (_debitOptions.isEmpty || _creditOptions.isEmpty) {
        _accountsFailed = true;
      }
    } catch (_) {
      if (current()) _accountsFailed = true;
    } finally {
      if (current()) {
        _loadingAccounts = false;
        _notify();
      }
    }
  }

  Future<void> _loadCategories() async {
    final request = ++_categoriesRequest, type = _type;
    bool current() => !_disposed && request == _categoriesRequest;
    _categoriesFailed = false;
    if (_categoryCache[type] case final cached?) {
      _categories = cached;
      _loadingCategories = false;
      _notify();
      return;
    }
    _categories = const [];
    _loadingCategories = true;
    _notify();
    try {
      final list =
          List<GeneralPaymentOption>.unmodifiable(await loadCategories(type));
      if (!current()) return;
      _categories = list;
      if (list.isEmpty) {
        _categoriesFailed = true;
      } else {
        _categoryCache[type] = list;
      }
    } catch (_) {
      if (current()) _categoriesFailed = true;
    } finally {
      if (current()) {
        _loadingCategories = false;
        _notify();
      }
    }
  }

  Future<void> _loadMethods() async {
    _loadingMethods = true;
    _methodsFailed = false;
    _notify();
    try {
      final list =
          List<GeneralPaymentOption>.unmodifiable(await loadPaymentMethods());
      if (_disposed) return;
      // No Cash default: the method must fit the cash or bank account, so
      // it is picked only when that account allows just one (as on Create
      // Expense); otherwise the user chooses.
      _paymentMethods = list;
      _methodsFailed = list.isEmpty;
      _fitPaymentMethod();
    } catch (_) {
      if (!_disposed) _methodsFailed = true;
    } finally {
      if (!_disposed) {
        _loadingMethods = false;
        _notify();
      }
    }
  }

  /// Loads again only what failed.
  Future<void> retryOptions() => Future.wait([
        if (_accountsFailed) _loadAccounts(),
        if (_categoriesFailed) _loadCategories(),
        if (_methodsFailed) _loadMethods(),
      ]);

  /// Why the entry cannot be saved yet, as a translation key; null when the
  /// choices are complete. Text fields check themselves.
  String? get selectionError {
    if (_categoryId == null) return 'general_payments.error_category';
    if (_debitId == null) return 'general_payments.error_debit';
    if (_creditId == null) return 'general_payments.error_credit';
    if (_debitId == _creditId) return 'general_payments.error_same_account';
    if (_paymentMethodId == null) {
      return 'general_payments.error_payment_method';
    }
    return null;
  }

  GeneralPaymentDraft? get draft {
    final value = amountValue;
    if (selectionError != null || value == null) return null;
    return GeneralPaymentDraft(
        type: _type,
        loan: _loan,
        date: _date,
        categoryId: _categoryId!,
        debitAccountId: _debitId!,
        creditAccountId: _creditId!,
        amount: value,
        paymentMethodId: _paymentMethodId!,
        description: description.text,
        notes: notes.text,
        usefulLifeYears: _type == GeneralPaymentType.asset
            ? int.tryParse(usefulLife.text.trim())
            : null);
  }

  /// Saves the entry; null when it is incomplete or already saving. After a
  /// save with [createAnother] the form is ready for the next entry of the
  /// same kind: type, date, accounts and payment method stay.
  Future<GeneralPaymentSaveResult?> submit({bool createAnother = false}) async {
    final entry = draft;
    if (_disposed || _busy || entry == null) return null;
    _busy = true;
    _notify();
    GeneralPaymentSaveResult result;
    try {
      result = await save(entry.toPayload());
    } catch (_) {
      result = const GeneralPaymentRejected();
    }
    if (_disposed) return result;
    if (result is GeneralPaymentSaved) {
      final saved = result.reference ?? reference.text;
      final next =
          saved.isEmpty ? null : followingGeneralPaymentReference(saved);
      if (next != null) {
        _references[generalPaymentReferencePrefix(entry.type, entry.loan)] =
            next;
      }
      if (createAnother) {
        _categoryId = null;
        for (final field in [description, amount, usefulLife, notes]) {
          field.clear();
        }
        _showReference();
      }
    }
    _busy = false;
    _notify();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final field in [
      reference,
      dateText,
      description,
      amount,
      usefulLife,
      notes
    ]) {
      field.dispose();
    }
    super.dispose();
  }
}
