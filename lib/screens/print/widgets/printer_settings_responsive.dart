import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';

/// Shared responsive helpers for printer settings screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kPrinterPhoneBreakpoint = kSettingsPhoneBreakpoint;

double printerHorizontalPadding(double width) => settingsHorizontalPadding(width);

double printerVerticalPadding(double width) => settingsVerticalPadding(width);

bool printerIsCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kPrinterPhoneBreakpoint;

EdgeInsets printerCardPadding(BuildContext context) =>
    EdgeInsets.all(printerIsCompact(context) ? 14 : 20);

double printerSectionGap(BuildContext context) =>
    printerIsCompact(context) ? 12 : 16;

/// White page shell with SafeArea and responsive padding.
class PrinterSettingsPageShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const PrinterSettingsPageShell({
    super.key,
    required this.child,
    this.scrollable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      scrollable: scrollable,
      padding: padding,
      child: child,
    );
  }
}

/// Card container matching the Shopify-like settings style.
class PrinterSettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PrinterSettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return SettingsContentCard(padding: padding, child: child);
  }
}

/// Section header with optional icon chip and trailing action.
class PrinterSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;

  const PrinterSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? ColorManager.kPrimaryColor;
    final isCompact = printerIsCompact(context);
    final iconSize = isCompact ? 36.0 : 42.0;
    final iconGlyphSize = isCompact ? 20.0 : 22.0;

    final iconChip = Container(
      height: iconSize,
      width: iconSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
      ),
      child: Icon(icon, color: color, size: iconGlyphSize),
    );

    final titleBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              isCompact ? FontSize.s15 : FontSize.s16,
              0.20,
              ColorManager.textColor,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: isCompact ? 2 : 4),
            Text(
              subtitle!,
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.regular,
                isCompact ? FontSize.s11 : FontSize.s12,
                0.10,
                Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );

    if (isCompact && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [iconChip, const SizedBox(width: 10), titleBlock],
          ),
          const SizedBox(height: 10),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconChip,
        SizedBox(width: isCompact ? 10 : 12),
        titleBlock,
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Horizontally scrollable tab bar for Billing / Quotation / Kitchen / Barcode.
class PrinterTabSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onSelected;

  const PrinterTabSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  static const _tabs = [
    ('Billing', 'Billing Printer'),
    ('Quotation', 'Quotation Printer'),
    ('Kitchen', 'Kitchen Printer'),
    ('Barcode', 'Barcode Printer'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < kPrinterPhoneBreakpoint;

    final tabs = _tabs
        .map(
          (tab) => _PrinterTabChip(
            label: isCompact ? tab.$1 : tab.$2,
            isSelected: selectedType == tab.$1,
            onTap: () => onSelected(tab.$1),
            minWidth: isCompact ? 88.0 : 120.0,
          ),
        )
        .toList();

    if (isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Row(children: tabs),
      );
    }

    return Row(children: tabs.map((t) => Expanded(child: t)).toList());
  }
}

class _PrinterTabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double minWidth;

  const _PrinterTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 44,
            constraints: BoxConstraints(minWidth: minWidth),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? ColorManager.kPrimaryColor
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? ColorManager.kPrimaryColor
                    : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.18,
                  isSelected ? Colors.white : ColorManager.textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// B2C / B2B segment pills with helper text below.
class PrinterSegmentSelector extends StatelessWidget {
  final String selectedSegment;
  final ValueChanged<String> onSelected;
  final String helperText;

  const PrinterSegmentSelector({
    super.key,
    required this.selectedSegment,
    required this.onSelected,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact =
        MediaQuery.of(context).size.width < kPrinterPhoneBreakpoint;

    Widget segmentPill(String segment, String label) {
      final isActive = selectedSegment == segment;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(segment),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 44,
            width: isCompact ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? ColorManager.kPrimaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? ColorManager.kPrimaryColor
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.18,
                  isActive
                      ? ColorManager.kPrimaryColor
                      : ColorManager.textColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final pills = [
      segmentPill('B2C', isCompact ? 'B2C' : 'B2C (Retail)'),
      segmentPill('B2B', isCompact ? 'B2B' : 'B2B (Business)'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Row(
            children: [
              Expanded(child: pills[0]),
              const SizedBox(width: 8),
              Expanded(child: pills[1]),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills,
          ),
        const SizedBox(height: 8),
        Text(
          helperText,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s11,
            0.10,
            Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Label + dropdown that stacks vertically on narrow widths.
class PrinterDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const PrinterDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked =
            constraints.maxWidth < kPrinterPhoneBreakpoint ||
            printerIsCompact(context);

        final labelWidget = Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s13,
            0.20,
            ColorManager.textColor.withValues(alpha: 0.85),
          ),
        );

        final dropdown = BuildBoxShadowContainer(
          circleRadius: 10,
          showShadow: false,
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade50,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items,
            onChanged: onChanged,
          ),
        );

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: 8),
              dropdown,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: constraints.maxWidth * 0.28, child: labelWidget),
            const SizedBox(width: 12),
            Expanded(child: dropdown),
          ],
        );
      },
    );
  }
}

/// Muted info strip (device count, scanning status).
class PrinterInfoStrip extends StatelessWidget {
  final String text;
  final IconData icon;

  const PrinterInfoStrip({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.15,
                ColorManager.kGreyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered loading placeholder for the settings page.
class PrinterSettingsLoadingState extends StatelessWidget {
  const PrinterSettingsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PrinterSettingsCard(
        padding: printerCardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading printer settings…',
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.18,
                ColorManager.kGreyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state placeholder for the printer list.
class PrinterEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const PrinterEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.print_disabled_rounded,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.20,
              ColorManager.kGreyColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.10,
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column layout that stacks on phones.
class PrinterSettingsSplitLayout extends StatelessWidget {
  final Widget settingsColumn;
  final Widget printerColumn;
  final double breakpoint;

  const PrinterSettingsSplitLayout({
    super.key,
    required this.settingsColumn,
    required this.printerColumn,
    this.breakpoint = kPrinterPhoneBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < breakpoint;

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              settingsColumn,
              SizedBox(height: printerSectionGap(context)),
              printerColumn,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: settingsColumn),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: printerColumn),
          ],
        );
      },
    );
  }
}
