import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/stock_report_query.dart';

/// The catalog can contain thousands of products. DropdownMenu creates a
/// button for every entry on opening; this bounded native menu builds only
/// visible rows, while searching the complete directory. Styling stays shared.
class StockReportProductPicker extends StatefulWidget {
  const StockReportProductPicker(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});
  final Map<String, StockReportOption> options;
  final String? value;
  final ValueChanged<StockReportOption?> onChanged;

  @override
  State<StockReportProductPicker> createState() =>
      _StockReportProductPickerState();
}

class _StockReportProductPickerState extends State<StockReportProductPicker> {
  static const _rowHeight = 48.0;
  final _menu = MenuController();
  final _scroll = ScrollController();
  late final _focus = FocusNode(onKeyEvent: _key);
  late final _text = TextEditingController(text: _selectedLabel);
  List<String> _matches = [];
  String _query = '';
  int? _highlight;
  String get _all => 'stock_report.all_products'.tr;
  String get _selectedLabel => widget.options[widget.value]?.label ?? _all;
  String _label(String id) => id.isEmpty ? _all : widget.options[id]!.label;

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void didUpdateWidget(covariant StockReportProductPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _text.text = _selectedLabel;
      _query = '';
    }
    _filter();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _query.toLowerCase();
    _matches = [
      if (_all.toLowerCase().contains(query)) '',
      for (final entry in widget.options.entries)
        if (entry.value.label.toLowerCase().contains(query)) entry.key,
    ];
    _highlight = null;
  }

  void _open() {
    setState(() {
      _query = '';
      _filter();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _menu.open();
    _focus.requestFocus();
  }

  void _search(String text) {
    setState(() {
      _query = text;
      _filter();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _menu.open();
  }

  void _select(String id) {
    if (!mounted) return;
    _text.text = _label(id);
    _menu.close();
    widget.onChanged(id.isEmpty ? null : widget.options[id]);
  }

  double _menuHeight(BuildContext context) {
    // Keep the scrolling viewport inside short windows and above the keyboard.
    final usable = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        AppSizes.control -
        AppSpacing.lg;
    final viewport = math.min(320.0, math.max(_rowHeight, usable / 2));
    return math.min(viewport, math.max(1, _matches.length) * _rowHeight);
  }

  void _scrollToHighlight() {
    if (!mounted ||
        !_menu.isOpen ||
        _highlight == null ||
        !_scroll.hasClients) {
      return;
    }
    final top = _highlight! * _rowHeight;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final offset = top < position.pixels
        ? top
        : top + _rowHeight > position.pixels + position.viewportDimension
            ? top + _rowHeight - position.viewportDimension
            : position.pixels;
    _scroll.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.tab) {
      if (!_menu.isOpen) return KeyEventResult.ignored;
      _menu.close();
      return key == LogicalKeyboardKey.tab
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (!_menu.isOpen) _open();
      if (_matches.isEmpty) return KeyEventResult.handled;
      final down = key == LogicalKeyboardKey.arrowDown;
      setState(() => _highlight = _highlight == null
          ? (down ? 0 : _matches.length - 1)
          : (_highlight! + (down ? 1 : -1)) % _matches.length);
      // A keyboard-opened menu has no scroll client until its first layout.
      // Use the current highlight, and ignore callbacks after close/disposal.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
      return KeyEventResult.handled;
    }
    if (_menu.isOpen &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      if (_matches.isNotEmpty) _select(_matches[_highlight ?? 0]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FieldLabel(label: 'stock_report.product'.tr),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
              builder: (context, constraints) => MenuAnchor(
                    controller: _menu,
                    childFocusNode: _focus,
                    crossAxisUnconstrained: false,
                    style: MenuStyle(
                      backgroundColor:
                          const WidgetStatePropertyAll(AppColors.surface),
                      surfaceTintColor:
                          const WidgetStatePropertyAll(AppColors.surface),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control))),
                    ),
                    menuChildren: [
                      SizedBox(
                        width: constraints.maxWidth,
                        height: _menuHeight(context),
                        child: _matches.isEmpty
                            ? Center(
                                child: Text('stock_report.no_data_found'.tr,
                                    style: AppTextStyles.caption))
                            : Scrollbar(
                                controller: _scroll,
                                child: ListView.builder(
                                  controller: _scroll,
                                  padding: EdgeInsets.zero,
                                  itemExtent: _rowHeight,
                                  itemCount: _matches.length,
                                  itemBuilder: (context, index) =>
                                      MenuItemButton(
                                    requestFocusOnHover: false,
                                    style: ButtonStyle(
                                      textStyle: const WidgetStatePropertyAll(
                                          AppTextStyles.input),
                                      backgroundColor: WidgetStatePropertyAll(
                                          _highlight == index
                                              ? AppColors.softBlue
                                              : null),
                                    ),
                                    onPressed: () => _select(_matches[index]),
                                    child: Text(_label(_matches[index]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                )),
                      )
                    ],
                    builder: (context, controller, _) => TextField(
                      controller: _text,
                      focusNode: _focus,
                      style: AppTextStyles.input,
                      onTap: _open,
                      onChanged: _search,
                      decoration: AppInputDecoration.of(
                          hint: _all,
                          suffix: ExcludeFocus(
                              child: IconButton(
                            tooltip: 'stock_report.product'.tr,
                            icon: const Icon(Icons.arrow_drop_down),
                            onPressed: () => controller.isOpen
                                ? controller.close()
                                : _open(),
                          ))),
                    ),
                  )),
        ],
      );
}
