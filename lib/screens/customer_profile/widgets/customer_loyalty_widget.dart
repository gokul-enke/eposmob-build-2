import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

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
  int loyaltyPoints = 0;
  String loyaltyLevel = "Bronze";
  String loyaltyCardNumber = "";

  @override
  void initState() {
    super.initState();
    _loadLoyaltyInfo();
  }

  Future<void> _loadLoyaltyInfo() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Generate a loyalty card number based on customer ID
      final customerId = widget.customer.id.toString();
      final loyaltyId = "LC${customerId.padLeft(8, '0')}";

      // TODO: Replace with actual API call to get customer loyalty information
      // final response = await http.get(
      //   Uri.parse('${APPUrl.getCustomerLoyalty}/${widget.customer.id}'),
      //   headers: {
      //     'Authorization': 'Bearer $accessToken',
      //     'Content-Type': 'application/json',
      //   },
      // );

      // For now, just use the customer ID to create a loyalty card number
      setState(() {
        loyaltyPoints = 0;
        loyaltyLevel = _calculateLoyaltyLevel(loyaltyPoints);
        loyaltyCardNumber = loyaltyId;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to load loyalty information';
        isLoading = false;
      });
    }
  }

  String _calculateLoyaltyLevel(int points) {
    if (points >= 1000) {
      return "Platinum";
    } else if (points >= 500) {
      return "Gold";
    } else if (points >= 200) {
      return "Silver";
    } else {
      return "Bronze";
    }
  }

  Color _getLoyaltyCardColor() {
    switch (loyaltyLevel) {
      case "Platinum":
        return const Color(0xFFE5E4E2);
      case "Gold":
        return const Color(0xFFFFD700);
      case "Silver":
        return const Color(0xFFC0C0C0);
      default:
        return const Color(0xFFCD7F32);
    }
  }

 
  
@override

@override
Widget build(BuildContext context) {
  return Expanded(
    child: BuildBoxShadowContainer(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(15),
      height: widget.size.height * 0.75,
      width: widget.size.width / 1.8,
      circleRadius: 7,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Title
                      Text(
                        'Loyalty Card',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s20,
                          0.30,
                          ColorManager.textColor,
                        ),
                      ),

                      /// Spacing
                      const SizedBox(height: 20),

                      /// Card UI with user info (visual part)
                      _buildLoyaltyCard(),

                      /// Spacing
                      const SizedBox(height: 30),

                      /// Loyalty card details (points, validity, etc.)
                      _buildLoyaltyCardDetails(widget.customer),

                      /// Optional bottom spacing
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
    ),
  );
}





  Widget _buildLoyaltyCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 800 ? screenWidth * 0.4 : 350.0;

    return Center(
      child: Container(
        width: cardWidth,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getLoyaltyCardColor(),
              _getLoyaltyCardColor().withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EPOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        loyaltyLevel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.customer.name ?? 'Customer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Card: $loyaltyCardNumber',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        loyaltyCardNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildLoyaltyCardDetails(CustomerListModelData data) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_membership,
              size: 60,
              color: ColorManager.kPrimaryColor,
            ),
            const SizedBox(height: 10),
            Text(
              data.membershipName ?? "Membership",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.2,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Card No: ${data.cardNumber ?? '--'}",
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.2,
                ColorManager.blackWithOpacity50,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLoyaltyInfoTile("Points", data.loyaltyPoints?.toString() ?? '0'),
                _buildLoyaltyInfoTile("Min Redeem", data.minRedeemablePoints?.toString() ?? '0'),
                _buildLoyaltyInfoTile("Value/Point", "₹${data.pricePerPoint?.toStringAsFixed(2) ?? '0.00'}"),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLoyaltyInfoTile("Valid From", data.validFrom ?? '--'),
                _buildLoyaltyInfoTile("Valid Until", data.validUntil ?? '--'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Status: ${data.cardStatus ?? 'Inactive'}",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.2,
                data.cardStatus?.toLowerCase() == "active"
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}




Widget _buildLoyaltyInfoTile(String title, String value) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.2,
            ColorManager.blackWithOpacity50,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.2,
            ColorManager.textColor,
          ),
        ),
      ],
    ),
  );
}

}
