import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class CustomerLoyaltyWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerLoyaltyWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerLoyaltyWidget> createState() => _CustomerLoyaltyWidgetState();
}

class _CustomerLoyaltyWidgetState extends State<CustomerLoyaltyWidget> {
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLoyaltyInfo();
  }

  Future<void> _loadLoyaltyInfo() async {
    try {
      setState(() => isLoading = true);
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      setState(() => isLoading = false);
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to load loyalty information';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.size.width < 600;
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(isMobile ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: isMobile ? double.infinity : widget.size.width / 1.8,
        circleRadius: 12,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildErrorState()
                : _buildLoyaltyContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: ColorManager.kRed),
            const SizedBox(height: 16),
            Text('Error Loading Data',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s18, 0, ColorManager.kTitleTextColor)),
            const SizedBox(height: 8),
            Text(errorMessage!,
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0, ColorManager.kGreyColor)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLoyaltyInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyContent() {
    final isMobile = widget.size.width < 600;
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoyaltyCard(),
                SizedBox(height: isMobile ? 16 : 24),
                _buildLoyaltyDetails(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isMobile = widget.size.width < 600;
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      child: Row(
        children: [
          Icon(Icons.card_membership,
              color: ColorManager.kPrimaryColor, size: isMobile ? 24 : 28),
          SizedBox(width: isMobile ? 8 : 12),
          isMobile
              ? Expanded(
                  child: Text(
                    'Loyalty Program',
                    softWrap: true,
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s16, 0, ColorManager.kTitleTextColor),
                  ),
                )
              : Flexible(
                  child: Text(
                    'Loyalty Program',
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s18, 0, ColorManager.kTitleTextColor),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyCard() {
    final cardColor = _getLoyaltyCardColor(widget.customer.membershipName);
    final isMobile = widget.size.width < 600;

    return Container(
      width: double.infinity,
      height: isMobile ? null : 200,
      constraints: isMobile ? const BoxConstraints(minHeight: 170) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, cardColor.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              bottom: -60,
              child: Icon(Icons.stars,
                  size: 180, color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isMobile
                          ? Expanded(
                              child: Text(
                                'EPOS Loyalty',
                                softWrap: true,
                                style: buildCustomStyle(FontWeightManager.bold,
                                    FontSize.s16, 0, Colors.white),
                              ),
                            )
                          : Flexible(
                              child: Text(
                                'EPOS Loyalty',
                                softWrap: true,
                                style: buildCustomStyle(FontWeightManager.bold,
                                    FontSize.s20, 0, Colors.white),
                              ),
                            ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                            vertical: isMobile ? 4 : 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          widget.customer.membershipName ?? "Bronze",
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              isMobile ? FontSize.s10 : FontSize.s12,
                              0,
                              Colors.white),
                        ),
                      ),
                    ],
                  ),
                  isMobile
                      ? const SizedBox(height: 24)
                      : const Spacer(),
                  Text(
                    widget.customer.name ?? 'Customer Name',
                    softWrap: true,
                    maxLines: isMobile ? null : 2,
                    overflow: isMobile ? null : TextOverflow.ellipsis,
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        isMobile ? FontSize.s15 : FontSize.s18,
                        0,
                        Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.customer.cardNumber ?? 'N/A',
                    softWrap: true,
                    style: buildCustomStyle(
                        FontWeightManager.regular,
                        isMobile ? FontSize.s12 : FontSize.s14,
                        0,
                        Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kBgDarkColor),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.star_border_purple500_outlined,
            title: 'Loyalty Points',
            value: widget.customer.loyaltyPoints?.toString() ?? '0',
            valueColor: ColorManager.kSuccessColor,
          ),
          _buildInfoRow(
            icon: Icons.redeem,
            title: 'Min. Redeemable Points',
            value: widget.customer.minRedeemablePoints?.toString() ?? '0',
          ),
          _buildInfoRow(
            icon: Icons.price_change_outlined,
            title: 'Price Per Point',
            value:
                '', // Empty value as we'll use the Consumer widget to display this
          ),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            title: 'Valid From',
            value: widget.customer.validFrom ?? '--',
          ),
          _buildInfoRow(
            icon: Icons.event_busy_outlined,
            title: 'Valid Until',
            value: widget.customer.validUntil ?? '--',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    bool showDivider = true,
  }) {
    final isMobile = widget.size.width < 600;

    Widget buildLabel() {
      if (isMobile) {
        return Expanded(
          flex: 3,
          child: Text(
            title,
            softWrap: true,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                0, ColorManager.kGreyColor),
          ),
        );
      }
      return Expanded(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s14, 0,
              ColorManager.kGreyColor),
        ),
      );
    }

    Widget buildValue(String text, Color color) {
      if (isMobile) {
        return Expanded(
          flex: 2,
          child: Text(
            text,
            textAlign: TextAlign.right,
            softWrap: true,
            style:
                buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0, color),
          ),
        );
      }
      return Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style:
              buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0, color),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  color: ColorManager.kPrimaryColor,
                  size: isMobile ? 18 : 22),
              SizedBox(width: isMobile ? 12 : 16),
              buildLabel(),
              const SizedBox(width: 8),
              if (title == 'Price Per Point')
                Consumer<AppSettingsProvider>(
                  builder: (context, appSettingsProvider, child) {
                    final currency =
                        appSettingsProvider.appSettings?.currency ?? 'INR';
                    return buildValue(
                      '$currency${widget.customer.pricePerPoint?.toStringAsFixed(2) ?? '0.00'}',
                      valueColor ?? ColorManager.kTitleTextColor,
                    );
                  },
                )
              else
                buildValue(value, valueColor ?? ColorManager.kTitleTextColor),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Color _getLoyaltyCardColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'platinum':
        return const Color(0xFF708090); // SlateGray
      case 'gold':
        return const Color(0xFFD4AF37); // Gold
      case 'silver':
        return const Color(0xFFA9A9A9); // DarkGray
      default:
        return const Color(0xFFB87333); // Copper
    }
  }
}
