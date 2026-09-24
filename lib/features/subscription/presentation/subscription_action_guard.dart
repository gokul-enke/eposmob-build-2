import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pos_machine/features/subscription/domain/company_subscription.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_status_dialog.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class SubscriptionActionGuard {
  const SubscriptionActionGuard._();

  static Future<bool> ensureOrderSubmissionAllowed(
    BuildContext context, {
    // Re-verifying here used to run on every order action. With the company
    // subscription endpoint not live yet, each stale check cost a failed probe
    // plus a full app-settings refetch - up to 15s with the confirm button
    // frozen and no spinner. Subscription state is refreshed at app start,
    // login, store switch and sync instead, and live enforcement stays on the
    // order response, which [handleBackendResponse] turns into the blocked
    // dialog. Pass true only from a flow that genuinely needs a fresh probe.
    bool refreshIfStale = false,
  }) async {
    final provider = context.read<SubscriptionProvider>();
    if (refreshIfStale) {
      await provider.refreshIfStale();
      if (!context.mounted) return false;
    }

    switch (provider.status) {
      case CompanySubscriptionStatus.active:
        return true;
      case CompanySubscriptionStatus.warning:
        return _showWarning(context, provider.subscription!);
      case CompanySubscriptionStatus.blocked:
        await showBlocked(context, provider.subscription!);
        return false;
      case CompanySubscriptionStatus.unknown:
        return _allowFromAppSettings(context, provider);
    }
  }

  /// Resolves subscription state from the already-loaded company app settings,
  /// without touching the network.
  ///
  /// Fails open when the settings are not loaded yet or the tenant has not
  /// enabled the temporary `COMPANY_SUBSCRIPTION_STATUS` row: enforcement is
  /// authoritative on the order response, not on this pre-flight check, so a
  /// cold start or an unconfigured tenant must never block a sale.
  static Future<bool> _allowFromAppSettings(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    AppSettings? settings;
    try {
      settings = context.read<AppSettingsProvider>().appSettings;
    } catch (_) {
      // Some isolated widget tests do not register the settings provider.
      return true;
    }
    if (settings == null) return true;

    final resolved =
        AppSettingsProvider.resolveCompanySubscriptionFallback(settings);
    // Enforcement is explicitly enabled but the value did not parse, so the
    // state is genuinely unverifiable rather than simply unconfigured.
    if (resolved == null) return _showUnableToVerify(context, provider);

    switch (resolved.status) {
      case CompanySubscriptionStatus.warning:
        return _showWarning(context, resolved);
      case CompanySubscriptionStatus.blocked:
        await showBlocked(context, resolved);
        return false;
      case CompanySubscriptionStatus.active:
      case CompanySubscriptionStatus.unknown:
        return true;
    }
  }

  static Future<bool> handleBackendResponse(
    BuildContext context,
    dynamic response,
  ) async {
    if (response is! Map) return false;
    final code = response['code']?.toString().toUpperCase();
    final httpStatus = int.tryParse(response['http_status']?.toString() ?? '');
    if (code != 'SUBSCRIPTION_BLOCKED' && httpStatus != 403) return false;

    final message =
        response['message']?.toString() ?? 'subscription.blocked_default'.tr;
    final url = response['manage_subscription_url']?.toString();
    final provider = context.read<SubscriptionProvider>();
    await provider.markBlockedFromBackend(
      message: message,
      manageSubscriptionUrl: url,
    );
    if (!context.mounted) return true;
    await showBlocked(context, provider.subscription!);
    return true;
  }

  static Future<bool> _showWarning(
    BuildContext context,
    CompanySubscription subscription,
  ) async {
    final branding = await _loadBranding(context);
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => SubscriptionStatusDialog(
        variant: SubscriptionDialogVariant.warning,
        title: subscription.message,
        message: '',
        companyName: branding.companyName,
        logoFilePath: branding.logoFilePath,
        logoUrl: branding.logoUrl,
        primaryLabel: 'general.continue_label'.tr,
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    return result ?? false;
  }

  static Future<void> showBlocked(
    BuildContext context,
    CompanySubscription subscription,
  ) async {
    final branding = await _loadBranding(context);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => SubscriptionStatusDialog(
        variant: SubscriptionDialogVariant.blocked,
        title: subscription.message,
        message: '',
        companyName: branding.companyName,
        logoFilePath: branding.logoFilePath,
        logoUrl: branding.logoUrl,
        primaryLabel: subscription.manageSubscriptionUrl != null
            ? 'subscription.manage_subscription'.tr
            : 'subscription.contact_administrator'.tr,
        onPrimaryPressed: () {
          Navigator.of(dialogContext).pop();
          final rawUrl = subscription.manageSubscriptionUrl;
          final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  static Future<bool> _showUnableToVerify(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    final branding = await _loadBranding(context);
    if (!context.mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => SubscriptionStatusDialog(
        variant: SubscriptionDialogVariant.unavailable,
        title: 'subscription.unable_verify'.tr,
        message: provider.errorMessage ??
            'subscription.status_unverified'.tr,
        companyName: branding.companyName,
        logoFilePath: branding.logoFilePath,
        logoUrl: branding.logoUrl,
        primaryLabel: 'general.retry'.tr,
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (retry != true) return false;
    await provider.refresh();
    if (!context.mounted) return false;
    return ensureOrderSubmissionAllowed(context, refreshIfStale: false);
  }

  static Future<_SubscriptionBranding> _loadBranding(
    BuildContext context,
  ) async {
    AdminSettingsProvider? adminSettings;
    try {
      adminSettings = context.read<AdminSettingsProvider>();
    } catch (_) {
      // Some isolated widget tests do not register the branding provider.
    }

    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name')?.trim();
    return _SubscriptionBranding(
      companyName:
          companyName == null || companyName.isEmpty ? 'CloudPOS' : companyName,
      logoFilePath: adminSettings?.logoFilePath,
      logoUrl: adminSettings?.logoUrl,
    );
  }
}

class _SubscriptionBranding {
  const _SubscriptionBranding({
    required this.companyName,
    this.logoFilePath,
    this.logoUrl,
  });

  final String companyName;
  final String? logoFilePath;
  final String? logoUrl;
}
