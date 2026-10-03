import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import '../state/expense_provider.dart';
import '../state/expense_form_controller.dart';
import '../navigation/expense_navigation.dart';
import '../widgets/form/expense_form_body.dart';

class CreateExpensePage extends StatefulWidget {
  const CreateExpensePage({super.key});
  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late final ExpenseProvider _provider;
  late final AuthModel _auth;
  late final MasterDataProvider _masterData;
  late final CompanyAccountProvider _accounts;
  late final ExpenseFormController _controller;
  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseProvider>();
    _auth = context.read<AuthModel>();
    _masterData = context.read<MasterDataProvider>();
    _accounts = context.read<CompanyAccountProvider>();
    _controller =
        ExpenseFormController(referenceNo: _provider.nextReferenceNumber);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final token = _auth.token;
      if (token != null) {
        await _provider.fetchAccountOptions(accessToken: token);
        if (!mounted) return;
        await _accounts.listCompanyAccounts(accessToken: token, loadAll: true);
        if (!mounted) return;
      }
      await _loadMasterDataOptions();
      if (mounted) _controller.dateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMasterDataOptions() async {
    final masterDataProvider = _masterData;
    final expenseProvider = _provider;

    final categories = await _fetchFirstAvailableMasterData(
      masterDataProvider,
      const ['EXPENSE_CATEGORY', 'EXPENSE_CATEGORIES'],
    );
    if (!mounted) return;
    if (categories != null && categories.isNotEmpty) {
      expenseProvider.setCategoryOptionsFromMasterData(categories);
    }

    final paymentMethods = await masterDataProvider.fetchPaymentMethods();
    if (!mounted || paymentMethods == null || paymentMethods.isEmpty) return;
    expenseProvider.setPaymentMethodOptionsFromMasterData(paymentMethods);
  }

  Future<List<MasterDataValue>?> _fetchFirstAvailableMasterData(
    MasterDataProvider provider,
    List<String> codes,
  ) async {
    for (final code in codes) {
      try {
        final result = await provider.fetchMasterData(code);
        final data = result?.data;
        if (data != null && data.isNotEmpty) {
          return data;
        }
      } catch (_) {
        // Try next candidate code.
      }
    }
    return null;
  }

  Future<void> _submit(bool createAnother) async {
    if (_controller.isSubmitting || !_formKey.currentState!.validate()) return;
    final error = _controller.selectionError;
    if (error != null) {
      showScaffoldError(context: context, message: error.tr);
      return;
    }
    final token = _auth.token;
    if (token == null) {
      showScaffoldError(context: context, message: 'expense.error_no_token'.tr);
      return;
    }
    final result = await _controller.submit(
        create: (payload) => _provider.createGeneralPayment(
            accessToken: token, payload: payload),
        nextReference: () => _provider.nextReferenceNumber,
        createAnother: createAnother);
    if (!mounted || result == null) return;
    if (result['status'] == 'success') {
      showScaffold(context: context, message: 'expense.success_created'.tr);
      if (!createAnother) ExpenseNavigation.openList();
    } else {
      showScaffoldError(
          context: context,
          message: result['message'] ?? 'expense.error_create_failed'.tr);
    }
  }

  List<String> _allowedPaymentMethods(Map<String, dynamic>? value) =>
      _accounts.getCompanyAccountsList
          ?.firstWhereOrNull((a) => a.name == value?['name']?.toString())
          ?.paymentMethod ??
      [];
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.select<AppSettingsProvider, String>(
        (p) => p.appSettings?.currency ?? '');
    return ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ExpenseFormBody(
            controller: _controller,
            formKey: _formKey,
            currency: currency,
            categoryOptions: provider.categoryOptions,
            debitAccountOptions: provider.debitAccountOptions,
            creditAccountOptions: provider.creditAccountOptions,
            paymentMethodOptions: provider.paymentMethodOptions,
            allowedPaymentMethods: _allowedPaymentMethods,
            onSubmit: _submit,
            onCancel: ExpenseNavigation.openList,
            onError: (message) =>
                showScaffoldError(context: context, message: message)));
  }
}
