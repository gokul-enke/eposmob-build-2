import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';

/// Shared responsive helpers for printer settings screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kPrinterPhoneBreakpoint = kSettingsPhoneBreakpoint;

double printerHorizontalPadding(double width) =>
    settingsHorizontalPadding(width);

double printerVerticalPadding(double width) => settingsVerticalPadding(width);

bool printerIsCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kPrinterPhoneBreakpoint;

EdgeInsets printerCardPadding(BuildContext context) =>
    EdgeInsets.all(printerIsCompact(context) ? 14 : 20);

double printerSectionGap(BuildContext context) =>
    printerIsCompact(context) ? 12 : 16;

/// Printer page shell with a quiet background and responsive padding.
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
    final width = MediaQuery.sizeOf(context).width;
    final insets = padding ??
        EdgeInsets.symmetric(
          horizontal: printerHorizontalPadding(width),
          vertical: printerVerticalPadding(width),
        );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(padding: insets, child: child)
            : Padding(padding: insets, child: SizedBox.expand(child: child)),
      ),
    );
  }
}

/// Flat bordered surface for printer controls.
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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E7EE)),
      ),
      child: Padding(padding: padding, child: child),
    );
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

/// Horizontally scrollable selector for printer and shared-PDF profiles.
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
    ('PDF Sharing', 'PDF Sharing'),
  ];

  static String _tabLabel(String id, {required bool compact}) {
    switch (id) {
      case 'Billing':
        return compact
            ? 'printer_settings.tab_billing_short'.tr
            : 'printer_settings.tab_billing'.tr;
      case 'Quotation':
        return compact
            ? 'printer_settings.tab_quotation_short'.tr
            : 'printer_settings.tab_quotation'.tr;
      case 'Kitchen':
        return compact
            ? 'printer_settings.tab_kitchen_short'.tr
            : 'printer_settings.tab_kitchen'.tr;
      case 'Barcode':
        return compact
            ? 'printer_settings.tab_barcode_short'.tr
            : 'printer_settings.tab_barcode'.tr;
      case 'PDF Sharing':
        return compact
            ? 'printer_settings.tab_pdf_short'.tr
            : 'printer_settings.tab_pdf'.tr;
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final tabs = _tabs
          .map((tab) => _PrinterTabChip(
                label: _tabLabel(tab.$1, compact: compact),
                icon: switch (tab.$1) {
                  'Billing' => Icons.receipt_long_outlined,
                  'Quotation' => Icons.description_outlined,
                  'Kitchen' => Icons.restaurant_outlined,
                  'Barcode' => Icons.qr_code_rounded,
                  _ => Icons.picture_as_pdf_outlined,
                },
                isSelected: selectedType == tab.$1,
                onTap: () => onSelected(tab.$1),
              ))
          .toList();
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDDE3EB))),
        ),
        child: compact
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: tabs),
              )
            : Row(children: tabs.map((tab) => Expanded(child: tab)).toList()),
      );
    });
  }
}

