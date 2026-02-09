import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 1200;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.title'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWide ? 260 : 220,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.08,
                      ),
                      itemCount: 4, // Added Language + Last Sync
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _SettingsCard(
                              title: 'settings.whatsapp'.tr,
                              iconPath: ImageAssets.whatsappIcon,
                              onTap: () {
                                Get.find<SideBarController>().index.value =
                                    63; // Navigate to WhatsApp Settings
                              },
                            );
                          case 1:
                            return _SettingsCardWithIcon(
                              title: 'settings.company_info'.tr,
                              icon: FontAwesomeIcons.building,
                              backgroundColor: const Color(0xFFE8F5E9),
                              iconColor: const Color(0xFF2E7D32),
                              onTap: () {
                                Get.find<SideBarController>().index.value =
                                    64; // Navigate to Company Info screen
                              },
                            );
                          case 2:
                            return _SettingsCardWithIcon(
                              title: 'settings.language'.tr,
                              icon: FontAwesomeIcons.globe,
                              backgroundColor: const Color(0xFFE3F2FD),
                              iconColor: const Color(0xFF1565C0),
                              onTap: () => _showLanguagePicker(context),
                            );
                          case 3:
                            return FutureBuilder<String?>(
                              future: SharedPreferenceProvider()
                                  .getLastProductSyncIso(),
                              builder: (context, snapshot) {
                                final isoTime = snapshot.data;
                                final displayTime = snapshot.connectionState ==
                                    ConnectionState.waiting
                                  ? 'Loading...'
                                  : (isoTime == null
                                    ? 'Not synced yet'
                                    : DateHelper.formatISODateToIST(
                                      isoTime,
                                      ));
                                return _SettingsInfoCard(
                                  title: 'Last Product Sync',
                                  subtitle: displayTime,
                                  icon: FontAwesomeIcons.clockRotateLeft,
                                  backgroundColor: const Color(0xFFFFF3E0),
                                  iconColor: const Color(0xFFEF6C00),
                                  onTap: isoTime == null
                                      ? null
                                      : () => _showLastSyncDialog(
                                          context,
                                          displayTime,
                                        ),
                                );
                              },
                            );
                          default:
                            return const SizedBox
                                .shrink(); // Return empty widget for invalid indices
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  void _showLastSyncDialog(BuildContext context, String displayTime) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Last Product Sync'),
          content: Text(displayTime),
          actions: [
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
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        offsetValue: const Offset(1, 1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (iconColor ?? const Color(0xFF25D366)).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final iconSize = side * 0.40; // scale icon to card size (smaller)
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: iconSize,
                    width: iconSize,
                    child: WebsafeSvg.asset(
                      iconPath,
                      fit: BoxFit.contain,
                      // WhatsApp green
                      colorFilter: ColorFilter.mode(
                        iconColor ?? const Color(0xFF25D366),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                  ),
                ],
              );
            },
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: BuildBoxShadowContainer(
          circleRadius: 14,
          offsetValue: _isHovered ? const Offset(2, 3) : const Offset(1, 1),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.iconColor.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                final iconSize = side * 0.35;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon container with background
                    Container(
                      height: iconSize,
                      width: iconSize,
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: FaIcon(
                          widget.icon,
                          color: widget.iconColor,
                          size: iconSize * 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.21,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                );
              },
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
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        offsetValue: const Offset(1, 1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final iconSize = side * 0.35;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: iconSize,
                    width: iconSize,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: FaIcon(
                        icon,
                        color: iconColor,
                        size: iconSize * 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
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
                      FontSize.s10,
                      0.15,
                      ColorManager.textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
