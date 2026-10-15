import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../helpers/dashboard_permissions.dart';
import '../../../models/dashboard_api.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import 'dashboard_responsive.dart';

/// Tenant-level ZATCA transmission totals for Phase 2 companies.
///
/// The section owns its request so both dashboard roles share identical
/// loading, retry, and settings-gating behaviour.
class ZatcaOverviewSection extends StatefulWidget {
  final String period;

  const ZatcaOverviewSection({
    super.key,
    required this.period,
  });

  @override
  State<ZatcaOverviewSection> createState() => _ZatcaOverviewSectionState();
}

class _ZatcaOverviewSectionState extends State<ZatcaOverviewSection> {
  bool _requestScheduled = false;
  bool _loading = false;
  ZatcaOverview? _overview;
  Object? _error;

  @override
  void didUpdateWidget(covariant ZatcaOverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_normalizedPeriod(oldWidget.period) ==
        _normalizedPeriod(widget.period)) {
      return;
    }

    _requestVersion++;
    _requestScheduled = false;
    _loading = false;
    _overview = null;
    _error = null;
    _scheduleInitialLoad();
  }

  int _requestVersion = 0;

  String _normalizedPeriod(String period) => period.trim().toLowerCase();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialLoad();
  }

  void _scheduleInitialLoad() {
    if (_requestScheduled || _overview != null || _loading) return;

    final phase2Enabled =
        context.read<AppSettingsProvider>().appSettings?.zatcaPhase2Enabled ??
            false;
    if (!phase2Enabled) return;

    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchOverview();
    });
  }

  Future<void> _fetchOverview() async {
    if (_loading) return;

    final accessToken = context.read<AuthModel>().token;
    if (accessToken == null || accessToken.isEmpty) {
      setState(() {
        _requestScheduled = false;
        _error = const FormatException('Missing access token');
      });
      return;
    }

    final requestVersion = ++_requestVersion;
    final requestPeriod = _normalizedPeriod(widget.period);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final overview = await DashboardProvider().fetchZatcaOverview(
        accessToken,
        period: requestPeriod,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _overview = overview);
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _error = error);
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase2Enabled = context.select<AppSettingsProvider, bool>(
      (provider) => provider.appSettings?.zatcaPhase2Enabled ?? false,
    );
    if (!phase2Enabled) return const SizedBox.shrink();

    final invoiceAllowed = _allowed(context, _invoiceFields);
    final voucherAllowed = _allowed(context, _voucherFields);
    if (!invoiceAllowed.contains(true) && !voucherAllowed.contains(true)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          DashboardSectionHeader(
            title: '${'dashboard.zatca_overview.title'.tr} · '
                '${'dashboard.periods.${_normalizedPeriod(widget.period)}'.tr}',
            trailing: IconButton(
              tooltip: 'dashboard.zatca_overview.refresh'.tr,
              onPressed: _loading ? null : _fetchOverview,
              icon: const Icon(Icons.refresh_rounded),
              color: ColorManager.kPrimaryColor,
            ),
          ),
          _buildContent(invoiceAllowed, voucherAllowed),
        ],
      ),
    );
  }

  Widget _buildContent(List<bool> invoiceAllowed, List<bool> voucherAllowed) {
    if (_loading && _overview == null) {
      return _buildMessageCard(
        const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_error != null && _overview == null) {
      return _buildMessageCard(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: ColorManager.kRed),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'dashboard.zatca_overview.load_failed'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.12,
                  ColorManager.textColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _fetchOverview,
              child: Text('dashboard.zatca_overview.retry'.tr),
            ),
          ],
        ),
      );
    }

    final overview = _overview ??
        const ZatcaOverview(
          successZatca: 0,
          notSent: 0,
          failed: 0,
          warning: 0,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (invoiceAllowed.contains(true)) ...[
          _buildGroupTitle('dashboard.zatca_overview.invoice_title'.tr),
          ResponsiveStatGrid(
            maxColumns: 4,
            cards: _buildStatusCards(
              allowed: invoiceAllowed,
              success: overview.successZatca,
              notSent: overview.notSent,
              failed: overview.failed,
              warning: overview.warning,
              successSubtitle: 'dashboard.zatca_overview.success_subtitle'.tr,
              notSentSubtitle: 'dashboard.zatca_overview.not_sent_subtitle'.tr,
              failedSubtitle: 'dashboard.zatca_overview.failed_subtitle'.tr,
              warningSubtitle: 'dashboard.zatca_overview.warning_subtitle'.tr,
            ),
          ),
        ],
        if (invoiceAllowed.contains(true) && voucherAllowed.contains(true))
          const SizedBox(height: 18),
        if (voucherAllowed.contains(true)) ...[
          _buildGroupTitle('dashboard.zatca_overview.voucher_title'.tr),
          ResponsiveStatGrid(
            maxColumns: 4,
            cards: _buildStatusCards(
              allowed: voucherAllowed,
              success: overview.voucherSuccess,
              notSent: overview.voucherNotSent,
              failed: overview.voucherFailed,
              warning: overview.voucherWarning,
              successSubtitle:
                  'dashboard.zatca_overview.voucher_success_subtitle'.tr,
              notSentSubtitle:
                  'dashboard.zatca_overview.voucher_not_sent_subtitle'.tr,
              failedSubtitle:
                  'dashboard.zatca_overview.voucher_failed_subtitle'.tr,
              warningSubtitle:
                  'dashboard.zatca_overview.voucher_warning_subtitle'.tr,
            ),
          ),
        ],
      ],
    );
  }

  // Order matches the cards: success, not sent, failed, warning.
  static const _invoiceFields = [
    'success_zatca',
    'not_sent',
    'failed',
    'warning',
  ];
  static const _voucherFields = [
    'voucher_success',
    'voucher_not_sent',
    'voucher_failed',
    'voucher_warning',
  ];

  List<bool> _allowed(BuildContext context, List<String> fields) => fields
      .map((field) => canSeeDashboardItem(
          context, DashboardPermissions.field('zatca_overview', field)))
      .toList();

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Text(
        title,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s14,
          0.15,
          ColorManager.textColor,
        ),
      ),
    );
  }

  List<Widget> _buildStatusCards({
    required List<bool> allowed,
    required int success,
    required int notSent,
    required int failed,
    required int warning,
    required String successSubtitle,
    required String notSentSubtitle,
    required String failedSubtitle,
    required String warningSubtitle,
  }) {
    return [
      if (allowed[0])
        DashboardStatCard(
          title: 'dashboard.zatca_overview.success'.tr,
          subtitle: successSubtitle,
          value: '$success',
          color: const Color(0xFF21A366),
          icon: Icons.check_circle_outline_rounded,
          showTrend: false,
        ),
      if (allowed[1])
        DashboardStatCard(
          title: 'dashboard.zatca_overview.not_sent'.tr,
          subtitle: notSentSubtitle,
          value: '$notSent',
          color: const Color(0xFF64748B),
          icon: Icons.schedule_send_outlined,
          showTrend: false,
        ),
      if (allowed[2])
        DashboardStatCard(
          title: 'dashboard.zatca_overview.failed'.tr,
          subtitle: failedSubtitle,
          value: '$failed',
          color: ColorManager.kRed,
          icon: Icons.error_outline_rounded,
          showTrend: false,
        ),
      if (allowed[3])
        DashboardStatCard(
          title: 'dashboard.zatca_overview.warning'.tr,
          subtitle: warningSubtitle,
          value: '$warning',
          color: const Color(0xFFE59A17),
          icon: Icons.warning_amber_rounded,
          showTrend: false,
        ),
    ];
  }

  Widget _buildMessageCard(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BuildBoxShadowContainer(
        height: 118,
        circleRadius: 14,
        padding: const EdgeInsets.all(16),
        blurRadius: 10,
        offsetValue: const Offset(0, 3),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        child: child,
      ),
    );
  }
}
