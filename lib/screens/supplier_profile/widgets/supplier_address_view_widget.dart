import 'package:flutter/material.dart';
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
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.location_on,
              color: ColorManager.kPrimaryColor, size: 28),
          const SizedBox(width: 12),
          Text(
            'Supplier Address',
            style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddressCard(),
          const SizedBox(height: 24),
          _buildMapPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business,
                    color: ColorManager.kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.supplier.name ?? 'Supplier Name',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s18, 0, ColorManager.kTitleTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registered Business Address',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0, ColorManager.kGreyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAddressDetail(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: widget.supplier.address ?? 'No address provided',
          ),
          const SizedBox(height: 16),
          _buildAddressDetail(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: widget.supplier.phone ?? 'No phone provided',
          ),
          const SizedBox(height: 16),
          _buildAddressDetail(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.supplier.email ?? 'No email provided',
          ),
        ],
      ),
    );
  }

  Widget _buildAddressDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ColorManager.kGreyColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                    0, ColorManager.kGreyColor),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0,
                  ColorManager.kTitleTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Expanded(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
          color: ColorManager.kBgLightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorManager.kBgDarkColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined,
                size: 48, color: ColorManager.kGreyColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Map View',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
                  0, ColorManager.kTitleTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Location map would be displayed here',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
                  0, ColorManager.kGreyColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Open in maps
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Open in Maps',
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s14, 0, Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