class _PrinterTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PrinterTabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? ColorManager.kPrimaryColor : const Color(0xFF596579);
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? ColorManager.kPrimaryColor.withValues(alpha: 0.06)
                  : Colors.transparent,
              border: Border(
                  bottom: BorderSide(
                width: 3,
                color: isSelected
                    ? ColorManager.kPrimaryColor
                    : Colors.transparent,
              )),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0,
                    color,
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary B2C / B2B selector with contextual helper text.
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            width: isCompact ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 18,
              vertical: isCompact ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? const Color(0xFFDDE3EB) : Colors.transparent,
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
      segmentPill(
        'B2C',
        isCompact
            ? 'printer_settings.segment_b2c'.tr
            : 'printer_settings.segment_b2c_full'.tr,
      ),
      segmentPill(
        'B2B',
        isCompact
            ? 'printer_settings.segment_b2b'.tr
            : 'printer_settings.segment_b2b_full'.tr,
      ),
    ];

    final selectorRow = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEFF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          isCompact ? Expanded(child: pills[0]) : pills[0],
          const SizedBox(width: 4),
          isCompact ? Expanded(child: pills[1]) : pills[1],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selectorRow,
        const SizedBox(height: 8),
        Text(
          helperText,
          // buildCustomStyle bakes in TextOverflow.ellipsis, which clips to a
          // single line unless maxLines is given explicitly.
          maxLines: 3,
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
        final isStacked = constraints.maxWidth < kPrinterPhoneBreakpoint ||
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

        final dropdown = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE3EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Colors.white,
                focusColor: ColorManager.kPrimaryColor.withValues(alpha: 0.12),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0,
                  ColorManager.textColor,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
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
              maxLines: 2,
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
            maxLines: 3,
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
class PrinterSettingsSplitLayout extends StatefulWidget {
  final Widget settingsColumn;
  final Widget printerColumn;
  final double breakpoint;

  const PrinterSettingsSplitLayout({
    super.key,
    required this.settingsColumn,
    required this.printerColumn,
    this.breakpoint = 900,
  });

  @override
  State<PrinterSettingsSplitLayout> createState() =>
      _PrinterSettingsSplitLayoutState();
}

class _PrinterSettingsSplitLayoutState
    extends State<PrinterSettingsSplitLayout> {
  // IntrinsicHeight was tried first and rejected: it queries children for
  // intrinsic dimensions, and PrinterDropdownField's LayoutBuilder cannot
  // answer that query — it throws ("RenderBox was not laid out") the moment a
  // LayoutBuilder ends up inside an IntrinsicHeight subtree. Measuring each
  // column's real layout size and feeding the larger one back in as a minimum
  // height avoids intrinsics entirely, so it works with LayoutBuilder,
  // scrollables, and everything else a column might contain.
  double? _settingsHeight;
  double? _printerHeight;

  void _reportSettingsHeight(double height) => _reportHeight(
        height,
        current: _settingsHeight,
        apply: (value) => _settingsHeight = value,
      );

  void _reportPrinterHeight(double height) => _reportHeight(
        height,
        current: _printerHeight,
        apply: (value) => _printerHeight = value,
      );

  void _reportHeight(
    double height, {
    required double? current,
    required void Function(double value) apply,
  }) {
    if (current != null && (current - height).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => apply(height));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < widget.breakpoint;

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.settingsColumn,
              SizedBox(height: printerSectionGap(context)),
              widget.printerColumn,
            ],
          );
        }

        final equalHeight = _settingsHeight == null || _printerHeight == null
            ? null
            : math.max(_settingsHeight!, _printerHeight!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _EqualHeightColumn(
                minHeight: equalHeight,
                onNaturalHeight: _reportSettingsHeight,
                child: widget.settingsColumn,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 6,
              child: _EqualHeightColumn(
                minHeight: equalHeight,
                onNaturalHeight: _reportPrinterHeight,
                child: widget.printerColumn,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Stretches [child] (the card itself, background and border included) up to
/// [minHeight], while still reporting the child's true unstretched height
/// back through [onNaturalHeight] — so the reported value never includes
/// space this widget itself added, otherwise two columns fed off each
/// other's height would only ever ratchet upward and never shrink back down
/// when content does.
///
/// The natural height is measured off an offstage copy of [child] — offstage
/// so it never paints or receives hits — while the visible copy is stretched
/// directly via [ConstrainedBox], so the two cards' white boxes actually end
/// at the same height instead of one ending early with blank page background
/// underneath it.
class _EqualHeightColumn extends StatelessWidget {
  final double? minHeight;
  final ValueChanged<double> onNaturalHeight;
  final Widget child;

  const _EqualHeightColumn({
    required this.minHeight,
    required this.onNaturalHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Stack's default loose fit only bounds width from above, it doesn't
    // force it — SizedBox(width: infinity) is what keeps both copies at the
    // column's full width, matching how they rendered before this widget
    // stretched height at all.
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        Offstage(
          child: SizedBox(
            width: double.infinity,
            child: _MeasureSize(onChange: onNaturalHeight, child: child),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight ?? 0),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height after every layout pass, without
/// altering the child's size or the constraints it receives.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  _RenderMeasureSize createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
      BuildContext context, _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  ValueChanged<double> onChange;
  double? _reportedHeight;

  _RenderMeasureSize(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reportedHeight != height) {
      _reportedHeight = height;
      onChange(height);
    }
  }
}

/// Small muted chip that states the scope of a settings group.
///
/// Used to make it explicit whether a control is per-profile or app-wide,
/// so a shared setting can never be mistaken for a tab-local one.
class PrinterScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const PrinterScopeChip({
    super.key,
    required this.label,
    this.icon = Icons.public_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.10,
              Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card whose body is hidden behind a tappable header.
///
/// Keeps rarely-used groups (advanced/shared options) off the default view
/// without removing them from the page, so the layout stays stable.
class PrinterDisclosureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? scopeLabel;
  final bool initiallyExpanded;

  /// Renders as a flat bordered panel instead of an elevated card, so one
  /// disclosure can nest inside another without doubling the card chrome.
  final bool embedded;

  /// When false the body is always visible and the header loses its chevron
  /// and tap target. Used for panels nested inside another disclosure, where a
  /// second level of hiding is just an extra click.
  final bool collapsible;

  /// Optional action shown next to the chevron. Kept out of the tap target so
  /// pressing it does not toggle the section.
  final Widget? trailing;
  final Widget child;

  const PrinterDisclosureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.scopeLabel,
    this.initiallyExpanded = false,
    this.embedded = false,
    this.collapsible = true,
    this.trailing,
  });

  @override
  State<PrinterDisclosureCard> createState() => _PrinterDisclosureCardState();
}

class _PrinterDisclosureCardState extends State<PrinterDisclosureCard> {
  late bool _isExpanded = widget.initiallyExpanded || !widget.collapsible;

  @override
  Widget build(BuildContext context) {
    final isCompact = printerIsCompact(context);
    final iconSize =
        widget.embedded ? (isCompact ? 30.0 : 34.0) : (isCompact ? 36.0 : 42.0);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: iconSize,
          width: iconSize,
          decoration: BoxDecoration(
            color: widget.embedded ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
            border: widget.embedded
                ? Border.all(color: Colors.grey.shade200)
                : null,
          ),
          child: Icon(
            widget.icon,
            color: Colors.grey.shade700,
            size: widget.embedded ? 18 : (isCompact ? 20 : 22),
          ),
        ),
        SizedBox(width: isCompact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  widget.embedded
                      ? FontSize.s14
                      : (isCompact ? FontSize.s15 : FontSize.s16),
                  0.20,
                  ColorManager.textColor,
                ),
              ),
              if (widget.subtitle != null) ...[
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  widget.subtitle!,
                  maxLines: 2,
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
        ),
        if (widget.scopeLabel != null && !isCompact) ...[
          const SizedBox(width: 12),
          PrinterScopeChip(label: widget.scopeLabel!),
        ],
        if (widget.collapsible) ...[
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              Icons.expand_more_rounded,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );

    final gap = printerSectionGap(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: widget.collapsible
                  ? InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(10),
                      child: header,
                    )
                  : header,
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 12),
              widget.trailing!,
            ],
          ],
        ),
        if (widget.scopeLabel != null && isCompact) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PrinterScopeChip(label: widget.scopeLabel!),
          ),
        ],
        if (_isExpanded) ...[
          SizedBox(height: gap),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: gap),
          widget.child,
        ],
      ],
    );

    if (widget.embedded) {
      return Container(
        padding: EdgeInsets.all(isCompact ? 12 : 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: content,
      );
    }

    return PrinterSettingsCard(
      padding: printerCardPadding(context),
      child: content,
    );
  }
}
