import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class CustomerInformationViewWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer;
  final VoidCallback? onEditCustomer;
  final VoidCallback? onViewOrders;
  final VoidCallback? onMessage;

  const CustomerInformationViewWidget({
    Key? key,
    required this.size,
    required this.customer,
    this.onEditCustomer,
    this.onViewOrders,
    this.onMessage,
  }) : super(key: key);

  @override
  State<CustomerInformationViewWidget> createState() =>
      _CustomerInformationViewWidgetState();
}

class _CustomerInformationViewWidgetState
    extends State<CustomerInformationViewWidget> {
  @override
  Widget build(BuildContext context) {
    Size size = widget.size;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final bool isZatcaPhase1Enabled = appSettings?.zatcaPhase1Enabled ?? false;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: ColorManager.kPrimaryWithOpacity10,
                borderRadius: BorderRadius.only(
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
                      Icons.person,
                      size: 32,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Customer Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer?.name ?? "Customer Name",
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s20,
                            0,
                            ColorManager.kTitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Customer Type Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (widget.customer?.customerType ?? 'B2C')
                                  .toUpperCase() ==
                              'B2B'
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: (widget.customer?.customerType ?? 'B2C')
                                      .toUpperCase() ==
                                  'B2B'
                              ? Colors.green.shade300
                              : Colors.blue.shade300),
                    ),
                    child: Text(
                      (widget.customer?.customerType ?? 'B2C').toUpperCase(),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.18,
                        (widget.customer?.customerType ?? 'B2C')
                                    .toUpperCase() ==
                                'B2B'
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                            value: widget.customer?.email ?? "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: "Phone",
                            value: widget.customer?.phone ?? "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_android_outlined,
                            label: "Alt Phone",
                            value: widget.customer?.altPhone ?? "Not provided",
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
                            icon: Icons.account_balance_wallet_outlined,
                            label: "Balance",
                            value:
                                "${widget.customer?.balance?.toStringAsFixed(2) ?? "0.00"}",
                            valueColor: (widget.customer?.balance ?? 0) >= 0
                                ? ColorManager.kSuccessColor
                                : Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.payment_outlined,
                            label: "Payment Type",
                            value: _getPaymentTypeDisplay(
                                widget.customer?.paymentType),
                            valueColor: _getPaymentTypeColor(
                                widget.customer?.paymentType),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.credit_score_outlined,
                            label: "Loyalty Points",
                            value: widget.customer?.loyaltyPoints?.toString() ??
                                "0",
                            valueColor: ColorManager.kSuccessColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.person_outlined,
                            label: "Gender",
                            value: widget.customer?.gender != null &&
                                    widget.customer!.gender!.isNotEmpty
                                ? widget.customer!.gender![0].toUpperCase() +
                                    widget.customer!.gender!.substring(1)
                                : "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: "Date of Birth",
                            value: widget.customer?.dob != null &&
                                    widget.customer!.dob!.isNotEmpty
                                ? widget.customer!.dob!
                                : "Not provided",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: "Member Since",
                            value: widget.customer?.createdAt != null
                                ? "${widget.customer!.createdAt!.day}/${widget.customer!.createdAt!.month}/${widget.customer!.createdAt!.year}"
                                : "Not available",
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.shopping_bag_outlined,
                            label: "Total Orders",
                            value: widget.customer?.orders?.length.toString() ??
                                "0",
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // KYC Information Card (only when ZATCA Phase 1 is enabled)
                      if (isZatcaPhase1Enabled &&
                          widget.customer?.kyc != null &&
                          widget.customer!.kyc!.isNotEmpty)
                        Column(
                          children: [
                            _buildKycInfoCard(),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Store Information Card
                      if (widget.customer?.storeName != null &&
                          widget.customer!.storeName!.isNotEmpty)
                        Column(
                          children: [
                            _buildStoreInfoCard(),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Loyalty Card Information Card
                      _buildLoyaltyCardInfoCard(),

                      const SizedBox(height: 24),

                      // Transaction History Card
                      if (widget.customer?.transactions != null &&
                          widget.customer!.transactions!.isNotEmpty)
                        Column(
                          children: [
                            _buildTransactionHistoryCard(),
                            const SizedBox(height: 24),
                          ],
                        ),

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
            decoration: const BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: BorderRadius.only(
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
            "Quick Actions",
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
                  label: "Edit Customer",
                  color: ColorManager.kPrimaryColor,
                  onTap: widget.onEditCustomer ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history_outlined,
                  label: "View Orders",
                  color: ColorManager.kButtonGreen,
                  onTap: widget.onViewOrders ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_outlined,
                  label: "Message",
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

  Widget _buildKycInfoCard() {
    return _buildInfoCard(
      title: "KYC Information",
      icon: Icons.verified_user,
      children: widget.customer!.kyc!
          .map((kyc) => Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.document_scanner,
                    label: kyc.key ?? "Document",
                    value: kyc.value ?? "Not provided",
                  ),
                  if (kyc.expiryDate != null && kyc.expiryDate!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: ColorManager.kGreyColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Expires: ${kyc.expiryDate}",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.30,
                              ColorManager.kGreyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildStoreInfoCard() {
    return _buildInfoCard(
      title: "Store Information",
      icon: Icons.store,
      children: [
        _buildInfoRow(
          icon: Icons.business,
          label: "Store Name",
          value: widget.customer?.storeName ?? "Not available",
        ),
        if (widget.customer?.companyId != null)
          Column(
            children: [
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.corporate_fare,
                label: "Company ID",
                value: widget.customer!.companyId!.toString(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoyaltyCardInfoCard() {
    return _buildInfoCard(
      title: "Loyalty Card Information",
      icon: Icons.card_giftcard,
      children: [
        if (widget.customer?.cardNumber != null &&
            widget.customer!.cardNumber!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.credit_card,
                label: "Card Number",
                value: widget.customer!.cardNumber!,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.membershipName != null &&
            widget.customer!.membershipName!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.star,
                label: "Membership",
                value: widget.customer!.membershipName!,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.membershipCode != null &&
            widget.customer!.membershipCode!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.qr_code,
                label: "Membership Code",
                value: widget.customer!.membershipCode!,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.validFrom != null &&
            widget.customer!.validFrom!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: "Valid From",
                value: widget.customer!.validFrom!,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.validUntil != null &&
            widget.customer!.validUntil!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.event_busy,
                label: "Valid Until",
                value: widget.customer!.validUntil!,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.cardStatus != null &&
            widget.customer!.cardStatus!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.info,
                label: "Card Status",
                value: widget.customer!.cardStatus!,
                valueColor:
                    widget.customer!.cardStatus!.toLowerCase() == 'active'
                        ? ColorManager.kSuccessColor
                        : ColorManager.kGreyColor,
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.minRedeemablePoints != null)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.redeem,
                label: "Min Redeemable Points",
                value: widget.customer!.minRedeemablePoints!.toString(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.pricePerPoint != null)
          _buildInfoRow(
            icon: Icons.currency_rupee,
            label: "Price Per Point",
            value: "${widget.customer!.pricePerPoint!.toStringAsFixed(2)}",
          ),
        // Show message if no loyalty information
        if ((widget.customer?.cardNumber?.isEmpty ?? true) &&
            (widget.customer?.membershipName?.isEmpty ?? true) &&
            (widget.customer?.membershipCode?.isEmpty ?? true) &&
            (widget.customer?.validFrom?.isEmpty ?? true) &&
            (widget.customer?.validUntil?.isEmpty ?? true) &&
            widget.customer?.cardStatus == null &&
            widget.customer?.minRedeemablePoints == null &&
            widget.customer?.pricePerPoint == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "No loyalty card information available",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.30,
                ColorManager.kGreyColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionHistoryCard() {
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
            decoration: const BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 20,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  "Recent Transactions",
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.30,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  "${widget.customer!.transactions!.length} transactions",
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.30,
                    ColorManager.kGreyColor,
                  ),
                ),
              ],
            ),
          ),
          // Transaction List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.customer!.transactions!.length > 3
                ? 3
                : widget.customer!.transactions!.length,
            itemBuilder: (context, index) {
              // Show last transactions (most recent first)
              final transactionIndex =
                  widget.customer!.transactions!.length - 1 - index;
              final transaction =
                  widget.customer!.transactions![transactionIndex];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: index <
                          (widget.customer!.transactions!.length > 3
                              ? 2
                              : widget.customer!.transactions!.length - 1)
                      ? const Border(
                          bottom: BorderSide(
                              color: ColorManager.kPrimaryWithOpacity10))
                      : null,
                ),
                child: Row(
                  children: [
                    // Transaction Type Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getTransactionTypeColor(transaction.type)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTransactionTypeIcon(transaction.type),
                        size: 20,
                        color: _getTransactionTypeColor(transaction.type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Transaction Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.transactionType ?? "Transaction",
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.30,
                              ColorManager.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Ref: ${transaction.referenceId ?? 'N/A'}",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.30,
                              ColorManager.kGreyColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            transaction.date ?? "",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.30,
                              ColorManager.kGreyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${transaction.type == 'Credit' ? '+' : '-'}${transaction.amount ?? '0'} ${transaction.currency ?? 'INR'}",
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s14,
                            0.30,
                            _getTransactionTypeColor(transaction.type),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transaction.paymentMethod ?? "N/A",
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.30,
                            ColorManager.kGreyColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Show more indicator if there are more than 3 transactions
          if (widget.customer!.transactions!.length > 3)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: ColorManager.kPrimaryWithOpacity10,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  "And ${widget.customer!.transactions!.length - 3} more transactions...",
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.30,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getTransactionTypeIcon(String? type) {
    if (type == null) return Icons.swap_horiz;
    switch (type.toLowerCase()) {
      case 'credit':
        return Icons.arrow_upward;
      case 'debit':
        return Icons.arrow_downward;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getTransactionTypeColor(String? type) {
    if (type == null) return ColorManager.kGreyColor;
    switch (type.toLowerCase()) {
      case 'credit':
        return ColorManager.kSuccessColor;
      case 'debit':
        return Colors.red;
      default:
        return ColorManager.kGreyColor;
    }
  }

  String _getPaymentTypeDisplay(String? paymentType) {
    if (paymentType == null || paymentType.isEmpty) {
      return "Not set";
    }
    switch (paymentType.toLowerCase()) {
      case 'to_pay':
        return "To Pay";
      case 'to_receive':
        return "To Receive";
      default:
        return "Not set";
    }
  }

  Color _getPaymentTypeColor(String? paymentType) {
    if (paymentType == null || paymentType.isEmpty) {
      return ColorManager.kGreyColor;
    }
    switch (paymentType.toLowerCase()) {
      case 'to_pay':
        return Colors.orange;
      case 'to_receive':
        return ColorManager.kSuccessColor;
      default:
        return ColorManager.kGreyColor;
    }
  }
}
