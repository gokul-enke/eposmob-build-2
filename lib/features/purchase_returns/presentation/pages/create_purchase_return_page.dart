import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import '../state/create_purchase_return_controller.dart';
import '../widgets/form/purchase_return_form_view.dart';
import '../navigation/purchase_return_navigation.dart';

class CreatePurchaseReturnPage extends StatefulWidget {
  const CreatePurchaseReturnPage({super.key});
  @override
  State<CreatePurchaseReturnPage> createState() =>
      _CreatePurchaseReturnPageState();
}

class _CreatePurchaseReturnPageState extends State<CreatePurchaseReturnPage> {
  late final CreatePurchaseReturnController controller;
  @override
  void initState() {
    super.initState();
    final purchases = context.read<PurchaseProvider>();
    final auth = context.read<AuthModel>();
    final master = context.read<MasterDataProvider>();
    final repository = purchases.purchaseReturnProvider.repository;
    controller = CreatePurchaseReturnController(
      fetchVouchers: (page) =>
          repository.fetchVouchers(accessToken: auth.token ?? '', page: page),
      fetchItems: (id) => purchases.purchaseReturnProvider
          .fetchItems(accessToken: auth.token ?? '', purchaseVoucherId: id),
      fetchPaymentMethods: () async {
        final cached = master.paymentMethods;
        return cached != null && cached.isNotEmpty
            ? cached
            : await master.fetchPaymentMethods() ?? <MasterDataValue>[];
      },
      create: (
              {required purchaseVoucherId,
              required returnDate,
              required items,
              required hasPayment,
              paidAmount,
              paymentMethod}) =>
          purchases.createPurchaseReturn(
              accessToken: auth.token ?? '',
              purchaseVoucherId: purchaseVoucherId,
              returnDate: returnDate,
              items: items,
              hasPayment: hasPayment,
              paidAmount: paidAmount,
              paymentMethod: paymentMethod),
    );
    controller.loadVouchers();
    controller.loadPaymentMethods();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: controller.returnDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (mounted && picked != null)
      controller.update(() => controller.returnDate = picked);
  }

  Future<void> _submit() async {
    if (controller.isSubmitting ||
        controller.returnItems.isEmpty ||
        controller.selectedVoucher?.id == null) return;
    if (!controller.hasValidPayment) {
      showScaffoldError(
          context: context,
          message:
              '${'purchase_return.return_amount'.tr}: 0 - ${controller.totalReturnAmount.toStringAsFixed(2)}');
      return;
    }
    final result = await controller.submitReturn();
    if (!mounted || result == null) return;
    if (result['status'] == 'success') {
      showScaffold(
          context: context, message: 'purchase_return.return_created'.tr);
      PurchaseReturnNavigation.openList();
    } else {
      showScaffoldError(
          context: context,
          message: result['message'] ?? 'purchase_return.err_create'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PurchaseReturnFormView(
                context: context,
                controller: controller,
                currency: currency,
                onBack: PurchaseReturnNavigation.openList,
                onSubmit: _submit,
                onPickDate: _pickDate)
            .build());
  }
}
