import 'package:flutter/material.dart';
// import 'package:pos_machine/screens/billing/billing_page_desktop.dart';
import 'package:pos_machine/screens/billing/billing_page_mobile.dart';
import 'package:pos_machine/screens/billing/billing_page_restaurant.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'billing_page.dart';

class BillingPageResponsive extends StatefulWidget {
  const BillingPageResponsive({super.key});

  @override
  State<BillingPageResponsive> createState() => _BillingPageResponsiveState();
}

class _BillingPageResponsiveState extends State<BillingPageResponsive> {
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    setState(() {
      userRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use full screen width to decide layout, not inner constraints reduced by sidebar
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 650) {
      return const BillingPageMobile();
    }

    // Show BillingPageRestaurant for restaurant_sales role, otherwise show BillingPage
    if (userRole == 'restaurant_sales') {
      return const BillingPageRestaurant();
    }
    return const BillingPage();
  }
}
