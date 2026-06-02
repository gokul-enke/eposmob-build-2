import 'package:flutter/material.dart';
// import 'package:pos_machine/screens/billing/billing_page_desktop.dart';
import 'package:pos_machine/screens/billing/billing_page_mobile.dart';
import 'package:pos_machine/screens/billing/restaurant/restaurant_page.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'billing_page.dart';

class BillingPageResponsive extends StatefulWidget {
  const BillingPageResponsive({super.key});

  @override
  State<BillingPageResponsive> createState() => _BillingPageResponsiveState();
}

class _BillingPageResponsiveState extends State<BillingPageResponsive> {
  String userRole = '';
  bool _isRoleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    if (!mounted) return;
    setState(() {
      userRole = role;
      _isRoleLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use full screen width to decide layout, not inner constraints reduced by sidebar
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 650) {
      return const BillingPageMobile();
    }

    if (!_isRoleLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: SizedBox.expand(),
      );
    }

    // Show RestaurantPage for restaurant_sales role, otherwise show BillingPage
    if (userRole == 'restaurant_sales') {
      return const RestaurantPage(
        allowCounterBillingFromAttender: true,
        defaultCounterBillingMode: true,
      );
    }
    return const BillingPage();
  }
}
