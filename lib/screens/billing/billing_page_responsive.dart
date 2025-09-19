import 'package:flutter/material.dart';
// import 'package:pos_machine/screens/billing/billing_page_desktop.dart';
import 'package:pos_machine/screens/billing/billing_page_mobile.dart';
import 'billing_page.dart';

class BillingPageResponsive extends StatelessWidget {
  const BillingPageResponsive({super.key});

  @override
  Widget build(BuildContext context) {
    // Use full screen width to decide layout, not inner constraints reduced by sidebar
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 650) {
      return const BillingPageMobile();
    }
    return const BillingPage();
  }
}
