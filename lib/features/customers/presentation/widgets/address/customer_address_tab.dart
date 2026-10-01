import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_address_controller.dart';
import 'customer_address_card.dart';
import 'customer_address_dependencies.dart';
import 'customer_address_form_dialog.dart';
import 'customer_address_header.dart';

/// Customer profile "Address" tab: the customer's saved addresses with add
/// and edit. Fills the space it is given and scrolls itself.
class CustomerAddressTab extends StatefulWidget {
  const CustomerAddressTab({
    super.key,
    required this.customer,
    this.controller,
  });

  final CustomerListModelData customer;

  /// Injected controller (tests). When null the tab builds one from the app
  /// providers and owns it.
  final CustomerAddressController? controller;

  @override
  State<CustomerAddressTab> createState() => _CustomerAddressTabState();
}

class _CustomerAddressTabState extends State<CustomerAddressTab> {
  late final CustomerAddressController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        createCustomerAddressController(context, widget.customer);
    _controller.reload();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _openForm({Address? address}) async {
    final saved = await showCustomerAddressFormDialog(
      context: context,
      customer: _controller.customer,
      address: address,
      controller: _controller,
    );
    // The saved address is already in the list; refresh for server-side
    // fields (state / district / pincode labels).
    if (saved != null && mounted) await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final gutter = compact ? AppSpacing.md : AppSpacing.xxl;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final busy = _controller.isLoading;
        return ListView(
          padding: EdgeInsets.all(gutter),
          children: [
            CustomerAddressHeader(
              customerName: _controller.customer.name,
              compact: compact,
              refreshFailed: _controller.loadFailed && !busy,
              onRefresh: busy ? null : _controller.reload,
              onAdd: busy ? null : () => _openForm(),
            ),
            const SizedBox(height: AppSpacing.xl),
            ..._body(),
          ],
        );
      },
    );
  }

  List<Widget> _body() {
    if (_controller.isLoading) {
      return const [SizedBox(height: 200, child: AppLoadingView())];
    }
    final addresses = _controller.addresses;
    if (addresses.isEmpty) {
      return [
        AppEmptyState(
          icon: Icons.location_off_outlined,
          title: 'customer_address.no_address_found'.tr,
          action: AppOutlinedButton(
            icon: Icons.add_rounded,
            label: 'customer_address.btn_add_new'.tr,
            onPressed: () => _openForm(),
          ),
        ),
      ];
    }
    return [
      for (final address in addresses)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: CustomerAddressCard(
            address: address,
            onEdit: () => _openForm(address: address),
          ),
        ),
    ];
  }
}
