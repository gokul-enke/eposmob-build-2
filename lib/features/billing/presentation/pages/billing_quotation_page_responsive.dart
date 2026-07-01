import 'package:flutter/material.dart';
import 'package:pos_machine/core/responsive/breakpoints.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page_mobile.dart';

/// Routes quotation billing to the mobile or desktop implementation based on
/// viewport width. Sidebar index 86 uses this instead of [BillingPage] alone.
class BillingQuotationPageResponsive extends StatelessWidget {
  const BillingQuotationPageResponsive({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobileWidth =
        Breakpoints.isMobileWidth(MediaQuery.of(context).size.width);
    if (isMobileWidth) {
      return const BillingPageMobile(mode: BillingPageMode.quotation);
    }
    return const BillingPage(mode: BillingPageMode.quotation);
  }
}
