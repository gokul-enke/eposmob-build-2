import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_inactivity_guard.dart';
import 'package:pos_machine/features/kiosk/presentation/theme/kiosk_design_system.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskFlowScaffold extends StatelessWidget {
  final String title;
  final String? stepLabel;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  const KioskFlowScaffold({
    super.key,
    required this.title,
    required this.child,
    this.stepLabel,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return KioskInactivityGuard(
      child: Scaffold(
        backgroundColor: ColorManager.kBgLightColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KioskSpacing.md,
                  KioskSpacing.md,
                  KioskSpacing.md,
                  0,
                ),
                child: _FlowHeader(
                  title: title,
                  stepLabel: stepLabel,
                  onBack: onBack ?? () => Navigator.of(context).maybePop(),
                  trailing: trailing,
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: child,
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

class _FlowHeader extends StatelessWidget {
  final String title;
  final String? stepLabel;
  final VoidCallback onBack;
  final Widget? trailing;

  const _FlowHeader({
    required this.title,
    required this.stepLabel,
    required this.onBack,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KioskRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KioskSpacing.sm,
          vertical: KioskSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton(
                onPressed: onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryWithOpacity10,
                  foregroundColor: ColorManager.kPrimaryColor,
                ),
              ),
            ),
            const SizedBox(width: KioskSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KioskType.pageTitle.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width < 500 ? 22 : 26,
                ),
              ),
            ),
            if (stepLabel != null) ...[
              const SizedBox(width: KioskSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryWithOpacity10,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stepLabel!,
                  style: const TextStyle(
                    color: ColorManager.kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: KioskSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class KioskSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const KioskSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KioskSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KioskRadius.card),
        border: Border.all(color: const Color(0xFFE5EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class KioskPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const KioskPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 24),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KioskType.action.copyWith(fontSize: 18),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryColor,
          disabledBackgroundColor: ColorManager.kGreyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KioskRadius.control),
          ),
        ),
      ),
    );
  }
}

class KioskSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const KioskSectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: KioskType.sectionTitle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: KioskType.supporting,
          ),
        ],
      ],
    );
  }
}
