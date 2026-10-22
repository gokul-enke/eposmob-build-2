import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// The catalog can contain thousands of products. DropdownMenu creates a
/// button for every entry on opening; this bounded native menu builds only
/// visible rows, while searching the complete directory. Styling stays shared.
class NonStockReportPicker extends StatefulWidget {
  const NonStockReportPicker(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged,
      required this.label,
      required this.allLabel,
      required this.icon,
      this.loading = false,
      this.enabled = true});

  /// Key → shown label; [value] and [onChanged] use the key.
  final Map<String, String> options;
  final String? value;
  final String label, allLabel;
  final IconData icon;

  /// The picked option's key, or null for All.
  final ValueChanged<String?> onChanged;

  /// The options are still loading: a spinner instead of the menu, so an
  /// empty list is never mistaken for "nothing to pick".
  final bool loading;

  /// False shows the value as a fixed, unchangeable filter.
  final bool enabled;

  @override
  State<NonStockReportPicker> createState() => _NonStockReportPickerState();
}

class _NonStockReportPickerState extends State<NonStockReportPicker> {
  static const _rowHeight = 48.0;
  final _menu = MenuController();
  final _scroll = ScrollController();
  late final _focus = FocusNode(onKeyEvent: _key);
  late final _text = TextEditingController(text: _selectedLabel);
  List<String> _matches = [];
  String _query = '';
  int? _highlight;
  bool _selecting = false;
  String get _all => widget.allLabel;
  // A picked key whose name has not arrived yet shows nothing, not All.
  String get _selectedLabel =>
      widget.value == null ? _all : widget.options[widget.value] ?? '';
  String _label(String id) => id.isEmpty ? _all : widget.options[id]!;

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void didUpdateWidget(covariant NonStockReportPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The picked option's name may arrive after it was selected.
    final changed = oldWidget.value != widget.value ||
        oldWidget.allLabel != widget.allLabel ||
        oldWidget.options[oldWidget.value] != widget.options[widget.value];
    if (changed) {
      _text.text = _selectedLabel;
      _query = '';
    }
    if (changed || !mapEquals(oldWidget.options, widget.options)) _filter();
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
    final all = _all.toLowerCase().contains(query);
    // Typed text targets an option: list "All" after the matches so Enter
    // without a highlight picks the first real match.
    _matches = [
      if (all && query.isEmpty) '',
      for (final entry in widget.options.entries)
        if (entry.value.toLowerCase().contains(query)) entry.key,
      if (all && query.isNotEmpty) '',
    ];
    _highlight = null;
  }

  void _open() {
    if (widget.loading || !widget.enabled) return;
    setState(() {
      _query = '';
      _selecting = false;
      _filter();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_menu.isOpen) _menu.open();
    _focus.requestFocus();
  }

  void _search(String text) {
    setState(() {
      _query = text;
      _filter();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    // Reopening an open MenuAnchor closes it first, which would fire onClose.
    if (!_menu.isOpen) _menu.open();
  }

  void _select(String id) {
    if (!mounted) return;
    _selecting = true;
    _text.text = _label(id);
    _menu.close();
    widget.onChanged(id.isEmpty ? null : id);
  }

  /// Closing without a selection discards typed search text, so the field
  /// always shows the filter that is actually applied.
  void _closed() {
    if (!mounted) return;
    _query = '';
    if (_selecting) {
      _selecting = false;
    } else if (_text.text != _selectedLabel) {
      _text.text = _selectedLabel;
    }
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
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
            controller: _menu,
            childFocusNode: _focus,
            onClose: _closed,
            crossAxisUnconstrained: false,
            style: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
              surfaceTintColor: const WidgetStatePropertyAll(AppColors.surface),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control))),
            ),
            menuChildren: [
              SizedBox(
                width: constraints.maxWidth,
                height: _menuHeight(context),
                child: _matches.isEmpty
                    ? Center(
                        child: Text('non_stock_report.no_data_found'.tr,
                            style: AppTextStyles.caption))
                    : Scrollbar(
                        controller: _scroll,
                        child: ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.zero,
                          itemExtent: _rowHeight,
                          itemCount: _matches.length,
                          itemBuilder: (context, index) => MenuItemButton(
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
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        )),
              )
            ],
            builder: (context, controller, _) => TextField(
              controller: _text,
              focusNode: _focus,
              style: AppTextStyles.input,
              readOnly: widget.loading,
              enabled: widget.enabled,
              onTap: _open,
              onChanged: _search,
              decoration: _decoration(controller),
            ),
          ));

  InputDecoration _decoration(MenuController controller) {
    final decoration = AppInputDecoration.filter(
        label: widget.label,
        // A picked key whose name has not arrived shows nothing, not All.
        hint: widget.value == null ? _all : null,
        icon: widget.icon,
        suffix: widget.loading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : !widget.enabled
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Icon(Icons.lock_outline,
                        size: 18, color: AppColors.muted))
                : ExcludeFocus(
                    child: IconButton(
                    tooltip: widget.label,
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () =>
                        controller.isOpen ? controller.close() : _open(),
                  )));
    // A fixed filter keeps the usual outline; the lock says it is fixed.
    return decoration.copyWith(disabledBorder: decoration.enabledBorder);
  }
}
