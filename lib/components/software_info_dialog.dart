import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class SoftwareInfoDialog extends StatefulWidget {
  const SoftwareInfoDialog({
    super.key,
    this.packageInfoFuture,
  });

  final Future<PackageInfo>? packageInfoFuture;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SoftwareInfoDialog(),
    );
  }

  @override
  State<SoftwareInfoDialog> createState() => _SoftwareInfoDialogState();
}

class _SoftwareInfoDialogState extends State<SoftwareInfoDialog> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = widget.packageInfoFuture ?? PackageInfo.fromPlatform();
  }

  String _versionText(PackageInfo packageInfo) {
    final version = packageInfo.version.trim();
    final buildNumber = packageInfo.buildNumber.trim();

    if (version.isEmpty) {
      return 'app.version_unavailable'.tr;
    }
    if (buildNumber.isEmpty) {
      return version;
    }
    return '$version.$buildNumber';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenWidth < 600 ? double.infinity : 420,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: ColorManager.kPrimaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'app.software_information'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'general.close'.tr,
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 92,
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                }

                final version = snapshot.hasData
                    ? _versionText(snapshot.data!)
                    : 'app.version_unavailable'.tr;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'app.software'.tr,
                        value: 'app.title'.tr,
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _InfoRow(
                        label: 'app.version'.tr,
                        value: version,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'general.close'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s13,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.20,
                Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
