import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/core/ui/form/app_input_decoration.dart';
import 'package:pos_machine/core/ui/tokens/app_colors.dart';
import 'package:pos_machine/core/ui/tokens/app_spacing.dart';
import 'package:pos_machine/core/ui/tokens/app_text_styles.dart';

/// Shared purchase-list adapter: the searchable menu uses the same decoration
/// and palette as FilterPanel, without a full-screen popup route.
class PurchaseListPicker extends StatefulWidget {
  const PurchaseListPicker(
      {super.key,
      required this.label,
      required this.icon,
      required this.value,
      required this.options,
      required this.search,
      required this.onChanged});
  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final TextEditingController search;
  final ValueChanged<String> onChanged;

  @override
  State<PurchaseListPicker> createState() => _PurchaseListPickerState();
}

class _PurchaseListPickerState extends State<PurchaseListPicker> {
  final _focus = FocusNode();
  final _menu = MenuController();
  bool _wasOpen = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_handleFocusChange);
  }

  void _restoreSelection() {
    final selected =
        widget.options.contains(widget.value) ? widget.value : 'All';
    final label = selected == 'All' ? 'purchase_order.hint_all'.tr : selected;
    if (widget.search.text != label) {
      widget.search.value = TextEditingValue(
          text: label,
          selection: TextSelection.collapsed(offset: label.length));
    }
  }

  void _handleFocusChange() {
    if (_focus.hasFocus) return;
    // Defer until any menu selection and parent rebuild have finished. Never
    // replace a newly selected value with the previous filter's label.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus) return;
      _menu.close();
      _restoreSelection();
    });
  }

  Widget _leadingIcon(BuildContext context) {
    // Depend on the native menu's open state so Escape, the arrow button and
    // outside clicks also restore the label when the text field keeps focus.
    final open = MenuController.maybeIsOpenOf(context) ?? false;
    if (_wasOpen && !open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_menu.isOpen) _restoreSelection();
      });
    }
    _wasOpen = open;
    return Icon(widget.icon, size: 18, color: AppColors.muted);
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final value = widget.value;
    final options = widget.options;
    final search = widget.search;
    final onChanged = widget.onChanged;
    final choices = options.toSet().toList();
    final decoration = AppInputDecoration.filter(
        label: label, hint: 'purchase_order.hint_all'.tr, icon: icon);
    return DropdownMenu<String>(
      controller: search,
      focusNode: _focus,
      menuController: _menu,
      initialSelection: choices.contains(value) ? value : 'All',
      label: Text(label),
      leadingIcon: Builder(builder: _leadingIcon),
      expandedInsets: EdgeInsets.zero,
      menuHeight: 280,
      enableFilter: true,
      requestFocusOnTap: true,
      hintText: 'purchase_order.hint_all'.tr,
      textStyle: AppTextStyles.input,
      menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control)))),
      inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          constraints: decoration.constraints,
          contentPadding: decoration.contentPadding,
          filled: decoration.filled,
          fillColor: decoration.fillColor,
          border: decoration.border,
          enabledBorder: decoration.enabledBorder,
          focusedBorder: decoration.focusedBorder,
          labelStyle: decoration.labelStyle,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintStyle: decoration.hintStyle),
      filterCallback: (entries, query) {
        final display = value == 'All' ? 'purchase_order.hint_all'.tr : value;
        if (query == display) return entries;
        return entries
            .where((e) => e.label.toLowerCase().contains(query.toLowerCase()))
            .toList();
      },
      dropdownMenuEntries: [
        for (final name in choices)
          DropdownMenuEntry(
              value: name,
              label: name == 'All' ? 'purchase_order.hint_all'.tr : name)
      ],
      onSelected: (name) {
        if (name != null) onChanged(name);
      },
    );
  }
}

/// Date-only calendar preserves the purchase endpoints' yyyy-MM-dd contract.
class PurchaseListDateField extends StatelessWidget {
  const PurchaseListDateField(
      {super.key,
      required this.label,
      required this.hint,
      required this.controller,
      required this.onChanged});
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      readOnly: true,
      style: AppTextStyles.input,
      decoration: AppInputDecoration.filter(
          label: label,
          hint: hint,
          icon: Icons.calendar_today_outlined,
          suffix: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'purchase_order.clear_filter'.tr,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => onChanged(''))),
      onTap: () async {
        final date = await showAutoDismissDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101));
        if (date != null && context.mounted) {
          onChanged(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
        }
      });
}
