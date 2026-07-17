import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_back_button.dart';
import '../../newcomponents/custom_dialog_box.dart';
import '../../newcomponents/custom_round_button.dart';
import '../../newcomponents/custom_container_box.dart';
import '../../newcomponents/custom_dropdown_with_search.dart';
import '../../components/build_container_box.dart';
import '../../components/build_calendar_selection.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/expense.dart';
import '../../models/master_data.dart';
import '../../providers/auth_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/company_account_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final SideBarController sideBarController = Get.find<SideBarController>();
  final _formKey = GlobalKey<FormState>();

  late String referenceNo;
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic>? selectedCategory;
  final TextEditingController descriptionController = TextEditingController();
  Map<String, dynamic>? selectedDebitAccount;
  Map<String, dynamic>? selectedCreditAccount;
  final TextEditingController amountController = TextEditingController();
  Map<String, dynamic>? selectedPaymentMethod;
  final TextEditingController notesController = TextEditingController();
  List<String> _allowedPaymentMethods = [];
  bool _isSubmitting = false;

  final FocusNode categoryFocus = FocusNode();
  final FocusNode dateFocus = FocusNode();
  final FocusNode debitAccountFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();
  final FocusNode creditAccountFocus = FocusNode();
  final FocusNode paymentMethodFocus = FocusNode();
  final FocusNode notesFocus = FocusNode();
  final FocusNode createBtnFocus = FocusNode();
  final FocusNode createAnotherBtnFocus = FocusNode();
  final FocusNode cancelBtnFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    referenceNo = provider.nextReferenceNumber;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null) {
        await provider.fetchAccountOptions(accessToken: token);
        if (mounted) {
          final companyAccountProvider =
              Provider.of<CompanyAccountProvider>(context, listen: false);
          await companyAccountProvider.listCompanyAccounts(
              accessToken: token, loadAll: true);
        }
      }
      await _loadMasterDataOptions();
      dateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    notesController.dispose();
    categoryFocus.dispose();
    dateFocus.dispose();
    debitAccountFocus.dispose();
    descriptionFocus.dispose();
    amountFocus.dispose();
    creditAccountFocus.dispose();
    paymentMethodFocus.dispose();
    notesFocus.dispose();
    createBtnFocus.dispose();
    createAnotherBtnFocus.dispose();
    cancelBtnFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMasterDataOptions() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

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

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // strip time component

    final DateTime? picked = await showAutoDismissDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && picked != selectedDate) {
      // Safety guard: reject if future date somehow slips through
      if (picked.isAfter(today)) {
        showScaffoldError(context: context, message: "Future dates cannot be selected");
        return;
      }
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _submitForm({bool createAnother = false}) {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      showScaffoldError(context: context, message: "Please select an Expense Category");
      return;
    }
    if (selectedDebitAccount == null) {
      showScaffoldError(context: context, message: "Please select a Debit Account");
      return;
    }
    if (selectedCreditAccount == null) {
      showScaffoldError(context: context, message: "Please select a Credit Account");
      return;
    }
    if (selectedPaymentMethod == null) {
      showScaffoldError(context: context, message: "Please select a Payment Method");
      return;
    }

    final double amount = double.tryParse(amountController.text) ?? 0.0;
    if (amount <= 0) {
      showScaffoldError(context: context, message: "Please enter a valid amount greater than zero");
      return;
    }

    final token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null) {
      showScaffoldError(context: context, message: "Authentication token missing. Please log in again.");
      return;
    }

    final payload = {
      "entry_type": "EXPENSE",
      "payment_date": "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
      "category": selectedCategory!['id'].toString(),
      "description": descriptionController.text.trim(),
      "amount": amount,
      "payment_method": selectedPaymentMethod!['id'].toString(),
      "expense_account_id": selectedDebitAccount!['id'],
      "payment_account_id": selectedCreditAccount!['id'],
      "status": "SUCC",
      "notes": notesController.text.trim(),
    };

    setState(() {
      _isSubmitting = true;
    });

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    provider.createGeneralPayment(accessToken: token, payload: payload).then((result) {
      setState(() {
        _isSubmitting = false;
      });
      if (result['status'] == 'success') {
        showScaffold(context: context, message: "Expense created successfully");
        if (createAnother) {
          setState(() {
            descriptionController.clear();
            amountController.clear();
            notesController.clear();
            selectedCategory = null;
            selectedDebitAccount = null;
            selectedCreditAccount = null;
            selectedPaymentMethod = null;
            selectedDate = DateTime.now();
            referenceNo = provider.nextReferenceNumber;
          });
        } else {
          sideBarController.index.value = 93;
        }
      } else {
        showScaffoldError(context: context, message: result['message'] ?? 'Failed to create expense');
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredPaymentMethods(
      ExpenseProvider provider) {
    if (selectedCreditAccount == null || _allowedPaymentMethods.isEmpty) {
      return provider.paymentMethodOptions;
    }
    return provider.paymentMethodOptions.where((method) {
      final name = method['name']?.toString().toUpperCase();
      return _allowedPaymentMethods.any(
          (allowed) => allowed.toUpperCase() == name);
    }).toList();
  }

  bool _isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final isPhone = _isPhone(context);

    return SafeArea(
      child: CustomBoxShadowContainer(
        margin: EdgeInsets.symmetric(
          horizontal: isPhone ? 4 : 10,
          vertical: isPhone ? 8 : 20,
        ),
        padding: EdgeInsets.all(isPhone ? 14 : 20),
        circleRadius: 22,
        offsetValue: const Offset(1, 1),
        blurRadius: 6,
        color: Colors.white,
        child: Form(
          key: _formKey,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSectionTitle("Entry Details"),
                const SizedBox(height: 15),
                _buildFormFields(provider, isPhone),
                const SizedBox(height: 15),
                _buildLabel("Notes"),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(8),
                  child: _buildNotesField(notesFocus),
                ),
                const SizedBox(height: 30),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(9),
                  child: _buildActionButtons(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(ExpenseProvider provider, bool isPhone) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Reference No."),
        _buildDisabledTextField(referenceNo),
        const SizedBox(height: 15),
        _buildLabel("Expense Category*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: _buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_category_dropdown'),
            focusNode: categoryFocus,
            hint: "Select an option",
            value: selectedCategory,
            items: provider.categoryOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) => setState(() => selectedCategory = val),
          ),
        ),
        const SizedBox(height: 15),
        _buildLabel("Expense Account (Debit)*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: _buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_debit_account_dropdown'),
            focusNode: debitAccountFocus,
            hint: "Select an option",
            value: selectedDebitAccount,
            items: provider.debitAccountOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) => setState(() => selectedDebitAccount = val),
          ),
        ),
        const SizedBox(height: 15),
        _buildLabel("Amount*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(6),
          child: _buildAmountField(amountFocus),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Payment Date*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: _buildDatePickerField(dateFocus),
        ),
        const SizedBox(height: 15),
        _buildLabel("Description / Vendor"),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _buildTextField(
            controller: descriptionController,
            hint: "e.g. Office rent",
            focusNode: descriptionFocus,
          ),
        ),
        const SizedBox(height: 15),
        _buildLabel("Paid From / Source (Credit)*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(5),
          child: _buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_credit_account_dropdown'),
            focusNode: creditAccountFocus,
            hint: "Select an option",
            value: selectedCreditAccount,
            items: provider.creditAccountOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) {
              setState(() {
                selectedCreditAccount = val;
                final companyAccountProvider =
                    Provider.of<CompanyAccountProvider>(context, listen: false);
                final selectedAccountName = val?['name']?.toString();
                final matchedAccount = companyAccountProvider
                    .getCompanyAccountsList?.firstWhereOrNull(
                      (account) => account.name == selectedAccountName);
                _allowedPaymentMethods = matchedAccount?.paymentMethod ?? [];
                // Reset payment method if no longer valid
                if (selectedPaymentMethod != null) {
                  final currentName = selectedPaymentMethod!['name']
                      ?.toString().toUpperCase();
                  final stillValid = _allowedPaymentMethods.any(
                      (m) => m.toUpperCase() == currentName);
                  if (!stillValid) selectedPaymentMethod = null;
                }
              });
            },
          ),
        ),
        const SizedBox(height: 15),
        _buildLabel("Payment Method*", isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(7),
          child: _buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_payment_method_dropdown'),
            focusNode: paymentMethodFocus,
            hint: "Select an option",
            value: selectedPaymentMethod,
            items: _getFilteredPaymentMethods(provider),
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) => setState(() => selectedPaymentMethod = val),
          ),
        ),
      ],
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftColumn,
          const SizedBox(height: 15),
          rightColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leftColumn),
        const SizedBox(width: 30),
        Expanded(child: rightColumn),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomBackButton(
          onPressed: () {
            sideBarController.index.value = 93;
          },
          text: 'All Expenses',
        ),
        Text(
          "Create Expense",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              onTap: () {
                sideBarController.index.value = 93;
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  "Expenses",
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
            Text(
              "Create",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                ColorManager.kPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade300, thickness: 0.8),
      ],
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: text.replaceAll('*', ''),
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.1,
            ColorManager.textColor,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: " *",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledTextField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeightManager.medium,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required FocusNode focusNode,
  }) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        return BuildBoxShadowContainer(
          height: 42,
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField(FocusNode focusNode) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 42,
      child: CalendarPickerTableCell(
        focusNode: focusNode,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: today,
        onDateSelected: (DateTime date) {
          if (date.isAfter(today)) {
            showScaffoldError(
              context: context,
              message: "Future dates cannot be selected",
            );
            return;
          }
          setState(() {
            selectedDate = date;
          });
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    Key? key,
    FocusNode? focusNode,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required Function(T?) onChanged,
  }) {
    return CustomDropDownWithSearch<T>(
      key: key,
      focusNode: focusNode,
      hintText: hint,
      value: value,
      items: items,
      onChanged: onChanged,
      displayText: displayText,
      showName: false,
      height: 42,
      autofocus: false,
    );
  }

  Widget _buildAmountField(FocusNode focusNode) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        final currency = Provider.of<AppSettingsProvider>(context).appSettings?.currency ?? "";
        return BuildBoxShadowContainer(
          height: 42,
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: amountController,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            validator: (val) {
              if (val == null || val.isEmpty) return "Please enter amount";
              if (double.tryParse(val) == null) return "Please enter a valid number";
              return null;
            },
            decoration: InputDecoration(
              hintText: "Enter amount",
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Text(
                  currency,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.1,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesField(FocusNode focusNode) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        return BuildBoxShadowContainer(
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: notesController,
            focusNode: focusNode,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Write notes here...",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final isPhone = _isPhone(context);

    final createButton = CustomRoundButtonAdvanced(
      title: "Create",
      fct: () => _submitForm(createAnother: false),
      width: isPhone ? double.infinity : 100,
      height: 40,
      fontSize: 12,
      radius: 5,
      isLoading: _isSubmitting,
      focusNode: createBtnFocus,
    );

    final createAnotherButton = CustomRoundButtonAdvanced(
      title: "Create & create another",
      fct: () => _submitForm(createAnother: true),
      width: isPhone ? double.infinity : 170,
      height: 40,
      fontSize: 12,
      radius: 5,
      boxColor: Colors.white,
      textColor: ColorManager.textColor,
      borderColor: Colors.grey.shade300,
      isLoading: _isSubmitting,
      focusNode: createAnotherBtnFocus,
    );

    final cancelButton = CustomRoundButtonAdvanced(
      title: "Cancel",
      fct: () {
        sideBarController.index.value = 93;
      },
      width: isPhone ? double.infinity : 100,
      height: 40,
      fontSize: 12,
      radius: 5,
      boxColor: Colors.transparent,
      textColor: ColorManager.textColor,
      borderColor: Colors.transparent,
      focusNode: cancelBtnFocus,
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          createButton,
          const SizedBox(height: 10),
          createAnotherButton,
          const SizedBox(height: 10),
          cancelButton,
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        createButton,
        createAnotherButton,
        cancelButton,
      ],
    );
  }
}

