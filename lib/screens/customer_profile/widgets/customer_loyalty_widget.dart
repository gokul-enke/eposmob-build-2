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
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
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
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoyaltyCard(),
                const SizedBox(height: 24),
                _buildLoyaltyDetails(),
              ],
            ),
          ),
        ),
      ],
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
          const Icon(Icons.card_membership,
              color: ColorManager.kPrimaryColor, size: 28),
          const SizedBox(width: 12),
          Text(
            'Loyalty Program',
            style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyCard() {
    final cardColor = _getLoyaltyCardColor(widget.customer.membershipName);

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
      child: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -60,
            child: Icon(Icons.stars,
                size: 180, color: Colors.white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EPOS Loyalty',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s20, 0, Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        widget.customer.membershipName ?? "Bronze",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s12, 0, Colors.white),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.customer.name ?? 'Customer Name',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s18, 0, Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.customer.cardNumber ?? 'N/A',
                  style: buildCustomStyle(FontWeightManager.regular,
                      FontSize.s14, 0, Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: ColorManager.kPrimaryColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s14, 0, ColorManager.kGreyColor),
                ),
              ),
              if (title == 'Price Per Point')
                Consumer<AppSettingsProvider>(
                  builder: (context, appSettingsProvider, child) {
                    final currency =
                        appSettingsProvider.appSettings?.currency ?? 'INR';
                    return Text(
                      '$currency${widget.customer.pricePerPoint?.toStringAsFixed(2) ?? '0.00'}',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s14,
                          0,
                          valueColor ?? ColorManager.kTitleTextColor),
                    );
                  },
                )
              else
                Text(
                  value,
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                      0, valueColor ?? ColorManager.kTitleTextColor),
                ),
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
