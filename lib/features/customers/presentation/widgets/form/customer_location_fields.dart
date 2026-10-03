import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../state/customer_form_controller.dart';

/// Building, country, street address (with "pick on map") and the
/// state → district → pincode dropdowns.
class CustomerAddressSection extends StatelessWidget {
  const CustomerAddressSection({
    super.key,
    required this.form,
    required this.onPickOnMap,
  });

  final CustomerFormController form;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customers.form.section_address'.tr,
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ResponsiveFieldGrid(
            maxColumns: 2,
            children: [
              AppTextField(
                controller: form.building,
                label: 'add_customer.label_building'.tr,
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                controller: form.country,
                label: 'add_customer.label_country'.tr,
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StreetAddressField(form: form, onPickOnMap: onPickOnMap),
          const SizedBox(height: 16),
          CustomerLocationFields(location: form.location),
        ],
      ),
    );
  }
}

class _StreetAddressField extends StatelessWidget {
  const _StreetAddressField({required this.form, required this.onPickOnMap});

  final CustomerFormController form;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: FieldLabel(label: 'add_customer.label_street_address'.tr),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTextStyles.button,
              ),
              icon: const Icon(Icons.location_pin, size: 14),
              label: Text('add_customer.btn_pick_on_map'.tr),
              onPressed: onPickOnMap,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: form.streetAddress,
          keyboardType: TextInputType.streetAddress,
          minLines: 2,
          maxLines: 2,
          style: AppTextStyles.input,
          decoration: AppInputDecoration.of(
            hint: 'add_customer.hint_street_address'.tr,
          ),
        ),
      ],
    );
  }
}

/// The searchable state, district and pincode dropdowns. Each level is
/// disabled until the previous one is chosen.
class CustomerLocationFields extends StatelessWidget {
  const CustomerLocationFields({super.key, required this.location});

  final CustomerLocationSelection location;

  static String _label(List<MapEntry<String, String>> entries, String key) {
    for (final entry in entries) {
      if (entry.key == key) return entry.value;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final states = location.states;
    final districts = location.districts;
    final pincodes = location.pincodes;
    final hasState = location.stateId != null;
    final hasDistrict = location.districtId != null;

    return ResponsiveFieldGrid(
      children: [
        AppSearchDropdownField<String>(
          label: 'add_customer.label_states'.tr,
          hint: 'add_customer.hint_select_state'.tr,
          value: location.stateId,
          items: [for (final entry in states) entry.key],
          itemLabel: (key) => _label(states, key),
          onChanged: location.selectState,
        ),
        AppSearchDropdownField<String>(
          label: 'add_customer.label_district'.tr,
          hint: !hasState
              ? 'add_customer.hint_select_state_first'.tr
              : districts.isEmpty
                  ? 'add_customer.hint_no_districts'.tr
                  : 'add_customer.hint_select_district'.tr,
          value: location.districtId,
          loading: location.loadingDistricts,
          enabled: hasState,
          items: [for (final entry in districts) entry.key],
          itemLabel: (key) => _label(districts, key),
          onChanged: location.selectDistrict,
        ),
        AppSearchDropdownField<String>(
          label: 'add_customer.label_pincode'.tr,
          hint: !hasDistrict
              ? 'add_customer.hint_select_district_first'.tr
              : pincodes.isEmpty
                  ? 'add_customer.hint_no_pincodes'.tr
                  : 'add_customer.hint_select_pincode'.tr,
          value: location.pincodeId,
          loading: location.loadingPincodes,
          enabled: hasDistrict,
          items: [for (final entry in pincodes) entry.key],
          itemLabel: (key) => _label(pincodes, key),
          onChanged: location.selectPincode,
        ),
      ],
    );
  }
}
