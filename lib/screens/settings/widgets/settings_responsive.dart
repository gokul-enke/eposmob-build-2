import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for settings screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kSettingsPhoneBreakpoint = 600;

double settingsHorizontalPadding(double width) =>
    width < kSettingsPhoneBreakpoint ? 12.0 : 20.0;

double settingsVerticalPadding(double width) =>
    width < kSettingsPhoneBreakpoint ? 12.0 : 16.0;

/// White page shell with responsive padding used by all settings screens.
class SettingsPageShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const SettingsPageShell({
    super.key,
    required this.child,
    this.scrollable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: settingsHorizontalPadding(size.width),
          vertical: settingsVerticalPadding(size.width),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                padding: resolvedPadding,
                child: child,
              )
            : Padding(
                padding: resolvedPadding,
                child: SizedBox.expand(child: child),
              ),
      ),
    );
  }
}

/// Primary page title with optional subtitle.
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SettingsPageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.10,
              Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Back navigation row + optional close button for sub-pages.
class SettingsSubPageHeader extends StatelessWidget {
  final String backLabel;
  final VoidCallback onBack;
  final VoidCallback? onClose;
  final String title;
  final String? subtitle;

  const SettingsSubPageHeader({
    super.key,
    required this.backLabel,
    required this.onBack,
    required this.title,
    this.onClose,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < kSettingsPhoneBreakpoint;

    final navRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CustomBackButton(
            onPressed: onBack,
            text: backLabel,
          ),
        ),
        if (onClose != null) SettingsCloseButton(onPressed: onClose!),
      ],
    );

    final titleBlock = SettingsPageHeader(title: title, subtitle: subtitle);

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          navRow,
          const SizedBox(height: 8),
          titleBlock,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        navRow,
        const SizedBox(height: 12),
        titleBlock,
      ],
    );
  }
}

/// Close button with a 44px tap target.
class SettingsCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SettingsCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: BuildBoxShadowContainer(
              width: 28,
              height: 28,
              circleRadius: 14,
              color: ColorManager.kPrimaryColor,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card container with subtle border and shadow.
class SettingsContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 14,
      showShadow: true,
      blurRadius: 10,
      offsetValue: const Offset(0, 3),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      color: Colors.white,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Section header inside a settings card.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < kSettingsPhoneBreakpoint;

    if (isCompact && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.20,
              ColorManager.textColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.10,
                Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s16,
                  0.20,
                  ColorManager.textColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.10,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Status badge pill (connected / disconnected, etc.).
class SettingsStatusBadge extends StatelessWidget {
  final String label;
  final bool isPositive;
  final IconData icon;

  const SettingsStatusBadge({
    super.key,
    required this.label,
    required this.isPositive,
    this.icon = Icons.check_circle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? const Color(0xFF128C7E) : Colors.red;
    final bgColor = isPositive
        ? const Color(0xFF25D366).withOpacity(0.15)
        : Colors.red.withOpacity(0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value pair used in company info and similar screens.
class SettingsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 480;

        final labelWidget = Text(
          label,
          textAlign: TextAlign.start,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s13,
            0.20,
            ColorManager.textColor.withOpacity(0.75),
          ),
        );

        final valueWidget = SelectableText(
          value,
          textAlign: TextAlign.start,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.22,
            ColorManager.textColor.withOpacity(0.9),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: isStacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        labelWidget,
                        const SizedBox(height: 6),
                        valueWidget,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth * 0.34,
                          child: labelWidget,
                        ),
                        Expanded(child: valueWidget),
                      ],
                    ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade200,
              ),
          ],
        );
      },
    );
  }
}

/// A list of [SettingsInfoRow] inside a card.
class SettingsInfoList extends StatelessWidget {
  final List<MapEntry<String, String>> entries;

  const SettingsInfoList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return SettingsContentCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < entries.length; i++)
            SettingsInfoRow(
              label: entries[i].key,
              value: entries[i].value,
              showDivider: i < entries.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable table wrapper for narrow screens.
class SettingsResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const SettingsResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsContentCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= minWidth) {
              return table;
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: table,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Filter fields that wrap on small screens.
class SettingsFilterWrap extends StatelessWidget {
  final List<Widget> children;
  final List<Widget>? actions;

  const SettingsFilterWrap({
    super.key,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < kSettingsPhoneBreakpoint;

    return SettingsContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: children
                .map(
                  (child) => SizedBox(
                    width: isCompact ? double.infinity : 160,
                    child: child,
                  ),
                )
                .toList(),
          ),
          if (actions != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Action buttons that stack vertically on phones.
class SettingsActionRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const SettingsActionRow({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < kSettingsPhoneBreakpoint;

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ],
    );
  }
}
