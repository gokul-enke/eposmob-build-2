library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/features/billing/presentation/pages/billing_page_responsive.dart';

void main() {
  test('restaurant_sales on mobile width routes to restaurant', () {
    expect(
      resolveBillingResponsiveRoute(
        isRoleLoaded: true,
        userRole: 'restaurant_sales',
        isMobileWidth: true,
      ),
      BillingResponsiveRoute.restaurant,
    );
  });

  test('restaurant_sales on desktop width routes to restaurant', () {
    expect(
      resolveBillingResponsiveRoute(
        isRoleLoaded: true,
        userRole: 'restaurant_sales',
        isMobileWidth: false,
      ),
      BillingResponsiveRoute.restaurant,
    );
  });

  test('non-restaurant mobile width routes to mobile billing', () {
    expect(
      resolveBillingResponsiveRoute(
        isRoleLoaded: true,
        userRole: 'sales',
        isMobileWidth: true,
      ),
      BillingResponsiveRoute.mobileBilling,
    );
  });

  test('non-restaurant desktop width routes to desktop billing', () {
    expect(
      resolveBillingResponsiveRoute(
        isRoleLoaded: true,
        userRole: 'sales',
        isMobileWidth: false,
      ),
      BillingResponsiveRoute.desktopBilling,
    );
  });

  test('unloaded role shows loading shell', () {
    expect(
      resolveBillingResponsiveRoute(
        isRoleLoaded: false,
        userRole: 'restaurant_sales',
        isMobileWidth: true,
      ),
      BillingResponsiveRoute.loading,
    );
  });
}
