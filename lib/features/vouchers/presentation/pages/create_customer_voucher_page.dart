import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/vouchers/presentation/state/customer_voucher_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:provider/provider.dart';

import '../navigation/voucher_navigation.dart';
import '../state/customer_voucher_form_controller.dart';
import '../widgets/form/customer_voucher_form_view.dart';

class CreateCustomerVoucherPage extends StatefulWidget {
  const CreateCustomerVoucherPage({super.key});
  @override
  State<CreateCustomerVoucherPage> createState() =>
      _CreateCustomerVoucherPageState();
}

class _CreateCustomerVoucherPageState extends State<CreateCustomerVoucherPage> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerVoucherProvider _provider;
  late final AuthModel _auth;
  late final CustomerVoucherFormController form;
  @override
  void initState() {
    super.initState();
    _provider = context.read<CustomerVoucherProvider>();
    _auth = context.read<AuthModel>();
    final master = context.read<MasterDataProvider>();
    form = CustomerVoucherFormController(
        loadChoices: () => _provider.repository.choices(_auth.token),
        loadPayments: master.fetchPaymentMethods);
    form.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(form.typeFocus);
    });
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: form,
      builder: (context, _) => CustomerVoucherFormView(
              context: context,
              form: form,
              formKey: _formKey,
              onSubmit: _submitVoucher,
              onClose: VoucherNavigation.openCustomerList)
          .build());
  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (form.selectedCustomerId == null) {
      showScaffoldError(
          context: context,
          message: 'customer_voucher.select_customer_required'.tr);
      return;
    }
    if (form.selectedType == null) {
      showScaffoldError(
          context: context,
          message: 'customer_voucher.select_type_required'.tr);
      return;
    }
    if (form.selectedStatus == null) {
      showScaffoldError(
          context: context,
          message: 'customer_voucher.select_status_required'.tr);
      return;
    }
    if (form.selectedPaymentMethod == null) {
      showScaffoldError(
          context: context,
          message: 'customer_voucher.select_payment_method_required'.tr);
      return;
    }
    if (form.voucherItems.isEmpty ||
        form.voucherItems.every((item) => item.itemName.isEmpty)) {
      showScaffoldError(
          context: context,
          message: 'customer_voucher.add_at_least_one_item_required'.tr);
      return;
    }

    if (form.isLoading) return;
    form.update(() => form.isLoading = true);

    try {
      String? accessToken = _auth.token;

      List<Map<String, dynamic>> items = form.voucherItems
          .where((item) => item.itemName.isNotEmpty)
          .map((item) => {
                'item_name': item.itemName,
                'quantity': double.tryParse(item.quantity) ?? 1,
                'unit_amount': double.tryParse(item.unitAmount) ?? 0,
                'tax': double.tryParse(item.tax) ?? 0,
                'total_amount': double.tryParse(item.totalAmount) ?? 0,
              })
          .toList();

      final result = await _provider.createVoucher(
        type: form.selectedType!,
        amount: double.tryParse(form.totalAmountController.text) ?? 0,
        voucherDate: DateFormat('yyyy-MM-dd').format(form.selectedVoucherDate),
        dueDate: DateFormat('yyyy-MM-dd')
            .format(form.selectedVoucherDate), //only using voucher date
        status: form.selectedStatus!,
        paymentMethodId: form.getPaymentMethodId(form.selectedPaymentMethod),
        customerId: form.selectedCustomerId!,
        voucherItems: items,
        accessToken: accessToken ?? '',
      );

      if (!mounted) return;
      if (result['success']) {
        showScaffold(
          context: context,
          message:
              result['message'] ?? 'customer_voucher.created_successfully'.tr,
        );
        // Navigate back to voucher list
        VoucherNavigation.openCustomerList();
      } else {
        showScaffoldError(
          context: context,
          message: result['message'] ?? 'customer_voucher.create_failed'.tr,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
          context: context,
          message: 'customer_voucher.error_generic'
              .tr
              .replaceAll('@error', e.toString()));
    } finally {
      form.update(() => form.isLoading = false);
    }
  }
}
