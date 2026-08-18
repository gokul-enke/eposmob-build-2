import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierAddressViewWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierAddressViewWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierAddressViewWidget> createState() =>
      _SupplierAddressViewWidgetState();
}

class _SupplierAddressViewWidgetState extends State<SupplierAddressViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildAddressContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        children: [
          // Address Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: ColorManager.kPrimaryColor.withOpacity(0.2),
                  width: 2),
            ),
            child: const Icon(
              Icons.location_on,
              size: 32,
              color: ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(width: 16),
          // Address Header Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'supplier_profile.addr_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s20,
                    0,
                    ColorManager.kTitleTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'supplier_profile.addr_supplier_prefix'.tr} ${widget.supplier.name ?? "N/A"}',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s14,
                    0,
                    ColorManager.kGreyColor,
                  ),
                ),
              ],
            ),
          ),
          // Address Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ColorManager.kButtonBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'supplier_profile.addr_badge_business'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.30,
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address Information Card
            _buildInfoCard(
              title: 'supplier_profile.addr_card_title'.tr,
              icon: Icons.location_on_outlined,
              children: [
                _buildInfoRow(
                  icon: Icons.place_outlined,
                  label: 'supplier_profile.label_address'.tr,
                  value: widget.supplier.address ?? 'supplier_profile.not_provided'.tr,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'supplier_profile.label_phone'.tr,
                  value: widget.supplier.phone ?? 'supplier_profile.not_provided'.tr,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: 'supplier_profile.label_email'.tr,
                  value: widget.supplier.email ?? 'supplier_profile.not_provided'.tr,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kSecondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kPrimaryWithOpacity10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.30,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryWithOpacity10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: ColorManager.kPrimaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.30,
                  ColorManager.kGreyColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.30,
                  valueColor ?? ColorManager.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
