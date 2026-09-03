import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../controllers/sidebar_controller.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/invoice_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

/// Dashboard alert for invoices that failed to send to ZATCA.
///
/// Renders nothing unless ZATCA Phase 2 is enabled and at least one invoice has
/// failed, so it stays out of the way until there is something to act on.
/// Tapping it opens the invoice list already filtered to the failed invoices.
///
/// The card fetches its own count rather than being fed one by the dashboard.
/// App settings load asynchronously at startup, so a dashboard reading
/// `zatcaPhase2Enabled` in initState can see null and skip the fetch forever.
/// Watching the setting here means the request fires as soon as settings
/// arrive, whenever that is.
class ZatcaFailedAlert extends StatefulWidget {
  const ZatcaFailedAlert({super.key});

  @override
  State<ZatcaFailedAlert> createState() => _ZatcaFailedAlertState();
}

class _ZatcaFailedAlertState extends State<ZatcaFailedAlert> {
  /// A transient failure at startup would otherwise hide the alert for the
  /// whole dashboard visit, so one retry is allowed before giving up until the
  /// user next opens a dashboard.
  static const int _maxAttempts = 2;
  static const Duration _retryDelay = Duration(seconds: 5);

  bool _inFlight = false;
  bool _succeeded = false;
  int _attempts = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // build() depends on AppSettingsProvider, so this runs again when settings
    // finish loading — which is when the fetch can actually be gated correctly.
    _fetchCount();
  }

  void _fetchCount() {
    if (_inFlight || _succeeded || _attempts >= _maxAttempts) return;

    final phase2Enabled =
        context.read<AppSettingsProvider>().appSettings?.zatcaPhase2Enabled ??
            false;
    if (!phase2Enabled) return;

    final accessToken = context.read<AuthModel>().token;
    if (accessToken == null || accessToken.isEmpty) return;

    _inFlight = true;
    _attempts++;

    // Deferred to the next frame so the provider is never notified mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _inFlight = false;
        return;
      }

      final succeeded = await context
          .read<InvoiceProvider>()
          .fetchFailedZatcaCount(accessToken: accessToken);

      if (!mounted) return;
      _inFlight = false;
      _succeeded = succeeded;

      if (!succeeded && _attempts < _maxAttempts) {
        Future.delayed(_retryDelay, () {
          if (mounted) _fetchCount();
        });
      }
    });
  }

  void _openFailedInvoices() {
    context
        .read<InvoiceProvider>()
        .requestZatcaStatusFilter(InvoiceProvider.zatcaFailedFilterValue);
    Get.find<SideBarController>().index.value =
        SideBarController.invoiceListScreenIndex;
  }

  @override
  Widget build(BuildContext context) {
    // select rather than watch: InvoiceProvider notifies on every invoice list
    // load and filter change, and this card only cares about the count.
    final phase2Enabled = context.select<AppSettingsProvider, bool>(
        (p) => p.appSettings?.zatcaPhase2Enabled ?? false);
    if (!phase2Enabled) return const SizedBox.shrink();

    final count =
        context.select<InvoiceProvider, int>((p) => p.failedZatcaCount);
    if (count <= 0) return const SizedBox.shrink();

    final isMobile = ResponsiveWidget.isMobile(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openFailedInvoices,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: ColorManager.kRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorManager.kRed.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 36 : 42,
                  height: isMobile ? 36 : 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorManager.kRed.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: ColorManager.kRed,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'dashboard.zatca_failed_title'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          isMobile ? FontSize.s13 : FontSize.s15,
                          0.22,
                          ColorManager.kRed,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'dashboard.zatca_failed_subtitle'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          isMobile ? FontSize.s11 : FontSize.s12,
                          0.18,
                          ColorManager.blackWithOpacity50,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: ColorManager.kRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      isMobile ? FontSize.s13 : FontSize.s15,
                      0.22,
                      Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: ColorManager.kRed,
                  size: isMobile ? 20 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
