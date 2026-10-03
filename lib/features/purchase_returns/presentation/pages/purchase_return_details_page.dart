import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import '../../domain/models/purchase_return.dart';
import '../state/purchase_return_detail_controller.dart';
import '../widgets/details/purchase_return_detail_view.dart';

class PurchaseReturnDetailsPage extends StatefulWidget {
  const PurchaseReturnDetailsPage({super.key, required this.returnData});
  final PurchaseReturnData returnData;
  @override
  State<PurchaseReturnDetailsPage> createState() =>
      _PurchaseReturnDetailsPageState();
}

class _PurchaseReturnDetailsPageState extends State<PurchaseReturnDetailsPage> {
  late final PurchaseReturnDetailController controller;
  @override
  void initState() {
    super.initState();
    final purchases = context.read<PurchaseProvider>();
    final auth = context.read<AuthModel>();
    controller = PurchaseReturnDetailController(
        initial: widget.returnData,
        fetch: (id) => purchases.fetchPurchaseReturnDetails(
            accessToken: auth.token ?? '', returnId: id));
    if (widget.returnData.items?.isEmpty ?? true)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.loadDetails();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PurchaseReturnDetailView(
                context: context, controller: controller, currency: currency)
            .build());
  }
}
