import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_address_controller.dart';
import 'address_type_labels.dart';

/// Id/label pairs for the state, district and pincode dropdowns.
typedef LocationOptions = List<MapEntry<String, String>>;

/// Add / edit address form. Pure UI: location options come in, the request
/// body ([buildAddressPayload]) goes out through [onSubmit].
class CustomerAddressForm extends StatefulWidget {
  const CustomerAddressForm({
    super.key,
    required this.customer,
    required this.states,
    required this.districts,
    required this.pincodes,
    required this.onSubmit,
    required this.onCancel,
    this.address,
    this.onStateSelected,
    this.onDistrictSelected,
    this.requirePincode = false,
    this.busy = false,
  });

  final CustomerListModelData customer;

  /// The address being edited; null adds a new one.
  final Address? address;
  final LocationOptions states;
  final LocationOptions districts;
  final LocationOptions pincodes;

  /// Called with the new state id so the host can load its districts.
  final ValueChanged<String>? onStateSelected;

  /// Called with the new district id so the host can load its pincodes.
  final ValueChanged<String>? onDistrictSelected;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final VoidCallback onCancel;
  final bool requirePincode;
  final bool busy;

  @override
  State<CustomerAddressForm> createState() => _CustomerAddressFormState();
}

class _CustomerAddressFormState extends State<CustomerAddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _landmark;

  String? _stateId;
  String? _districtId;
  String? _pincodeId;
  late String _type;

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _address = TextEditingController(text: address?.address ?? '');
    _city = TextEditingController(text: address?.city ?? '');
    _landmark = TextEditingController(text: address?.landmark ?? '');
    _stateId = address?.stateId?.toString();
    _districtId = address?.districtId?.toString();
    _pincodeId = address?.pincodeId?.toString();
    final type = address?.type;
    _type = type == null || type.isEmpty ? kDefaultCustomerAddressType : type;
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _landmark.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(
      buildAddressPayload(
        customer: widget.customer,
        existing: widget.address,
        address: _address.text,
        city: _city.text,
        landmark: _landmark.text,
        type: _type,
        stateId: _stateId,
        districtId: _districtId,
        pincodeId: _pincodeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final required = 'customer_address.required'.tr;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ResponsiveFieldGrid(
            maxColumns: 2,
            children: [
              _LocationDropdown(
                fieldKey: const ValueKey('address_state_field'),
                label: 'customer_address.label_state'.tr,
                hint: 'customer_address.hint_state'.tr,
                value: _stateId,
                options: widget.states,
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _stateId = id;
                    _districtId = null;
                    _pincodeId = null;
                  });
                  widget.onStateSelected?.call(id);
                },
              ),
              _LocationDropdown(
                fieldKey: const ValueKey('address_district_field'),
                label: 'customer_address.label_district'.tr,
                hint: 'customer_address.hint_district'.tr,
                value: _districtId,
                options: widget.districts,
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _districtId = id;
                    _pincodeId = null;
                  });
                  widget.onDistrictSelected?.call(id);
                },
              ),
              _LocationDropdown(
                fieldKey: const ValueKey('address_pincode_field'),
                label: 'customer_address.label_pincode'.tr,
                hint: 'customer_address.hint_pincode'.tr,
                value: _pincodeId,
                options: widget.pincodes,
                required: widget.requirePincode,
                validator: (_) =>
                    widget.requirePincode && (_pincodeId ?? '').isEmpty
                        ? 'customer_address.pincode_required'.tr
                        : null,
                onChanged: (id) => setState(() => _pincodeId = id),
              ),
              AppTextField(
                fieldKey: const ValueKey('city_field'),
                controller: _city,
                label: 'customer_address.label_city'.tr,
                hint: 'customer_address.hint_city'.tr,
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            fieldKey: const ValueKey('address_field'),
            controller: _address,
            label: 'customer_address.label_address'.tr,
            hint: 'customer_address.hint_address'.tr,
            required: true,
            maxLines: 2,
            validator: (v) => (v ?? '').isEmpty ? required : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          ResponsiveFieldGrid(
            maxColumns: 2,
            children: [
              AppTextField(
                fieldKey: const ValueKey('landmark_field'),
                controller: _landmark,
                label: 'customer_address.label_landmark'.tr,
                hint: 'customer_address.hint_landmark'.tr,
              ),
              AppDropdownField<String>(
                label: 'customer_address.label_address_type'.tr,
                required: true,
                value: _type,
                items: [
                  for (final type in {...kCustomerAddressTypes, _type})
                    DropdownMenuItem(
                      value: type,
                      child: Text(customerAddressTypeLabel(type)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) => FormActionsBar(
              stacked: constraints.maxWidth < 420,
              busy: widget.busy,
              submitIcon: Icons.check_rounded,
              submitLabel: widget.busy
                  ? 'customer_address.btn_saving'.tr
                  : _isEdit
                      ? 'customer_address.btn_update_address'.tr
                      : 'customer_address.btn_save_address'.tr,
              onSubmit: _submit,
              cancelLabel: 'customer_address.btn_cancel'.tr,
              onCancel: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

/// State / district / pincode picker. Drops [value] when it is not (yet) in
/// [options] so the dropdown never asserts while options load.
class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.required = false,
    this.validator,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final String? value;
  final LocationOptions options;
  final ValueChanged<String?> onChanged;
  final bool required;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final known = options.any((e) => e.key == value);
    return KeyedSubtree(
      key: fieldKey,
      child: AppDropdownField<String>(
        label: label,
        hint: hint,
        required: required,
        value: known ? value : null,
        validator: validator,
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option.key,
              child: Text(option.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
