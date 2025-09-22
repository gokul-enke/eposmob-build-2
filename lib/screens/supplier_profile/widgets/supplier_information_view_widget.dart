import 'package:flutter/material.dart';
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
                          widget.supplier?.name ?? "Supplier Name",
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
                      "Active",
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
                        title: "Contact Information",
                        icon: Icons.contact_phone,
                        children: [
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: "Email",
                            value: widget.supplier?.email ?? "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: "Phone",
                            value: widget.supplier?.phone ?? "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_android_outlined,
                            label: "Alt Phone",
                            value: widget.supplier?.altPhone ?? "Not provided",
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Account Information Card
                      _buildInfoCard(
                        title: "Account Information",
                        icon: Icons.account_circle,
                        children: [
                          _buildInfoRow(
                            icon: Icons.account_balance,
                            label: "Balance",
                            value: widget.supplier?.balance ?? "0",
                            valueColor: ColorManager.kSuccessColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.account_balance_wallet,
                            label: "Current Balance",
                            value: widget.supplier?.currentBalance
                                    ?.toStringAsFixed(2) ??
                                "0.00",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.payment,
                            label: "Payment Type",
                            value: widget.supplier?.paymentType ?? "N/A",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.category,
                            label: "Product Categories",
                            value: widget.supplier?.productCategories ?? "N/A",
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Address Information Card
                      _buildInfoCard(
                        title: "Address Information",
                        icon: Icons.location_on,
                        children: [
                          _buildInfoRow(
                            icon: Icons.location_on_outlined,
                            label: "Address",
                            value: widget.supplier?.address ?? "Not provided",
                          ),
                        ],
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
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ColorManager.kPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s16, 0, ColorManager.kTitleTextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
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
                  valueColor ?? ColorManager.kTitleTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16, 0,
              ColorManager.kTitleTextColor),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              icon: Icons.edit,
              label: "Edit Details",
              onPressed: widget.onEditSupplier,
            ),
            _buildActionButton(
              icon: Icons.receipt_long,
              label: "View Orders",
              onPressed: widget.onViewOrders,
            ),
            _buildActionButton(
              icon: Icons.message,
              label: "Message",
              onPressed: widget.onMessage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 120,
      height: 100,
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(0),
        padding: const EdgeInsets.all(12),
        circleRadius: 12,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ColorManager.kPrimaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0,
                  ColorManager.kTitleTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
