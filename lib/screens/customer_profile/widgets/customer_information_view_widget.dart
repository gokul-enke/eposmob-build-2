import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_ui.dart';
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
    final isMobile = size.width < 700;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final bool isZatcaPhase1Enabled = appSettings?.zatcaPhase1Enabled ?? false;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: isMobile ? 8 : 12,
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryWithOpacity10,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMobile ? 8 : 12),
                  topRight: Radius.circular(isMobile ? 8 : 12),
                ),
              ),
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 12 : 24,
                horizontal: isMobile ? 12 : 24,
              ),
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 40 : 60,
                    height: isMobile ? 40 : 60,
                    decoration: BoxDecoration(
                      color: ColorManager.kPrimaryColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(isMobile ? 20 : 30),
                      border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.2),
                          width: 2),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isMobile ? 22 : 32,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CustomerDisplay.name(widget.customer?.name),
                          overflow: TextOverflow.ellipsis,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            isMobile ? FontSize.s16 : FontSize.s20,
                            0,
                            ColorManager.kTitleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width < 600 ? 6 : 10,
                      vertical: size.width < 600 ? 4 : 6,
                    ),
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
                      ((widget.customer?.customerType ?? 'B2C')
                                  .toUpperCase() ==
                              'B2B')
                          ? 'customers.type_b2b'.tr
                          : 'customers.type_b2c'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        size.width < 600 ? FontSize.s10 : FontSize.s11,
                        0.18,
                        (widget.customer?.customerType ?? 'B2C')
                                    .toUpperCase() ==
                                'B2B'
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  SizedBox(width: size.width < 600 ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width < 600 ? 6 : 12,
                      vertical: size.width < 600 ? 4 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: ColorManager.kSuccessColor,
                      borderRadius:
                          BorderRadius.circular(size.width < 600 ? 12 : 20),
                    ),
                    child: Text(
                      'customer_profile.view_label_active'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        size.width < 600 ? FontSize.s10 : FontSize.s12,
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
                padding: EdgeInsets.all(widget.size.width < 600 ? 12 : 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact Information Card
                      _buildInfoCard(
                        title: 'customer_profile.view_section_contact'.tr,
                        icon: Icons.contact_phone,
                        children: [
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'customer_profile.view_label_email'.tr,
                            value: widget.customer?.email ?? 'customer_profile.view_msg_not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'customer_profile.view_label_phone'.tr,
                            value: widget.customer?.phone ?? 'customer_profile.view_msg_not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.phone_android_outlined,
                            label: 'customer_profile.view_label_alt_phone'.tr,
                            value: widget.customer?.altPhone ?? 'customer_profile.view_msg_not_provided'.tr,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Account Information Card
                      _buildInfoCard(
                        title: 'customer_profile.view_section_account'.tr,
                        icon: Icons.account_circle,
                        children: [
                          _buildInfoRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'customer_profile.view_label_balance'.tr,
                            value:
                                "${widget.customer?.balance?.toStringAsFixed(2) ?? "0.00"}",
                            valueColor: (widget.customer?.balance ?? 0) >= 0
                                ? ColorManager.kSuccessColor
                                : Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.payment_outlined,
                            label: 'customer_profile.view_label_payment_type'.tr,
                            value: _getPaymentTypeDisplay(
                                widget.customer?.paymentType),
                            valueColor: _getPaymentTypeColor(
                                widget.customer?.paymentType),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.credit_score_outlined,
                            label: 'customer_profile.view_label_loyalty_points'.tr,
                            value: widget.customer?.loyaltyPoints?.toString() ??
                                "0",
                            valueColor: ColorManager.kSuccessColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.person_outlined,
                            label: 'customer_profile.view_label_gender'.tr,
                            value: widget.customer?.gender != null &&
                                    widget.customer!.gender!.isNotEmpty
                                ? widget.customer!.gender![0].toUpperCase() +
                                    widget.customer!.gender!.substring(1)
                                : 'customer_profile.view_msg_not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'customer_profile.view_label_dob'.tr,
                            value: widget.customer?.dob != null &&
                                    widget.customer!.dob!.isNotEmpty
                                ? widget.customer!.dob!
                                : 'customer_profile.view_msg_not_provided'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'customer_profile.view_label_member_since'.tr,
                            value: widget.customer?.createdAt != null
                                ? "${widget.customer!.createdAt!.day}/${widget.customer!.createdAt!.month}/${widget.customer!.createdAt!.year}"
                                : 'customer_profile.view_msg_not_available'.tr,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.shopping_bag_outlined,
                            label: 'customer_profile.view_label_total_orders'.tr,
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
    final isMobile = widget.size.width < 700;
    final radius = isMobile ? 8.0 : 12.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kSecondaryColor,
        borderRadius: BorderRadius.circular(radius),
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
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
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
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.30,
                      ColorManager.kPrimaryColor,
                    ),
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
    final isMobile = widget.size.width < 700;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 10 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
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
            'customer_profile.view_section_quick_actions'.tr,
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
                  label: 'customer_profile.view_label_edit_customer'.tr,
                  color: ColorManager.kPrimaryColor,
                  onTap: widget.onEditCustomer ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history_outlined,
                  label: 'customer_profile.view_label_view_orders'.tr,
                  color: ColorManager.kButtonGreen,
                  onTap: widget.onViewOrders ?? () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_outlined,
                  label: 'customer_profile.view_label_message'.tr,
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
      title: 'customer_profile.view_section_kyc'.tr,
      icon: Icons.verified_user,
      children: widget.customer!.kyc!
          .map((kyc) => Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.document_scanner,
                    label: kyc.key ?? 'customer_profile.view_label_document'.tr,
                    value: kyc.value ?? 'customer_profile.view_msg_not_provided'.tr,
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
                            '${'customer_profile.view_label_expires'.tr}: ${kyc.expiryDate}',
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
      title: 'customer_profile.view_section_store'.tr,
      icon: Icons.store,
      children: [
        _buildInfoRow(
          icon: Icons.business,
          label: 'customer_profile.view_label_store_name'.tr,
          value: widget.customer?.storeName ?? 'customer_profile.view_msg_not_available'.tr,
        ),
        if (widget.customer?.companyId != null)
          Column(
            children: [
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.corporate_fare,
                label: 'customer_profile.view_label_company_id'.tr,
                value: widget.customer!.companyId!.toString(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoyaltyCardInfoCard() {
    return _buildInfoCard(
      title: 'customer_profile.view_section_loyalty'.tr,
      icon: Icons.card_giftcard,
      children: [
        if (widget.customer?.cardNumber != null &&
            widget.customer!.cardNumber!.isNotEmpty)
          Column(
            children: [
              _buildInfoRow(
                icon: Icons.credit_card,
                label: 'customer_profile.view_label_card_number'.tr,
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
                label: 'customer_profile.view_label_membership'.tr,
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
                label: 'customer_profile.view_label_membership_code'.tr,
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
                label: 'customer_profile.view_label_valid_from'.tr,
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
                label: 'customer_profile.view_label_valid_until'.tr,
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
                label: 'customer_profile.view_label_card_status'.tr,
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
                label: 'customer_profile.view_label_min_redeemable'.tr,
                value: widget.customer!.minRedeemablePoints!.toString(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (widget.customer?.pricePerPoint != null)
          _buildInfoRow(
            icon: Icons.currency_rupee,
            label: 'customer_profile.view_label_price_per_point'.tr,
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
              'customer_profile.view_msg_no_loyalty_info'.tr,
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
    final isMobile = widget.size.width < 700;
    final radius = isMobile ? 8.0 : 12.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kSecondaryColor,
        borderRadius: BorderRadius.circular(radius),
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
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
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
                Flexible(
                  child: Text(
                    'customer_profile.view_section_transactions'.tr,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.30,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "${widget.customer!.transactions!.length} ${'customer_profile.view_label_transactions'.tr}",
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
                            '${'customer_profile.view_label_ref'.tr}: ${transaction.referenceId ?? 'N/A'}',
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
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryWithOpacity10,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(radius),
                  bottomRight: Radius.circular(radius),
                ),
              ),
              child: Center(
                child: Text(
                  '${'customer_profile.view_label_and'.tr} ${widget.customer!.transactions!.length - 3} ${'customer_profile.view_label_more_transactions'.tr}',
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
      return 'customer_profile.view_msg_not_set'.tr;
    }
    switch (paymentType.toLowerCase()) {
      case 'to_pay':
        return 'customer_profile.field_payment_to_pay'.tr;
      case 'to_receive':
        return 'customer_profile.field_payment_to_receive'.tr;
      default:
        return 'customer_profile.view_msg_not_set'.tr;
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
