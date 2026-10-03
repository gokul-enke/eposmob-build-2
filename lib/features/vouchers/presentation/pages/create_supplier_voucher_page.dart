import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/vouchers/presentation/state/supplier_voucher_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:provider/provider.dart';

import '../navigation/voucher_navigation.dart';
import '../state/supplier_voucher_form_controller.dart';
import '../widgets/form/supplier_voucher_form_view.dart';

class CreateSupplierVoucherPage extends StatefulWidget {
  const CreateSupplierVoucherPage({super.key});
  @override
  State<CreateSupplierVoucherPage> createState() =>
      _CreateSupplierVoucherPageState();
}

class _CreateSupplierVoucherPageState extends State<CreateSupplierVoucherPage> {
  final _formKey = GlobalKey<FormState>();
  late final SupplierVoucherProvider _provider;
  late final AuthModel _auth;
  late final SupplierVoucherFormController form;
  @override
  void initState() {
    super.initState();
    _provider = context.read<SupplierVoucherProvider>();
    _auth = context.read<AuthModel>();
    final master = context.read<MasterDataProvider>();
    form = SupplierVoucherFormController(
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
      builder: (context, _) => SupplierVoucherFormView(
              context: context,
              form: form,
              formKey: _formKey,
              onSubmit: _submitVoucher,
              onClose: VoucherNavigation.backFromSupplierCreate)
          .build());
  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (form.selectedSupplierId == null) {
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.select_supplier_required'.tr);
      return;
    }
    if (form.selectedType == null) {
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.select_type_required'.tr);
      return;
    }
    if (form.selectedStatus == null) {
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.select_status_required'.tr);
      return;
    }
    if (form.selectedPaymentMethod == null) {
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.select_payment_method_required'.tr);
      return;
    }
    if (form.voucherItems.isEmpty ||
        form.voucherItems
            .every((item) => item.itemNameController.text.isEmpty)) {
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.add_at_least_one_item_required'.tr);
      return;
    }

    if (form.isLoading) return;
    form.update(() => form.isLoading = true);

    try {
      String? accessToken = _auth.token;

      List<Map<String, dynamic>> items = form.voucherItems
          .where((item) => item.itemNameController.text.isNotEmpty)
          .map((item) => {
                'item_name': item.itemNameController.text,
                'quantity': double.tryParse(item.quantityController.text) ?? 1,
                'unit_amount':
                    double.tryParse(item.unitAmountController.text) ?? 0,
                'tax': double.tryParse(item.taxController.text) ?? 0,
                'total_amount': double.tryParse(item.totalController.text) ?? 0,
              })
          .toList();

      final result = await _provider.createVoucher(
        supplierId: form.selectedSupplierId!,
        type: form.selectedType!,
        amount: double.tryParse(form.totalAmountController.text) ?? 0,
        voucherDate: DateFormat('yyyy-MM-dd').format(form.selectedVoucherDate),
        dueDate: DateFormat('yyyy-MM-dd')
            .format(form.selectedVoucherDate), //only voucher date
        status: form.selectedStatus!,
        paymentMethodId: form.getPaymentMethodId(form.selectedPaymentMethod),
        voucherItems: items,
        accessToken: accessToken ?? '',
      );

      if (!mounted) return;
      if (result['success']) {
        showScaffold(
          context: context,
          message:
              result['message'] ?? 'supplier_voucher.created_successfully'.tr,
        );
        VoucherNavigation.backFromSupplierCreate();
      } else {
        showScaffoldError(
          context: context,
          message: result['message'] ?? 'supplier_voucher.create_failed'.tr,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
          context: context,
          message: 'supplier_voucher.error_generic'
              .tr
              .replaceAll('@error', e.toString()));
    } finally {
      form.update(() => form.isLoading = false);
    }
  }
}
