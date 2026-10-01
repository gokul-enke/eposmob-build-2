import 'package:flutter/material.dart';

import '../buttons/app_buttons.dart';
import '../display/app_icon_tile.dart';
import '../layout/app_surface.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_text_styles.dart';
import 'filter_field.dart';

/// Search/filter block of a listing page.
///
/// Fields are laid out in 1, 2 or 4 equal columns depending on the width.
/// With [showHeader] the panel shows a title row with a Reset text button;
/// without it (inside the mobile collapsible tile) Reset becomes a
/// full-width button under the fields.
class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    required this.fields,
    required this.onSearch,
    this.onSubmit,
    required this.onReset,
    required this.resetLabel,
    this.embeddedResetLabel,
    this.title,
    this.hint,
    this.showHeader = true,
    this.useSurface = true,
  });

  static const singleColumnBelow = 540.0;
  static const twoColumnsBelow = 940.0;
  static const gap = 12.0;

  final List<FilterFieldDef> fields;

  /// Runs on every edit of a text field. Pages usually debounce this.
  final VoidCallback onSearch;

  /// Runs when a text field is submitted (Enter). Defaults to [onSearch].
  final VoidCallback? onSubmit;
  final VoidCallback onReset;
  final String resetLabel;

  /// Label of the full-width Reset button used without the header (mobile).
  /// Defaults to [resetLabel].
  final String? embeddedResetLabel;
  final String? title;
  final String? hint;
  final bool showHeader;
  final bool useSurface;

  static int columnsFor(double width) {
    if (width < singleColumnBelow) return 1;
    if (width < twoColumnsBelow) return 2;
    return 4;
  }

  /// Copy of this panel for the mobile collapsible tile.
  FilterPanel embedded() => FilterPanel(
        fields: fields,
        onSearch: onSearch,
        onSubmit: onSubmit,
        onReset: onReset,
        resetLabel: resetLabel,
        embeddedResetLabel: embeddedResetLabel,
        title: title,
        hint: hint,
        showHeader: false,
        useSurface: false,
      );

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const AppIconTile(icon: Icons.tune_rounded, iconSize: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(title!, style: AppTextStyles.sectionTitle),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!, style: AppTextStyles.sectionHint),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 17),
          label: Text(resetLabel),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTextStyles.themed(context, AppTextStyles.button),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = columnsFor(available);
        final fieldWidth = (available - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[_header(context), const SizedBox(height: 14)],
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: fieldWidth,
                    child: field.build(
                      context,
                      onTextChanged: onSearch,
                      onTextSubmitted: onSubmit ?? onSearch,
                    ),
                  ),
              ],
            ),
            if (!showHeader) ...[
              const SizedBox(height: 12),
              AppOutlinedButton(
                label: embeddedResetLabel ?? resetLabel,
                icon: Icons.restart_alt_rounded,
                iconSize: 18,
                height: 44,
                expand: true,
                onPressed: onReset,
              ),
            ],
          ],
        );
      },
    );

    if (!useSurface) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: content,
      );
    }
    return AppSurface(padding: const EdgeInsets.all(16), child: content);
  }
}
