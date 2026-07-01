import 'package:flutter/material.dart';
// import 'package:pos_machine/screens/billing/billing_page_desktop.dart';
import 'package:pos_machine/core/responsive/breakpoints.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page_mobile.dart';
import 'package:pos_machine/screens/billing/restaurant/restaurant_page.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'billing_page.dart';

/// Resolved billing shell for responsive routing (testable without mounting pages).
enum BillingResponsiveRoute { loading, restaurant, mobileBilling, desktopBilling }

@visibleForTesting
BillingResponsiveRoute resolveBillingResponsiveRoute({
  required bool isRoleLoaded,
  required String userRole,
  required bool isMobileWidth,
}) {
  if (!isRoleLoaded) return BillingResponsiveRoute.loading;
  if (userRole == 'restaurant_sales') {
    return BillingResponsiveRoute.restaurant;
  }
  if (isMobileWidth) return BillingResponsiveRoute.mobileBilling;
  return BillingResponsiveRoute.desktopBilling;
}

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
    // Use full screen width to decide layout, not inner constraints reduced by
    // sidebar. Threshold delegated to the single source of truth (Breakpoints).
    final isMobileWidth =
        Breakpoints.isMobileWidth(MediaQuery.of(context).size.width);

    switch (resolveBillingResponsiveRoute(
      isRoleLoaded: _isRoleLoaded,
      userRole: userRole,
      isMobileWidth: isMobileWidth,
    )) {
      case BillingResponsiveRoute.loading:
        return Scaffold(
          backgroundColor: isMobileWidth ? Colors.white : const Color(0xFFF8FAFC),
          body: const SizedBox.expand(),
        );
      case BillingResponsiveRoute.restaurant:
        return const RestaurantPage(
          allowCounterBillingFromAttender: true,
          defaultCounterBillingMode: true,
        );
      case BillingResponsiveRoute.mobileBilling:
        return const BillingPageMobile();
      case BillingResponsiveRoute.desktopBilling:
        return const BillingPage();
    }
  }
}
