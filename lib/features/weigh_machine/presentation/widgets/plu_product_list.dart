import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'weigh_ui.dart';

enum PluProductView { all, selected, weighted }

class PluViewCounts {
  const PluViewCounts({
    required this.all,
    required this.selected,
    required this.weighted,
  });

  final int all;
  final int selected;
  final int weighted;

  int of(PluProductView view) => switch (view) {
        PluProductView.all => all,
        PluProductView.selected => selected,
        PluProductView.weighted => weighted,
      };
}

class PluProductFilters extends StatelessWidget {
  const PluProductFilters({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.categories,
    required this.category,
    required this.onCategoryChanged,
    required this.view,
    required this.counts,
    required this.onViewChanged,
    required this.onReset,
  });

  final TextEditingController search;
  final VoidCallback onSearchChanged;
  final List<String> categories;
  final String? category;
  final ValueChanged<String?> onCategoryChanged;
  final PluProductView view;
  final PluViewCounts counts;
  final ValueChanged<PluProductView> onViewChanged;

  /// Null when search, category and view are already at their defaults.
  final VoidCallback? onReset;

  static String _viewLabel(PluProductView view) => switch (view) {
        PluProductView.all => 'All',
        PluProductView.selected => 'Selected',
        PluProductView.weighted => 'Weighted',
      };

  @override
  Widget build(BuildContext context) {
    final searchField = _SearchBox(
      controller: search,
      onChanged: onSearchChanged,
    );

    // No value means all categories; the × clears back to it.
    final categoryField = KeyedSubtree(
      key: const ValueKey('plu_category'),
      child: CustomDropDownWithSearch<String>(
        hintText: 'All categories',
        searchHintText: 'Search categories',
        value: category,
        items: categories,
        displayText: (name) => name,
        onChanged: onCategoryChanged,
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in PluProductView.values)
          ChoiceChip(
            key: ValueKey('plu_view_${option.name}'),
            label: Text(
                '${_viewLabel(option)} · ${WeighFormat.count(counts.of(option))}'),
            selected: view == option,
            showCheckmark: false,
            onSelected: (_) => onViewChanged(option),
            labelStyle: TextStyle(
              color: view == option
                  ? ColorManager.kPrimaryColor
                  : WeighUiColors.body,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Colors.white,
            selectedColor: WeighUiColors.softBlue,
            side: BorderSide(
              color: view == option
                  ? ColorManager.kPrimaryColor.withValues(alpha: 0.4)
                  : WeighUiColors.border,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 560;
      final reset = _ResetButton(
        label: stacked ? 'Reset filters' : 'Reset',
        onPressed: onReset,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stacked) ...[
            searchField,
            const SizedBox(height: 10),
            categoryField,
          ] else
            Row(children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: categoryField),
              const SizedBox(width: 12),
              IntrinsicWidth(child: reset),
            ]),
          const SizedBox(height: 12),
          chips,
          if (stacked) ...[
            const SizedBox(height: 12),
            reset,
          ],
        ],
      );
    });
  }
}

/// Filter-row controls share the look of [CustomDropDownWithSearch]: a 48px
/// white box with a soft shadow and 7px corners, outlined in the primary
/// colour while focused.
const _filterHeight = 48.0;
const _filterRadius = 7.0;

BoxDecoration _filterBox({required bool focused}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_filterRadius),
      border: Border.all(
        color: focused ? ColorManager.kPrimaryColor : Colors.transparent,
        width: focused ? 1.2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: focused
              ? ColorManager.kPrimaryColor.withValues(alpha: 0.18)
              : ColorManager.boxShadowColor,
          blurRadius: focused ? 6 : 3,
          offset: const Offset(0, 1),
        ),
      ],
    );

final _filterTextStyle = buildCustomStyle(
  FontWeightManager.medium,
  FontSize.s13,
  0.27,
  ColorManager.textColor.withValues(alpha: .5),
);

