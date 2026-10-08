import 'package:flutter/material.dart';

import '../buttons/app_buttons.dart';
import '../display/app_icon_tile.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// A secondary page action (Filters, Export, Refresh...). Shown as a square
/// icon button on wide headers and as a menu entry on narrow ones, so every
/// action needs a [label].
@immutable
class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.badge = false,
    this.busy = false,
    this.key,
  });

  final IconData icon;

  /// Tooltip on wide headers, menu text on narrow ones.
  final String label;

  /// `null` disables the action.
  final VoidCallback? onPressed;

  /// Shown as "on" (e.g. filters visible).
  final bool active;

  /// Shows a dot (e.g. filters applied while hidden).
  final bool badge;

  /// Shows a spinner and disables the action.
  final bool busy;

  /// Key for the action's button (tests).
  final Key? key;
}

/// Icon + title + subtitle on the left; secondary [actions] and the primary
/// Add button on the right.
///
/// * Below [compactBreakpoint] the icon shrinks, the subtitle hides and Add
///   uses [addShortLabel].
/// * Below [collapseActionsBelow], two or more [actions] fold into a single
///   "more" menu so the row never overflows on phones.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onAdd,
    this.addLabel,
    this.addShortLabel,
    this.leading,
    this.primaryActions = const [],
  });

  static const compactBreakpoint = 560.0;
  static const collapseActionsBelow = 640.0;

  /// Key of the "more" button that holds the folded actions.
  static const moreActionsKey = ValueKey('page_header_more_actions');

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Secondary actions, left to right, placed before the Add button.
  final List<HeaderAction> actions;
  final VoidCallback? onAdd;
  final String? addLabel;
  final String? addShortLabel;

  /// Labeled workflow buttons built with the shared button components.
  /// Wide headers keep them beside secondary actions; narrow headers wrap
  /// them below the title so labels and disabled states remain visible.
  final List<Widget> primaryActions;

  /// Optional widget above the title row (e.g. a back link).
  final Widget? leading;

  Widget _titleBlock(bool compact) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconTile(
          icon: icon,
          size: compact ? 40 : 46,
          iconSize: compact ? 21 : 24,
          radius: 13,
          background: AppColors.softBlue,
          foreground: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? AppTextStyles.pageTitleCompact
                    : AppTextStyles.pageTitle,
              ),
              if (!compact && subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.pageSubtitle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(HeaderAction action) {
    return AppSquareIconButton(
      key: action.key,
      icon: action.icon,
      tooltip: action.label,
      onPressed: action.onPressed,
      foreground: AppColors.body,
      active: action.active,
      badge: action.badge,
      busy: action.busy,
    );
  }

  Widget _moreMenu(BuildContext context) {
    final anyBadge = actions.any((action) => action.badge);
    return PopupMenuButton<int>(
      key: moreActionsKey,
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      color: AppColors.surface,
      onSelected: (index) => actions[index].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null && !actions[i].busy,
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 20,
                  color: actions[i].active ? AppColors.primary : AppColors.body,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(actions[i].label)),
                if (actions[i].badge) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const AppBadgeDot(),
                ],
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: AppSquareIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: '',
          onPressed: () {},
          foreground: AppColors.body,
          badge: anyBadge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final collapse =
            actions.length > 1 && constraints.maxWidth < collapseActionsBelow;
        final wrapPrimary = constraints.maxWidth < collapseActionsBelow;

        final trailing = <Widget>[
          if (collapse)
            _moreMenu(context)
          else
            for (final action in actions) _actionButton(action),
          if (!wrapPrimary) ...primaryActions,
          if (onAdd != null)
            AppPrimaryButton(
              label: compact
                  ? (addShortLabel ?? addLabel ?? '')
                  : (addLabel ?? ''),
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
        ];

        final row = Row(
          children: [
            Expanded(child: _titleBlock(compact)),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              for (var i = 0; i < trailing.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                trailing[i],
              ],
            ],
          ],
        );

        if (leading == null && (!wrapPrimary || primaryActions.isEmpty)) {
          return row;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(height: 10)],
            row,
            if (wrapPrimary && primaryActions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: primaryActions),
            ],
          ],
        );
      },
    );
  }
}
