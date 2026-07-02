import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:pos_machine/services/session_reset_service.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart'
    as custom_dialog_box;
import 'package:pos_machine/screens/dashboard/widgets/dashboard_responsive.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _resyncProducts() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: billingProvider.isManualOfflineMode
            ? 'Offline Mode is enabled. Disable it to resync products.'
            : 'No internet connection. Cannot resync products.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      await localProductProvider.fetchProductsFromAPI(refresh: true);

      if (localProductProvider.sellableProducts.isEmpty) {
        await syncProvider.syncAllData(context);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      if (localProductProvider.sellableProducts.isEmpty) {
        showScaffoldError(
          context: context,
          message:
              'Resync finished but no products were returned. Check tenant/API key or internet.',
        );
      } else {
        showScaffold(
          context: context,
          message:
              'Products resynced successfully (${localProductProvider.sellableProducts.length} items)',
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showScaffoldError(
        context: context,
        message: 'Failed to resync products: ${e.toString()}',
      );
    }
  }

  Future<void> _clearProductsDebug() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Product Cache'),
        content: const Text(
          'This will clear locally cached products and last product sync timestamp. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.resetProducts();
      await SharedPreferenceProvider().clearLastProductSyncIso();

      if (!mounted) return;
      showScaffold(
        context: context,
        message: 'Local product cache cleared (debug)',
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Failed to clear product cache: ${e.toString()}',
      );
    }
  }

  Future<void> _clearLocalStorageAndLogout() async {
    try {
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Local Storage'),
          content: const Text(
            'This will clear all local data except login credentials and log you out. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Clear & Logout',
                style: TextStyle(color: ColorManager.kButtonRed),
              ),
            ),
          ],
        ),
      );

      if (shouldClear != true) return;
      await SessionResetService.clearLocalStorageAndLogout(
        context,
        preserveRememberMe: true,
      );

      if (mounted) {
        showScaffold(
          context: context,
          message: 'Local storage cleared successfully',
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignInScreen()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error clearing local storage: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _toggleManualOfflineMode() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final enableOfflineMode = !billingProvider.isManualOfflineMode;

    await billingProvider.setManualOfflineMode(enableOfflineMode);

    if (!mounted) return;
    showScaffold(
      context: context,
      message: enableOfflineMode
          ? 'Offline Mode enabled. Online actions are now blocked.'
          : billingProvider.deviceHasInternet
              ? 'Offline Mode disabled. Online actions are available again.'
              : 'Offline Mode disabled, but internet is still unavailable.',
    );
  }

  Future<void> _showNotificationPositionPicker() async {
    final prefs = SharedPreferenceProvider();
    final current = await prefs.getNotificationPosition();
    if (!mounted) return;

    String selected = current;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Position'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Left'),
                value: 'left',
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v!),
              ),
              RadioListTile<String>(
                title: const Text('Center'),
                value: 'center',
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v!),
              ),
              RadioListTile<String>(
                title: const Text('Right'),
                value: 'right',
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(selected),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    await prefs.saveNotificationPosition(result);
    setNotificationPosition(result);
    custom_dialog_box.setNotificationPosition(result);
    if (!mounted) return;
    setState(() {});
    showScaffold(context: context, message: 'Notification position updated');
  }

  List<Widget> _buildSettingsCards(BuildContext context) {
    return [
      _SettingsCard(
        title: 'settings.whatsapp'.tr,
        iconPath: ImageAssets.whatsappIcon,
        onTap: () {
          Get.find<SideBarController>().index.value =
              63; // Navigate to WhatsApp Settings
        },
      ),
      _SettingsCardWithIcon(
        title: 'settings.company_info'.tr,
        icon: FontAwesomeIcons.building,
        backgroundColor: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
        onTap: () {
          Get.find<SideBarController>().index.value =
              64; // Navigate to Company Info screen
        },
      ),
      _SettingsCardWithIcon(
        title: 'settings.language'.tr,
        icon: FontAwesomeIcons.globe,
        backgroundColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        onTap: () => _showLanguagePicker(context),
      ),
      FutureBuilder<String?>(
        future: SharedPreferenceProvider().getLastProductSyncIso(),
        builder: (context, snapshot) {
          final isoTime = snapshot.data;
          final displayTime = snapshot.connectionState == ConnectionState.waiting
              ? 'Loading...'
              : (isoTime == null
                  ? 'Not synced yet'
                  : DateHelper.formatISODateToIST(isoTime));
          return _SettingsInfoCard(
            title: 'Last Product Sync',
            subtitle: displayTime,
            icon: FontAwesomeIcons.clockRotateLeft,
            backgroundColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFEF6C00),
            onTap: () => _showLastSyncDialog(
              context,
              displayTime,
              isoTime != null,
            ),
          );
        },
      ),
      _SettingsCardWithIcon(
        title: 'Resync Products',
        icon: FontAwesomeIcons.arrowsRotate,
        backgroundColor: const Color(0xFFEDE7F6),
        iconColor: const Color(0xFF5E35B1),
        onTap: () async {
          await _resyncProducts();
        },
      ),
      Consumer<BillingProvider>(
        builder: (context, billingProvider, _) {
          final isOfflineModeEnabled = billingProvider.isManualOfflineMode;
          return _SettingsInfoCard(
            title: 'Offline Mode',
            subtitle: isOfflineModeEnabled
                ? 'Manually enabled'
                : 'Uses live internet status',
            icon: isOfflineModeEnabled ? Icons.wifi_off : Icons.wifi,
            backgroundColor: isOfflineModeEnabled
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFE8F5E9),
            iconColor: isOfflineModeEnabled
                ? const Color(0xFFC62828)
                : const Color(0xFF2E7D32),
            onTap: () async {
              await _toggleManualOfflineMode();
            },
          );
        },
      ),
      FutureBuilder<String>(
        future: SharedPreferenceProvider().getNotificationPosition(),
        builder: (context, snapshot) {
          final current = snapshot.data ?? 'right';
          final label = current[0].toUpperCase() + current.substring(1);
          return _SettingsInfoCard(
            title: 'Notification Position',
            subtitle: label,
            icon: Icons.view_week,
            backgroundColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            onTap: () async {
              await _showNotificationPositionPicker();
            },
          );
        },
      ),
      _SettingsCardWithIcon(
        title: 'Clear Local Storage',
        icon: FontAwesomeIcons.trashCan,
        backgroundColor: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFEF6C00),
        onTap: () async {
          await _clearLocalStorageAndLogout();
        },
      ),
      if (kDebugMode)
        _SettingsCardWithIcon(
          title: 'Clear Product Cache (Debug)',
          icon: FontAwesomeIcons.broom,
          backgroundColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFC62828),
          onTap: () async {
            await _clearProductsDebug();
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsPageHeader(
            title: 'settings.title'.tr,
            subtitle: 'Manage integrations, sync, and app preferences',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: ResponsiveStatGrid(
                    padding: EdgeInsets.zero,
                    cardHeight: 168,
                    maxColumns: 4,
                    cards: _buildSettingsCards(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final currentCode = LocalizationService.locale.languageCode;
    showDialog(
      context: context,
      builder: (ctx) {
        String selected = currentCode;
        return AlertDialog(
          title: Text('settings.language_select'.tr),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'en',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('हिन्दी'),
                    value: 'hi',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('മലയാളം'),
                    value: 'ml',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('العربية'),
                    value: 'ar',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('general.cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                final newLocale = Locale(selected);
                await LocalizationService.updateLocale(newLocale);
                Get.updateLocale(newLocale);
                Get.back();
              },
              child: Text('general.ok'.tr),
            ),
          ],
        );
      },
    );
  }

  void _showLastSyncDialog(
    BuildContext context,
    String displayTime,
    bool hasSync,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Last Product Sync'),
          content: Text(displayTime),
          actions: [
            TextButton(
              onPressed: hasSync
                  ? () async {
                      await SharedPreferenceProvider()
                          .clearLastProductSyncIso();
                      if (mounted) {
                        setState(() {});
                      }
                      Get.back();
                    }
                  : null,
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Get.back(),
              child: Text('general.ok'.tr),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String iconPath;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsCard({
    super.key,
    required this.title,
    required this.iconPath,
    required this.onTap,
    this.iconColor = const Color(0xFF25D366),
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? const Color(0xFF25D366);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: BuildBoxShadowContainer(
          circleRadius: 14,
          showShadow: true,
          blurRadius: 10,
          offsetValue: const Offset(0, 3),
          border: Border.all(color: accent.withOpacity(0.18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: WebsafeSvg.asset(
                        iconPath,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          accent,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.21,
                    ColorManager.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCardWithIcon extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _SettingsCardWithIcon({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  State<_SettingsCardWithIcon> createState() => _SettingsCardWithIconState();
}

class _SettingsCardWithIconState extends State<_SettingsCardWithIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: BuildBoxShadowContainer(
            circleRadius: 14,
            showShadow: true,
            blurRadius: 10,
            offsetValue: _isHovered ? const Offset(0, 5) : const Offset(0, 3),
            border: Border.all(color: widget.iconColor.withOpacity(0.18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: FaIcon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SettingsInfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: BuildBoxShadowContainer(
          circleRadius: 14,
          showShadow: true,
          blurRadius: 10,
          offsetValue: const Offset(0, 3),
          border: Border.all(color: iconColor.withOpacity(0.18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(
                      icon,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.21,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.15,
                    ColorManager.textColor.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
