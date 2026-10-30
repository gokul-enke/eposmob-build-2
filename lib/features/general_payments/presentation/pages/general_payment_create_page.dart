import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/company_accounts.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import '../../data/general_payment_form_api.dart';
import '../../domain/general_payment_entry.dart';
import '../../domain/general_payment_type.dart';
import '../navigation/general_payment_navigation.dart';
import '../state/general_payment_form_controller.dart';
import '../widgets/general_payment_form_actions.dart';
import '../widgets/general_payment_form_sections.dart';

/// New Entry of General Payments: an expense, asset purchase, other income,
/// or a loan received or repaid, with its debit and credit accounts. Saving
/// returns to the list unless "Create & add another" is used.
class GeneralPaymentCreatePage extends StatefulWidget {
  const GeneralPaymentCreatePage({super.key, this.api});

  /// Injected in tests.
  final GeneralPaymentFormApi? api;

  @override
  State<GeneralPaymentCreatePage> createState() =>
      _GeneralPaymentCreatePageState();
}

class _GeneralPaymentCreatePageState extends State<GeneralPaymentCreatePage> {
  late final GeneralPaymentFormApi _api = widget.api ?? GeneralPaymentFormApi();
  late final AuthModel _auth;
  late final AppSettingsProvider _settings;
  late final MasterDataProvider _master;
  late final CompanyAccountProvider _companyAccounts;
  late final GeneralPaymentFormController _form;
  final _formKey = GlobalKey<FormState>();

  String get _token => _auth.token ?? '';
  String _tr(String key) => 'general_payments.$key'.tr;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _settings = context.read<AppSettingsProvider>();
    _master = context.read<MasterDataProvider>();
    _companyAccounts = context.read<CompanyAccountProvider>();
    final request = GeneralPaymentNavigation.takeCreateRequest();
    _form = GeneralPaymentFormController(
        type: request?.type ?? GeneralPaymentType.expense,
        nextReferences: request?.nextReferences ?? const {},
        loadAccounts: (type, loan) =>
            _api.accountOptions(accessToken: _token, type: type, loan: loan),
        loadCategories: _categories,
        loadPaymentMethods: _paymentMethods,
        loadAllowedMethods: _allowedMethods,
        save: (payload) => _api.create(accessToken: _token, payload: payload));
    // Master data notifies its listeners as it starts, so not during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _form.initialize();
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  static GeneralPaymentOption _option(MasterDataValue value) =>
      GeneralPaymentOption('${value.id}', value.label, code: value.stableCode);

  /// The first of the type's master data codes that has values.
  Future<List<GeneralPaymentOption>> _categories(
      GeneralPaymentType type) async {
    for (final code in type.categoryCodes) {
      try {
        final values = (await _master.fetchMasterData(code))?.data;
        if (values != null && values.isNotEmpty) {
          return [for (final value in values) _option(value)];
        }
      } catch (_) {
        // Not this code; try the next.
      }
    }
    return const [];
  }

  Future<List<GeneralPaymentOption>> _paymentMethods() async {
    final cached = _master.paymentMethods;
    final values = cached != null && cached.isNotEmpty
        ? cached
        : await _master.fetchPaymentMethods() ?? const <MasterDataValue>[];
    return [for (final value in values) _option(value)];
  }

  /// Each company account's allowed payment methods, by account name, as
  /// Create Expense reads them.
  Future<Map<String, List<String>>> _allowedMethods() async {
    if (_token.isEmpty) return const {};
    await _companyAccounts.listCompanyAccounts(
        accessToken: _token, loadAll: true);
    return {
      for (final account in _companyAccounts.getCompanyAccountsList ??
          const <CompanyAccountsData>[])
        if (account.name case final name?)
          name: account.paymentMethod ?? const [],
    };
  }

  /// The app's calendar (closes on a tap); no future dates, as on Create
  /// Expense.
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showAutoDismissDatePicker(
        context: context,
        initialDate: _form.date.isAfter(today) ? today : _form.date,
        firstDate: DateTime(2000),
        lastDate: today);
    if (picked != null && mounted) _form.setDate(picked);
  }

  Future<void> _submit({bool another = false}) async {
    if (_form.busy) return;
    final fieldsValid = _formKey.currentState?.validate() ?? false;
    // Also as a toast: on a phone the field may be scrolled out of view.
    final error = _form.selectionError ??
        (fieldsValid
            ? null
            : generalPaymentAmountError(_form.amount.text) ??
                generalPaymentUsefulLifeError(_form.usefulLife.text));
    if (error != null) {
      AppToast.error(context, error.tr);
      return;
    }
    if (!fieldsValid) return;
    final result = await _form.submit(createAnother: another);
    if (!mounted || result == null) return;
    switch (result) {
      case GeneralPaymentSaved(:final reference):
        AppToast.success(
            context,
            reference == null
                ? _tr('saved')
                : 'general_payments.saved_reference'
                    .trParams({'reference': reference}));
        if (!another) GeneralPaymentNavigation.openList();
      case GeneralPaymentRejected(:final message):
        AppToast.error(context, message ?? _tr('save_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final gutter = constraints.maxWidth < 600 ? 16.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListenableBuilder(
                  listenable: Listenable.merge([_form, _settings]),
                  builder: (context, _) {
                    final currency = _settings.appSettings?.currency ?? '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PageHeader(
                            icon: Icons.account_balance_outlined,
                            title: _tr('new_entry_title'),
                            subtitle: _tr('new_entry_subtitle'),
                            leading: AppOutlinedButton(
                                label: _tr('title'),
                                icon: Icons.arrow_back_rounded,
                                onPressed: _form.busy
                                    ? null
                                    : GeneralPaymentNavigation.openList)),
                        const SizedBox(height: AppSpacing.xl),
                        Form(
                          key: _formKey,
                          child: AbsorbPointer(
                            absorbing: _form.busy,
                            child: GeneralPaymentFormSections(
                                form: _form,
                                currency: currency,
                                onPickDate: _pickDate),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        GeneralPaymentFormActions(
                            stacked: constraints.maxWidth < 520,
                            busy: _form.busy,
                            onCreate: _submit,
                            onCreateAnother: () => _submit(another: true),
                            onCancel: GeneralPaymentNavigation.openList),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
