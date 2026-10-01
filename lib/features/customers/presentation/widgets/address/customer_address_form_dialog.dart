import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_address_controller.dart';
import 'customer_address_dependencies.dart';
import 'customer_address_form.dart';

/// Opens the add / edit address form in a dialog and resolves with the saved
/// address, or null when cancelled.
///
/// Saves through [controller] when given (the address tab passes its own so
/// the list updates); otherwise a controller is created from the app
/// providers for this dialog only.
Future<Address?> showCustomerAddressFormDialog({
  required BuildContext context,
  required CustomerListModelData customer,
  Address? address,
  bool requirePincode = false,
  CustomerAddressController? controller,
}) {
  return showDialog<Address>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AppDialog(
      title: address == null
          ? 'customer_address.title_add'.tr
          : 'customer_address.title_edit'.tr,
      subtitle: customer.name,
      maxWidth: 820,
      child: CustomerAddressFormHost(
        customer: customer,
        address: address,
        requirePincode: requirePincode,
        controller: controller,
        onSaved: (saved) => Navigator.of(dialogContext).pop(saved),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );
}

/// Connects [CustomerAddressForm] to [LocationProvider] (state, district
/// and pincode options) and to a [CustomerAddressController] (save).
class CustomerAddressFormHost extends StatefulWidget {
  const CustomerAddressFormHost({
    super.key,
    required this.customer,
    required this.onSaved,
    required this.onCancel,
    this.address,
    this.requirePincode = false,
    this.controller,
  });

  final CustomerListModelData customer;
  final Address? address;
  final bool requirePincode;
  final CustomerAddressController? controller;
  final ValueChanged<Address> onSaved;
  final VoidCallback onCancel;

  @override
  State<CustomerAddressFormHost> createState() =>
      _CustomerAddressFormHostState();
}

class _CustomerAddressFormHostState extends State<CustomerAddressFormHost> {
  CustomerAddressController? _ownController;
  late final LocationProvider _locations;
  late final String? _token;

  CustomerAddressController get _controller =>
      widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownController =
          createCustomerAddressController(context, widget.customer);
    }
    _locations = Provider.of<LocationProvider>(context, listen: false);
    _token = Provider.of<AuthModel>(context, listen: false).token;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocations());
  }

  void _loadLocations() {
    final token = _token;
    if (!mounted || token == null) return;
    final address = widget.address;
    _locations.listAllStates(token);
    final stateId = address?.stateId?.toString();
    if (stateId != null) {
      _locations.listAllDistricts(accessToken: token, stateId: stateId);
    }
    final districtId = address?.districtId?.toString();
    if (districtId != null) {
      _locations.listAllPincodes(accessToken: token, districtId: districtId);
    }
  }

  void _onStateSelected(String stateId) {
    final token = _token;
    if (token == null) return;
    _locations.listAllDistricts(accessToken: token, stateId: stateId);
  }

  void _onDistrictSelected(String districtId) {
    final token = _token;
    if (token == null) return;
    _locations.listAllPincodes(accessToken: token, districtId: districtId);
  }

  Future<void> _submit(Map<String, dynamic> data) async {
    final result = await _controller.save(data: data, existing: widget.address);
    if (!mounted) return;
    final saved = result.address;
    if (result.success && saved != null) {
      AppToast.success(context, result.message);
      widget.onSaved(saved);
    } else {
      AppToast.error(context, result.message);
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationProvider>();
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => CustomerAddressForm(
        customer: widget.customer,
        address: widget.address,
        requirePincode: widget.requirePincode,
        states: locations.stateList,
        districts: locations.districtList,
        pincodes: locations.pincodeList,
        onStateSelected: _onStateSelected,
        onDistrictSelected: _onDistrictSelected,
        busy: _controller.isSaving,
        onSubmit: _submit,
        onCancel: widget.onCancel,
      ),
    );
  }
}