final _filterHintStyle = buildCustomStyle(
  FontWeightManager.medium,
  FontSize.s11,
  0.27,
  ColorManager.textColor.withValues(alpha: .5),
);

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = ColorManager.textColor.withValues(alpha: .6);
    return ListenableBuilder(
      listenable: Listenable.merge([_focus, widget.controller]),
      builder: (context, _) => Container(
        height: _filterHeight,
        decoration: _filterBox(focused: _focus.hasFocus),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded, size: 18, color: iconColor),
            ),
            Expanded(
              child: TextField(
                key: const ValueKey('plu_search'),
                controller: widget.controller,
                focusNode: _focus,
                onChanged: (_) => widget.onChanged(),
                textInputAction: TextInputAction.search,
                cursorColor: ColorManager.kPrimaryColor,
                style: _filterTextStyle,
                // The outer box draws the focus outline. Clear every border
                // state, or the app theme's focusedBorder (main.dart) adds a
                // second ring inside it.
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintText: 'Search name or barcode',
                  hintStyle: _filterHintStyle,
                ),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                key: const ValueKey('plu_search_clear'),
                tooltip: 'Clear search',
                icon: Icon(Icons.close, size: 16, color: iconColor),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged();
                },
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? ColorManager.kPrimaryColor
        : ColorManager.textColor.withValues(alpha: .35);
    return Tooltip(
      message: 'Reset search, category and view',
      child: Container(
        height: _filterHeight,
        decoration: _filterBox(focused: false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('plu_reset_filters'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(_filterRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                // Centred when stretched full width on narrow layouts.
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restart_alt_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s12,
                      0.27,
                      color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop product table. Rows have a fixed height so thousands of products
/// scroll lazily without measuring each row.
class PluProductTable extends StatelessWidget {
  const PluProductTable({
    super.key,
    required this.products,
    required this.isSelected,
    required this.onToggle,
    required this.allShownState,
    required this.onToggleAllShown,
    required this.empty,
  });

  static const rowHeight = 56.0;

  final List<GetProduct> products;
  final bool Function(GetProduct) isSelected;
  final void Function(GetProduct, bool) onToggle;

  /// `true` all shown selected, `false` none, `null` some.
  final bool? allShownState;

  /// Null when nothing is shown.
  final VoidCallback? onToggleAllShown;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: WeighUiColors.canvas,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Tooltip(
                  message: allShownState == true
                      ? 'Deselect all shown'
                      : 'Select all shown',
                  child: Checkbox(
                    key: const ValueKey('plu_select_all_shown'),
                    tristate: true,
                    value: allShownState,
                    activeColor: ColorManager.kPrimaryColor,
                    onChanged: onToggleAllShown == null
                        ? null
                        : (_) => onToggleAllShown!(),
                  ),
                ),
              ),
              const _HeaderCell('PRODUCT', flex: 4),
              const _HeaderCell('SKU', flex: 2),
              const _HeaderCell('CATEGORY', flex: 2),
              const _HeaderCell('BARCODE', flex: 2),
              const _HeaderCell('UNIT', flex: 1),
              const _HeaderCell('PRICE', flex: 1, align: TextAlign.right),
            ],
          ),
        ),
        const Divider(height: 1, color: WeighUiColors.border),
        Expanded(
          child: products.isEmpty
              ? SingleChildScrollView(child: empty)
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.builder(
                    itemCount: products.length,
                    itemExtent: rowHeight,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _TableRow(
                        product: product,
                        selected: isSelected(product),
                        onToggle: onToggle,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.flex, this.align});

  final String text;
  final int flex;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
            color: WeighUiColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.35,
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.product,
    required this.selected,
    required this.onToggle,
  });

  final GetProduct product;
  final bool selected;
  final void Function(GetProduct, bool) onToggle;

  Widget _cell(String text,
      {required int flex, TextAlign? align, TextStyle? style}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style:
              style ?? const TextStyle(color: WeighUiColors.body, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Any product can be ticked (for Excel); the SKU only drives PLU.csv.
    final weighted = PluCsv.isWeighted(product);
    return Material(
      color: selected
          ? WeighUiColors.softBlue.withValues(alpha: 0.6)
          : Colors.white,
      child: InkWell(
        key: ValueKey('plu_product_${product.productId}'),
        onTap: () => onToggle(product, !selected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: WeighUiColors.subtleBorder),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Checkbox(
                  value: selected,
                  activeColor: ColorManager.kPrimaryColor,
                  onChanged: (value) => onToggle(product, value ?? false),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.productName ?? 'Unnamed product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WeighUiColors.heading,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (weighted) ...[
                        const SizedBox(width: 8),
                        const WeighBadge.weighted(),
                      ],
                    ],
                  ),
                ),
              ),
              _cell(
                weighted ? product.sku!.trim() : '—',
                flex: 2,
                style: TextStyle(
                  color: weighted ? WeighUiColors.body : WeighUiColors.muted,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              _cell(product.category?.name ?? 'Uncategorized', flex: 2),
              _cell(
                product.barcode?.isNotEmpty == true ? product.barcode! : '—',
                flex: 2,
                style: const TextStyle(
                  color: WeighUiColors.body,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              _cell(product.unit?.isNotEmpty == true ? product.unit! : '—',
                  flex: 1),
              _cell(
                WeighFormat.price(product.price?.price),
                flex: 1,
                align: TextAlign.right,
                style: const TextStyle(
                  color: WeighUiColors.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile/narrow product card.
class PluProductCard extends StatelessWidget {
  const PluProductCard({
    super.key,
    required this.product,
    required this.selected,
    required this.onToggle,
  });

  final GetProduct product;
  final bool selected;
  final void Function(GetProduct, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final weighted = PluCsv.isWeighted(product);
    final details = [
      if (weighted) 'SKU ${product.sku!.trim()}',
      product.category?.name ?? 'Uncategorized',
      if (product.barcode?.isNotEmpty == true) product.barcode!,
      if (product.unit?.isNotEmpty == true) product.unit!,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? WeighUiColors.softBlue : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? ColorManager.kPrimaryColor.withValues(alpha: 0.45)
                : WeighUiColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('plu_product_${product.productId}'),
          onTap: () => onToggle(product, !selected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  activeColor: ColorManager.kPrimaryColor,
                  onChanged: (value) => onToggle(product, value ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              product.productName ?? 'Unnamed product',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: WeighUiColors.heading,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (weighted) ...[
                            const SizedBox(width: 6),
                            const WeighBadge.weighted(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WeighUiColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  WeighFormat.price(product.price?.price),
                  style: const TextStyle(
                    color: WeighUiColors.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky footer on narrow layouts: what PLU.csv will hold and the Download
/// action stay reachable while the user scrolls a long catalog. Ticks (for
/// Excel) are shown separately because they do not affect PLU.csv.
class PluSelectionBar extends StatelessWidget {
  const PluSelectionBar({
    super.key,
    required this.productCount,
    required this.tickedCount,
    required this.onClear,
    required this.download,
  });

  /// Products with an SKU, i.e. what PLU.csv will contain.
  final int productCount;
  final int tickedCount;
  final VoidCallback? onClear;
  final Widget download;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: WeighUiColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${WeighFormat.products(productCount)} in PLU.csv',
                    style: const TextStyle(
                      color: WeighUiColors.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      key: const ValueKey('plu_clear_selection'),
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Untick ${WeighFormat.count(tickedCount)}',
                          style: const TextStyle(
                            color: ColorManager.kPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            download,
          ],
        ),
      ),
    );
  }
}
