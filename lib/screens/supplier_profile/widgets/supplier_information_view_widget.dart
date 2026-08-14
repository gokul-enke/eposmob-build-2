import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/supplier.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class SupplierInformationViewWidget extends StatefulWidget {
  final Size size;
  final Supplier? supplier;
  final VoidCallback? onEditSupplier;
  final VoidCallback? onViewOrders;
  final VoidCallback? onMessage;

  const SupplierInformationViewWidget({
    Key? key,
    required this.size,
    required this.supplier,
    this.onEditSupplier,
    this.onViewOrders,
    this.onMessage,
  }) : super(key: key);

  @override
  State<SupplierInformationViewWidget> createState() =>
      _SupplierInformationViewWidgetState();
}

class _SupplierInformationViewWidgetState
    extends State<SupplierInformationViewWidget> {
  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            // Header Section
            Container(
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
                  // Avatar Circle
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
                      Icons.business,
                      size: 32,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Supplier Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.supplier?.name ?? 'supplier_profile.label_supplier_name'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s20,
                            0,
                            ColorManager.kTitleTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ID: ${widget.supplier?.id?.toString() ?? "N/A"}",
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
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ColorManager.kSuccessColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'supplier_profile.view_status_active'.tr,
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
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact Information Card
                      _buildInfoCard(
                        title: 'supplier_profile.view_contact_title'.tr,
                        icon: Icons.contact_phone,
                        children: [
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'supplier_profile.label_email'.tr,
                            value: widget.supplier?.email ?? 'supplier_profile.not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'supplier_profile.label_phone'.tr,
                            value: widget.supplier?.phone ?? 'supplier_profile.not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_android_outlined,
                            label: 'supplier_profile.view_label_alt_phone'.tr,
                            value: widget.supplier?.altPhone ?? 'supplier_profile.not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.receipt_long_outlined,
                            label: 'supplier_profile.view_label_tax_number'.tr,
                            value: widget.supplier?.taxNumber ?? 'supplier_profile.not_provided'.tr,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Account Information Card
                      _buildInfoCard(
                        title: 'supplier_profile.view_account_title'.tr,
                        icon: Icons.account_circle,
                        children: [
                          _buildInfoRow(
                            icon: Icons.account_balance_wallet,
                            label: 'supplier_profile.view_label_current_balance'.tr,
                            value: widget.supplier?.currentBalance
                                    ?.toStringAsFixed(2) ??
                                "0.00",
                            valueColor:
                                (widget.supplier?.currentBalance ?? 0) >= 0
                                    ? ColorManager.kSuccessColor
                                    : Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.payment,
                            label: 'supplier_profile.view_label_payment_type'.tr,
                            value: widget.supplier?.paymentType ?? "N/A",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.info_outline,
                            label: 'supplier_profile.view_label_balance_status'.tr,
                            value: widget.supplier?.balanceStatus ?? "N/A",
                            valueColor: widget.supplier?.paymentType == 'to_pay'
                                ? Colors.red
                                : widget.supplier?.paymentType == 'to_receive'
                                    ? Colors.green
                                    : ColorManager.textColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.category,
                            label: 'supplier_profile.view_label_product_categories'.tr,
                            value: widget.supplier?.productCategories ?? "N/A",
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Address Information Card
                      _buildInfoCard(
                        title: 'supplier_profile.view_address_title'.tr,
                        icon: Icons.location_on,
                        children: [
                          _buildInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'supplier_profile.label_address'.tr,
                            value: widget.supplier?.address ?? 'supplier_profile.not_provided'.tr,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildInfoCard(
                        title: 'supplier_profile.view_kyc_title'.tr,
                        icon: Icons.verified_user_outlined,
                        children: _buildKycRows(),
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      _buildQuickActions(),
                    ],
                  ),
                ),
              ),
            ),
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
                    FontSize.s16,
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

  List<Widget> _buildKycRows() {
    final entries = widget.supplier?.kyc ?? const <SupplierKyc>[];
    if (entries.isEmpty) {
      return [
        _buildInfoRow(
          icon: Icons.verified_user_outlined,
          label: 'supplier_profile.view_label_kyc'.tr,
          value: 'supplier_profile.not_provided'.tr,
        ),
      ];
    }

    return entries
        .map(
          (entry) => _buildInfoRow(
            icon: Icons.badge_outlined,
            label: entry.key,
            value: entry.value.isEmpty ? 'supplier_profile.not_provided'.tr : entry.value,
          ),
        )
        .toList();
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
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.30,
                  ColorManager.kGreyColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
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

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kPrimaryWithOpacity10),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'supplier_profile.view_quick_actions'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'supplier_profile.view_btn_edit'.tr,
                  color: ColorManager.kPrimaryColor,
                  onTap: widget.onEditSupplier ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history_outlined,
                  label: 'supplier_profile.view_btn_orders'.tr,
                  color: ColorManager.kButtonGreen,
                  onTap: widget.onViewOrders ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.business_outlined,
                  label: 'supplier_profile.view_btn_contact'.tr,
                  color: ColorManager.kButtonBlue,
                  onTap: widget.onMessage ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.30,
                color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
