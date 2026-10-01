import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../resources/color_manager.dart';
import '../app_colors.dart';
import '../app_surface.dart';
import 'list_page_scaffold.dart';

class FilterPanel extends StatefulWidget {
  const FilterPanel(
      {super.key,
      required this.fields,
      required this.title,
      required this.hint,
      required this.onReset});
  final List<Widget> fields;
  final String title, hint;
  final VoidCallback onReset;
  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  @override
  Widget build(BuildContext context) => AppSurface(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, size) {
        final columns = size.maxWidth < ListLayoutBreakpoints.oneFilter
            ? 1
            : size.maxWidth < ListLayoutBreakpoints.fourFilters
                ? 2
                : 4;
        final width =
            (size.maxWidth - AppSpacing.small * (columns - 1)) / columns;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: AppColors.body, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.title,
                      style: const TextStyle(
                          color: AppColors.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(widget.hint,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 11))
                ])),
            TextButton.icon(
                onPressed: widget.onReset,
                style: TextButton.styleFrom(
                    foregroundColor: ColorManager.kPrimaryColor),
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: Text('list.reset'.tr))
          ]),
          const SizedBox(height: AppSpacing.medium),
          Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: widget.fields
                  .map((field) => SizedBox(width: width, child: field))
                  .toList()),
        ]);
      }));
}

InputDecoration listFilterDecoration(String label, IconData icon) =>
    InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: const BorderSide(
                color: ColorManager.kPrimaryColor, width: 1.5)));

class TextFilterField extends StatefulWidget {
  const TextFilterField(
      {super.key,
      required this.controller,
      required this.label,
      required this.icon,
      required this.onSearch,
      this.keyboardType = TextInputType.text});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onSearch;
  final TextInputType keyboardType;
  @override
  State<TextFilterField> createState() => TextFilterFieldState();
}

class TextFilterFieldState extends State<TextFilterField> {
  Timer? _debounce;

  void cancelPendingSearch() => _debounce?.cancel();
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: AppColors.heading, fontSize: 13),
      decoration: listFilterDecoration(widget.label, widget.icon),
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), widget.onSearch);
      },
      onSubmitted: (_) {
        _debounce?.cancel();
        widget.onSearch();
      });
}
