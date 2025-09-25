import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:websafe_svg/websafe_svg.dart';

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
                'Settings',
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
                      itemCount: 3, // Updated count
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _SettingsCard(
                              title: 'WhatsApp Settings',
                              iconPath: ImageAssets.whatsappIcon,
                              onTap: () {
                                Get.find<SideBarController>().index.value =
                                    63; // Navigate to WhatsApp Settings
                              },
                            );
                          case 1:
                            return _SettingsCard(
                              title: 'Company Info',
                              iconPath: ImageAssets
                                  .reportIcon, // Using existing report icon
                              iconColor: Colors.green,
                              onTap: () {
                                Get.find<SideBarController>().index.value =
                                    64; // Navigate to Company Info screen
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
