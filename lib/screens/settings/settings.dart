import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/orientation_helper.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:pos_machine/services/session_reset_service.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/screens/settings/realtime_sync_test_page.dart';
import 'package:pos_machine/screens/settings/widgets/offline_data_page.dart';
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
        backgroundColor: Colors.white,
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
          backgroundColor: Colors.white,
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
        backgroundColor: Colors.white,
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

  Future<void> _showOrientationModePicker() async {
    final prefs = SharedPreferenceProvider();
    final current = await prefs.getOrientationMode();
    if (!mounted) return;

    String selected = current;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Screen Orientation'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Auto'),
                subtitle:
                    const Text('Portrait on phones, landscape on tablets'),
                value: OrientationHelper.modeAuto,
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v!),
              ),
              RadioListTile<String>(
                title: const Text('Portrait'),
                value: OrientationHelper.modePortrait,
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v!),
              ),
              RadioListTile<String>(
                title: const Text('Landscape'),
                value: OrientationHelper.modeLandscape,
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

    await prefs.saveOrientationMode(result);
    await OrientationHelper.apply(modeOverride: result);
    if (!mounted) return;
    setState(() {});
    showScaffold(context: context, message: 'Screen orientation updated');
  }

  Future<void> _toggleDeveloperMode() async {
    try {
      final wasEnabled = await DevelopmentPrinterService.isEnabled();
      final isEnabled = !wasEnabled;
      await DevelopmentPrinterService.setEnabled(isEnabled);
      if (!mounted) return;
      setState(() {});
      showScaffold(
        context: context,
        message: isEnabled
            ? 'Developer Mode enabled. Select Development Printer in Printer settings.'
            : 'Developer Mode disabled. Physical printer settings restored.',
      );
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Could not update Developer Mode: $error',
      );
    }
  }

  List<Widget> _buildSettingsCards(BuildContext context) {
    return [
      // _SettingsCard(
      //   title: 'settings.whatsapp'.tr,
      //   iconPath: ImageAssets.whatsappIcon,
      //   onTap: () {
      //     Get.find<SideBarController>().index.value =
      //         63; // Navigate to WhatsApp Settings
      //   },
      // ),
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
      Consumer<LocalProductProvider>(
        builder: (context, productProvider, _) {
          final count = productProvider.sellableProducts.length;
          final subtitle = count > 0
              ? 'settings_ui.products_cached'.trParams({'count': '$count'})
              : 'settings_ui.view_cached_data'.tr;
          return _SettingsInfoCard(
            title: 'settings_ui.offline_data'.tr,
            subtitle: subtitle,
            icon: const FaIcon(
              FontAwesomeIcons.database,
              color: Color(0xFF2E7D32),
              size: 22,
            ),
            backgroundColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            onTap: () {
              Get.find<SideBarController>().index.value =
                  OfflineDataPage.sidebarIndex;
            },
          );
        },
      ),
      FutureBuilder<String?>(
        future: SharedPreferenceProvider().getLastProductSyncIso(),
        builder: (context, snapshot) {
          final isoTime = snapshot.data;
          final displayTime =
              snapshot.connectionState == ConnectionState.waiting
                  ? 'settings_ui.loading'.tr
                  : (isoTime == null
                      ? 'settings_ui.not_synced'.tr
                      : DateHelper.formatISODateToIST(isoTime));
          return _SettingsInfoCard(
            title: 'settings_ui.last_product_sync'.tr,
            subtitle: displayTime,
            icon: const FaIcon(
              FontAwesomeIcons.clockRotateLeft,
              color: Color(0xFFEF6C00),
              size: 22,
            ),
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
        title: 'settings_ui.resync_products'.tr,
        icon: FontAwesomeIcons.arrowsRotate,
        backgroundColor: const Color(0xFFEDE7F6),
        iconColor: const Color(0xFF5E35B1),
        onTap: () async {
          await _resyncProducts();
        },
      ),
      if (kDebugMode)
        _SettingsInfoCard(
          title: 'settings_ui.realtime_sync_tester'.tr,
          subtitle: 'settings_ui.realtime_sync_tester_subtitle'.tr,
          icon: const FaIcon(
            FontAwesomeIcons.satelliteDish,
            color: Color(0xFF00695C),
            size: 22,
          ),
          backgroundColor: const Color(0xFFE0F2F1),
          iconColor: const Color(0xFF00695C),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RealtimeSyncTestPage(),
              ),
            );
          },
        ),
      Consumer<BillingProvider>(
        builder: (context, billingProvider, _) {
          final isOfflineModeEnabled = billingProvider.isManualOfflineMode;
          return _SettingsInfoCard(
            title: 'settings_ui.offline_mode'.tr,
            subtitle: isOfflineModeEnabled
                ? 'settings_ui.manually_enabled'.tr
                : 'settings_ui.live_internet_status'.tr,
            icon: Icon(
              isOfflineModeEnabled ? Icons.wifi_off : Icons.wifi,
              color: isOfflineModeEnabled
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
              size: 22,
            ),
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
          final label = current == 'left'
              ? 'settings_ui.left'.tr
              : 'settings_ui.right'.tr;
          return _SettingsInfoCard(
            title: 'settings_ui.notification_position'.tr,
            subtitle: label,
            icon: const Icon(
              Icons.view_week,
              color: Color(0xFF1565C0),
              size: 22,
            ),
            backgroundColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            onTap: () async {
              await _showNotificationPositionPicker();
            },
          );
        },
      ),
      if (!kIsWeb)
        FutureBuilder<String>(
          future: SharedPreferenceProvider().getOrientationMode(),
          builder: (context, snapshot) {
            final current = snapshot.data ?? OrientationHelper.modeAuto;
            final orientationLabel = switch (current) {
              OrientationHelper.modePortrait => 'settings_ui.portrait'.tr,
              OrientationHelper.modeLandscape => 'settings_ui.landscape'.tr,
              _ => 'settings_ui.auto'.tr,
            };
            return _SettingsInfoCard(
              title: 'settings_ui.screen_orientation'.tr,
              subtitle: orientationLabel,
              icon: const Icon(
                Icons.screen_rotation,
                color: Color(0xFF3949AB),
                size: 22,
              ),
              backgroundColor: const Color(0xFFE8EAF6),
              iconColor: const Color(0xFF3949AB),
              onTap: () async {
                await _showOrientationModePicker();
              },
            );
          },
        ),
      FutureBuilder<bool>(
        future: DevelopmentPrinterService.isEnabled(),
        builder: (context, snapshot) {
          final isEnabled = snapshot.data ?? false;
          return _SettingsInfoCard(
            title: 'settings_ui.developer_mode'.tr,
            subtitle: isEnabled
                ? 'settings_ui.developer_on'.tr
                : 'settings_ui.developer_off'.tr,
            icon: FaIcon(
              FontAwesomeIcons.code,
              color:
                  isEnabled ? const Color(0xFF6A1B9A) : const Color(0xFF546E7A),
              size: 22,
            ),
            backgroundColor:
                isEnabled ? const Color(0xFFF3E5F5) : const Color(0xFFECEFF1),
            iconColor:
                isEnabled ? const Color(0xFF6A1B9A) : const Color(0xFF546E7A),
            onTap: _toggleDeveloperMode,
          );
        },
      ),
      _SettingsCardWithIcon(
        title: 'settings_ui.clear_local_storage'.tr,
        icon: FontAwesomeIcons.trashCan,
        backgroundColor: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFEF6C00),
        onTap: () async {
          await _clearLocalStorageAndLogout();
        },
      ),
      if (kDebugMode)
        _SettingsCardWithIcon(
          title: 'settings_ui.clear_product_cache_debug'.tr,
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
            subtitle: 'settings_ui.subtitle'.tr,
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
          backgroundColor: Colors.white,
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
          backgroundColor: Colors.white,
          title: Text('settings_ui.last_product_sync'.tr),
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
              child: Text('general.reset'.tr),
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

// class _SettingsCard extends StatelessWidget {
//   final String title;
//   final String iconPath;
//   final VoidCallback onTap;
//   final Color? iconColor;
//
//   const _SettingsCard({
//     super.key,
//     required this.title,
//     required this.iconPath,
//     required this.onTap,
//     this.iconColor = const Color(0xFF25D366),
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final accent = iconColor ?? const Color(0xFF25D366);
//
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14),
//         child: BuildBoxShadowContainer(
//           circleRadius: 14,
//           showShadow: true,
//           blurRadius: 10,
//           offsetValue: const Offset(0, 3),
//           border: Border.all(color: accent.withOpacity(0.18)),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Container(
//                   height: 48,
//                   width: 48,
//                   decoration: BoxDecoration(
//                     color: accent.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Center(
//                     child: SizedBox(
//                       height: 28,
//                       width: 28,
//                       child: WebsafeSvg.asset(
//                         iconPath,
//                         fit: BoxFit.contain,
//                         colorFilter: ColorFilter.mode(
//                           accent,
//                           BlendMode.srcIn,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 14),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: buildCustomStyle(
//                     FontWeightManager.semiBold,
//                     FontSize.s14,
//                     0.21,
//                     ColorManager.textColor,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

class _SettingsCardWithIcon extends StatefulWidget {
  final String title;
  final FaIconData icon;
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
  final Widget icon;
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
                  child: Center(child: icon),
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
