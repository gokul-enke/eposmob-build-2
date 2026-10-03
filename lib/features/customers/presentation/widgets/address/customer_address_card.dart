import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import 'address_type_labels.dart';

/// One saved address: type in the header, then address, district, city and
/// pincode. Shows an edit button when [onEdit] is set.
class CustomerAddressCard extends StatelessWidget {
  const CustomerAddressCard({super.key, required this.address, this.onEdit});

  final Address address;
  final VoidCallback? onEdit;

  static String _orNotProvided(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? 'customer_address.not_provided'.tr : text;
  }

  @override
  Widget build(BuildContext context) {
    final pincode = (address.pincode?.trim().isNotEmpty ?? false)
        ? address.pincode
        : address.pincodeId?.toString();
    return SectionCard(
      icon: Icons.location_on_outlined,
      title: 'customer_address.title_address'
          .trParams({'type': customerAddressTypeLabel(address.type)}),
      trailing: onEdit == null
          ? null
          : AppSquareIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'customer_address.title_edit'.tr,
              onPressed: onEdit,
              size: 36,
              iconSize: 18,
              foreground: AppColors.primary,
            ),
      child: InfoGrid(
        minColumnWidth: 220,
        maxColumns: 2,
        children: [
          InfoRow(
            icon: Icons.place_outlined,
            label: 'customer_address.label_address'.tr,
            value: _orNotProvided(address.address),
          ),
          InfoRow(
            icon: Icons.map_outlined,
            label: 'customer_address.label_district'.tr,
            value: _orNotProvided(address.district),
          ),
          InfoRow(
            icon: Icons.location_city_outlined,
            label: 'customer_address.label_city'.tr,
            value: _orNotProvided(address.city),
          ),
          InfoRow(
            icon: Icons.pin_drop_outlined,
            label: 'customer_address.label_pincode'.tr,
            value: _orNotProvided(pincode),
          ),
        ],
      ),
    );
  }
}
