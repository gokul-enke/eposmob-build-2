import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
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
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
    return ResponsiveStatGrid(
      maxColumns: 4,
      cards: [
        DashboardStatCard(
          title: 'dashboard.zatca_overview.success'.tr,
          subtitle: 'dashboard.zatca_overview.success_subtitle'.tr,
          value: '${overview.successZatca}',
          color: const Color(0xFF21A366),
          icon: Icons.check_circle_outline_rounded,
          showTrend: false,
        ),
        DashboardStatCard(
          title: 'dashboard.zatca_overview.not_sent'.tr,
          subtitle: 'dashboard.zatca_overview.not_sent_subtitle'.tr,
          value: '${overview.notSent}',
          color: const Color(0xFF64748B),
          icon: Icons.schedule_send_outlined,
          showTrend: false,
        ),
        DashboardStatCard(
          title: 'dashboard.zatca_overview.failed'.tr,
          subtitle: 'dashboard.zatca_overview.failed_subtitle'.tr,
          value: '${overview.failed}',
          color: ColorManager.kRed,
          icon: Icons.error_outline_rounded,
          showTrend: false,
        ),
        DashboardStatCard(
          title: 'dashboard.zatca_overview.warning'.tr,
          subtitle: 'dashboard.zatca_overview.warning_subtitle'.tr,
          value: '${overview.warning}',
          color: const Color(0xFFE59A17),
          icon: Icons.warning_amber_rounded,
          showTrend: false,
        ),
      ],
    );
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
