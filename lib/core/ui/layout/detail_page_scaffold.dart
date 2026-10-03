import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'app_surface.dart';

/// One navigation entry of a [DetailPageScaffold].
@immutable
class DetailTab<K> {
  const DetailTab({required this.id, required this.label, required this.icon});

  final K id;
  final String label;
  final IconData icon;
}

/// Width thresholds used by [DetailPageScaffold].
abstract final class DetailLayoutBreakpoints {
  /// Below this screen width: summary card + horizontal chip tabs on top.
  static const double mobileBelow = 700;

  /// Below this width the sidebar takes 30 % instead of 25 % of the page and
  /// the page padding tightens.
  static const double narrowBelow = 900;
}

/// The shared detail ("profile") page layout:
///
/// * wide: back link, title, then a sidebar (summary + vertical tab list)
///   next to the selected tab's content;
/// * mobile: back link, title, summary card, horizontal chip tabs, content.
class DetailPageScaffold<K> extends StatefulWidget {
  const DetailPageScaffold({
    super.key,
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.summary,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.content,
  });

  final String title;
  final String backLabel;
  final VoidCallback onBack;

  /// Summary block (avatar, name, id) shown at the top of the sidebar or in
  /// the mobile header card.
  final Widget summary;
  final List<DetailTab<K>> tabs;
  final K selectedTab;
  final ValueChanged<K> onTabSelected;

  /// Content of [selectedTab].
  final Widget content;

  @override
  State<DetailPageScaffold<K>> createState() => _DetailPageScaffoldState<K>();
}

class _DetailPageScaffoldState<K> extends State<DetailPageScaffold<K>> {
  final _chipScrollController = ScrollController();
  final Map<K, GlobalKey> _chipKeys = {};

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  void _select(K id) {
    widget.onTabSelected(id);
    final chipContext = _chipKeys[id]?.currentContext;
    if (chipContext != null) {
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _backLink() {
    return TextButton.icon(
      onPressed: widget.onBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(widget.backLabel),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: EdgeInsets.zero,
        textStyle: AppTextStyles.themed(
          context,
          AppTextStyles.button.copyWith(fontSize: 13),
        ),
      ),
    );
  }

  Widget _chip(DetailTab<K> tab) {
    final selected = tab.id == widget.selectedTab;
    return Padding(
      key: _chipKeys.putIfAbsent(tab.id, GlobalKey.new),
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          tab.icon,
          size: 14,
          color: selected ? AppColors.onPrimary : AppColors.muted,
        ),
        label: Text(tab.label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? AppColors.onPrimary : AppColors.body,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: const StadiumBorder(),
        onSelected: (_) => _select(tab.id),
      ),
    );
  }

  Widget _sidebarItem(DetailTab<K> tab) {
    final selected = tab.id == widget.selectedTab;
    final foreground = selected ? AppColors.onPrimary : AppColors.heading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: () => _select(tab.id),
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  tab.icon,
                  size: 20,
                  color: selected ? AppColors.onPrimary : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: selected ? AppColors.onPrimary : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backLink(),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.title, style: AppTextStyles.pageTitleCompact),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: widget.summary,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            controller: _chipScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final tab in widget.tabs) _chip(tab)]),
          ),
          const SizedBox(height: 10),
          Expanded(child: widget.content),
        ],
      ),
    );
  }

  Widget _wide(BoxConstraints constraints) {
    final narrow = constraints.maxWidth < DetailLayoutBreakpoints.narrowBelow;
    final padding = narrow ? 16.0 : 20.0;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backLink(),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.title, style: AppTextStyles.pageTitle),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: narrow
                      ? constraints.maxWidth * 0.3
                      : constraints.maxWidth / 4,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 24),
                    child: SingleChildScrollView(
                      child: AppSurface(
                        child: Column(
                          children: [
                            widget.summary,
                            const SizedBox(height: AppSpacing.xxl),
                            for (final tab in widget.tabs) _sidebarItem(tab),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: widget.content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < DetailLayoutBreakpoints.mobileBelow;
    return SafeArea(
      child: ColoredBox(
        color: AppColors.surface,
        child: isMobile
            ? _mobile()
            : LayoutBuilder(builder: (context, c) => _wide(c)),
      ),
    );
  }
}
