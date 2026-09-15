import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_language_sheet.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/localization_service.dart';

class KioskHeader extends StatelessWidget {
  final String storeName;
  final VoidCallback? onCancelPressed;

  const KioskHeader({
    super.key,
    required this.storeName,
    this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final showLabels = width >= 920;

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? KioskSpacing.md : KioskSpacing.xl,
        vertical: KioskSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KioskRadius.card),
        border: Border.all(color: const Color(0xFFE2E9F3)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 48 : 54,
            height: compact ? 48 : 54,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(KioskRadius.control),
            ),
            child: Image.asset(
              'assets/logo/cloudposlogo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.storefront_rounded,
                color: ColorManager.kPrimaryColor,
              ),
            ),
          ),
          SizedBox(width: compact ? KioskSpacing.sm : KioskSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KioskType.pageTitle.copyWith(
                    fontSize: compact ? 22 : 26,
                  ),
                ),
                if (!compact)
                  const Text(
                    'Choose products to build your order',
                    style: KioskType.supporting,
                  ),
              ],
            ),
          ),
          const SizedBox(width: KioskSpacing.sm),
          _HeaderAction(
            icon: Icons.language_rounded,
            label: showLabels
                ? kioskLanguageLabel(LocalizationService.locale)
                : null,
            tooltip: 'Change language',
            onPressed: () => showKioskLanguageSheet(context),
          ),
          if (onCancelPressed != null) ...[
            const SizedBox(width: KioskSpacing.sm),
            _HeaderAction(
              icon: Icons.close_rounded,
              label: showLabels ? 'Cancel' : null,
              tooltip: 'Cancel order',
              onPressed: onCancelPressed,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 23),
        label: label == null ? const SizedBox.shrink() : Text(label!),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorManager.kTitleTextColor,
          backgroundColor: Colors.white,
          minimumSize: Size(label == null ? 56 : 124, 56),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 13 : 16),
          side: const BorderSide(color: Color(0xFFDCE5F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KioskRadius.control),
          ),
        ),
      ),
    );
  }
}
