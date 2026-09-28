import 'package:flutter/material.dart';

import '../resources/color_manager.dart';

/// Shared button for showing and hiding list filters.
class FilterToggleButton extends StatelessWidget {
  const FilterToggleButton({
    super.key,
    required this.showFilters,
    required this.hasActiveFilters,
    required this.onPressed,
    this.showTooltip,
    this.hideTooltip,
    this.activeFiltersListenable,
    this.activeFiltersBuilder,
  });

  final bool showFilters;
  final bool hasActiveFilters;
  final VoidCallback onPressed;
  final String? showTooltip;
  final String? hideTooltip;
  final Listenable? activeFiltersListenable;
  final bool Function()? activeFiltersBuilder;

  @override
  Widget build(BuildContext context) {
    if (activeFiltersListenable != null) {
      return AnimatedBuilder(
        animation: activeFiltersListenable!,
        builder: (context, _) => _buildButton(
          activeFiltersBuilder?.call() ?? hasActiveFilters,
        ),
      );
    }

    return _buildButton(hasActiveFilters);
  }

  Widget _buildButton(bool filtersAreActive) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            onPressed: onPressed,
            tooltip: showFilters ? hideTooltip : showTooltip,
          ),
          if (filtersAreActive)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
