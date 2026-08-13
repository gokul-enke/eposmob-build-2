import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/models/restaurant/table_model.dart';
import '../../../../components/build_container_box.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';

// Using the existing TableModel and TableStatus from your models

class TablesPanel extends StatelessWidget {
  final String? activeTableId;
  final ValueChanged<String> onSelect;
  final bool isCompact;

  /// Phone layout: auto-fit compact table cards and a horizontal
  /// delivery-method chip rail at the top instead of the bottom block.
  final bool isMobile;
  final Size screenSize;
  final String? selectedDeliveryMethodId;
  final bool showDeliveryMethods;

  /// Store mode: hide the table grid entirely (walk-in/delivery only).
  final bool showTables;
  final void Function(String id, String name) onDeliveryMethodSelected;

  const TablesPanel({
    super.key,
    required this.activeTableId,
    required this.onSelect,
    this.isCompact = false,
    this.isMobile = false,
    required this.screenSize,
    this.selectedDeliveryMethodId,
    this.showDeliveryMethods = true,
    this.showTables = true,
    required this.onDeliveryMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, tableProvider, _) {
        final tables = tableProvider.tables;

        if (tableProvider.isLoading && tables.isEmpty) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (tableProvider.error != null && tables.isEmpty) {
          return BuildBoxShadowContainer(
            circleRadius: 10,
            margin: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'restaurant.failed_load_tables'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s16,
                      0.21,
                      Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tableProvider.error!,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.21,
                      ColorManager.textColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => tableProvider.refreshTables(),
                    child: Text('restaurant.retry'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced header with modern styling
              Container(
                padding: EdgeInsets.all(isCompact ? 10.0 : 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2563EB).withOpacity(0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade100,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        showTables
                            ? Icons.table_restaurant
                            : Icons.delivery_dining,
                        color: const Color(0xFF2563EB),
                        size: isCompact ? 14 : 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showTables
                          ? 'restaurant.tables_tab'.tr
                          : 'restaurant.walk_in_delivery'.tr,
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          isCompact ? FontSize.s14 : FontSize.s16,
                          0.30,
                          const Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    if (showTables)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${tables.length}',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s11, 0.21, const Color(0xFF059669)),
                        ),
                      ),
                  ],
                ),
              ),
              // On mobile the delivery methods sit above the grid as a
              // horizontal chip rail so the tables get the remaining space.
              if (isMobile && showDeliveryMethods)
                _buildDeliveryMethodsSection(context),
              // Tables list/grid
              Expanded(
                child: showTables
                    ? RefreshIndicator(
                        onRefresh: () => tableProvider.refreshTables(),
                        child: _buildTablesView(
                            tables, context), // Pass context here
                      )
                    : _buildWalkInOnlyPlaceholder(),
              ),
              if (!isMobile && showDeliveryMethods)
                _buildDeliveryMethodsSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalkInOnlyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_rounded,
            size: 44,
            color: ColorManager.textColor.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'restaurant.walk_in_delivery_billing'.tr,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                0.21, ColorManager.textColor.withOpacity(0.75)),
          ),
          const SizedBox(height: 4),
          Text(
            'restaurant.pick_delivery_method'.tr,
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
                0.21, ColorManager.textColor.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodsSection(BuildContext context) {
    return Consumer<DeliveryMethodsProvider>(
      builder: (context, deliveryMethodsProvider, _) {
        final methods = deliveryMethodsProvider.deliveryMethods;
        debugPrint(
            '🚚 [TablesPanel] Consumer rebuild — isLoading=${deliveryMethodsProvider.isLoading}, methods=${methods.length}, hasMethods=${deliveryMethodsProvider.hasMethods}');

        // Show a compact loading row while fetching
        if (deliveryMethodsProvider.isLoading && methods.isEmpty) {
          debugPrint(
              '🚚 [TablesPanel] Showing loading spinner (first-time fetch in progress)');
          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            padding: EdgeInsets.all(isCompact ? 10.0 : 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.delivery_dining,
                    color: const Color(0xFF1A56DB),
                    size: isCompact ? 12 : 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Walk-in / Delivery',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    isCompact ? FontSize.s12 : FontSize.s13,
                    0.21,
                    const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF1A56DB).withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          );
        }

        if (methods.isEmpty) {
          debugPrint(
              '🚚 [TablesPanel] No delivery methods available — hiding section');
          return const SizedBox.shrink();
        }

        debugPrint(
            '🚚 [TablesPanel] Rendering ${methods.length} delivery method chips (selected=$selectedDeliveryMethodId)');

        if (isMobile) {
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.delivery_dining,
                    color: const Color(0xFF1A56DB),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  if (selectedDeliveryMethodId != null) ...[
                    GestureDetector(
                      onTap: () => onDeliveryMethodSelected('', ''),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (final method in methods) ...[
                    _buildDeliveryChip(
                      method.id,
                      method.name,
                      horizontalPadding: 14,
                      verticalPadding: 8,
                      fontSize: FontSize.s12,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          padding: EdgeInsets.all(isCompact ? 10.0 : 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delivery_dining,
                      color: const Color(0xFF1A56DB),
                      size: isCompact ? 12 : 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Walk-in / Delivery',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      isCompact ? FontSize.s12 : FontSize.s13,
                      0.21,
                      const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  if (selectedDeliveryMethodId != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onDeliveryMethodSelected('', ''),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Delivery method chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: methods
                    .map((method) => _buildDeliveryChip(
                          method.id,
                          method.name,
                          horizontalPadding: isCompact ? 8 : 10,
                          verticalPadding: isCompact ? 5 : 6,
                          fontSize: isCompact ? FontSize.s10 : FontSize.s11,
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryChip(
    String id,
    String name, {
    required double horizontalPadding,
    required double verticalPadding,
    required double fontSize,
  }) {
    final isSelected = selectedDeliveryMethodId == id;
    return GestureDetector(
      onTap: () => onDeliveryMethodSelected(id, name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A56DB)
              : const Color(0xFF1A56DB).withOpacity(0.07),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A56DB)
                : const Color(0xFF1A56DB).withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A56DB).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          name,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            fontSize,
            0.21,
            isSelected ? Colors.white : const Color(0xFF1A56DB),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTablesView(List<TableModel> tables, BuildContext context) {
    if (tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 48,
              color: ColorManager.textColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'restaurant.no_tables_available'.tr,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                  0.21, ColorManager.textColor.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    // Determine layout based on screen size and compact mode
    if (isMobile) {
      return _buildMobileTableGrid(tables, context);
    } else if (isCompact) {
      return _buildCompactTablesList(tables, context); // Pass context here
    } else {
      return _buildTableGrid(tables, context); // Pass context here
    }
  }

  Widget _buildMobileTableGrid(List<TableModel> tables, BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 104,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final isActive = table.id == activeTableId;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(table.id),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _getTableBackgroundColor(table.status),
                border: isActive
                    ? Border.all(color: const Color(0xFF2563EB), width: 2.5)
                    : Border.all(color: Colors.grey.shade200, width: 1),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? const Color(0xFF2563EB).withOpacity(0.15)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: isActive ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _tableColor(table.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.table_restaurant,
                      color: _tableColor(table.status),
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      table.name,
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s13, 0.21, const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tableColor(table.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _tableColor(table.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(table.status),
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s9, 0.14, _tableColor(table.status)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactTablesList(
      List<TableModel> tables, BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final isActive = table.id == activeTableId;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(table.id),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2563EB).withOpacity(0.08)
                          : _getTableBackgroundColor(table.status),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF2563EB)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        // Table icon and name
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.table_restaurant,
                            color: _tableColor(table.status),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.name,
                                style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s14,
                                    0.21,
                                    const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getStatusText(table.status),
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s11,
                                    0.21,
                                    _tableColor(table.status)),
                              ),
                            ],
                          ),
                        ),
                        // Status indicator with pulse animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _tableColor(table.status),
                            shape: BoxShape.circle,
                            boxShadow: table.status == TableStatus.occupied
                                ? [
                                    BoxShadow(
                                      color: _tableColor(table.status)
                                          .withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableGrid(List<TableModel> tables, BuildContext context) {
    // Always 2 columns
    const int crossAxisCount = 2;
    const double childAspectRatio = 1;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final isActive = table.id == activeTableId;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(table.id),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _getTableBackgroundColor(table.status),
                    border: isActive
                        ? Border.all(color: const Color(0xFF2563EB), width: 3)
                        : Border.all(color: Colors.grey.shade200, width: 1),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? const Color(0xFF2563EB).withOpacity(0.15)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: isActive ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Table icon - even smaller
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.table_restaurant,
                            color: _tableColor(table.status),
                            size: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Table name - smaller font
                        Text(
                          table.name,
                          style: buildCustomStyle(FontWeightManager.bold,
                              FontSize.s12, 0.21, const Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Status indicator - minimal
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: _tableColor(table.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _getStatusText(table.status),
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s8,
                                    0.14,
                                    _tableColor(table.status)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getTableBackgroundColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Colors.white;
      case TableStatus.occupied:
        return const Color(0xFFFEF2F2); // Modern red tint
      case TableStatus.reserved:
        return const Color(0xFFFAF5FF); // Modern purple tint
      case TableStatus.cleaning:
        return const Color(0xFFF0F9FF); // Modern blue tint
      case TableStatus.maintenance:
        return const Color(0xFFFFF7ED); // Modern orange tint
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return 'restaurant.status_free'.tr;
      case TableStatus.occupied:
        return 'restaurant.status_busy'.tr;
      case TableStatus.reserved:
        return 'restaurant.status_rsvd'.tr;
      case TableStatus.cleaning:
        return 'restaurant.status_clean'.tr;
      case TableStatus.maintenance:
        return 'restaurant.status_maint'.tr;
    }
  }

  Color _tableColor(TableStatus s) {
    switch (s) {
      case TableStatus.available:
        return const Color(0xFF059669); // Modern green
      case TableStatus.occupied:
        return const Color(0xFFD97706); // Modern amber
      case TableStatus.reserved:
        return const Color(0xFF1A56DB); // Modern purple
      case TableStatus.cleaning:
        return const Color(0xFF0EA5E9); // Modern blue
      case TableStatus.maintenance:
        return const Color(0xFFDC2626); // Modern red
    }
  }
}
