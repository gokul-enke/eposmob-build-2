import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../models/restaurant/menu_item_model.dart';
import '../../models/restaurant/table_model.dart';
import '../../providers/restaurant/table_provider.dart';
import '../../providers/restaurant/menu_provider.dart';
import '../../providers/restaurant/order_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../screens/restaurant/widgets/modifier_selection_modal.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantStatePage();
}

class _RestaurantStatePage extends State<RestaurantPage> {
  String? _activeTableId;
  String? _activeCategoryId;

  @override
  void initState() {
    super.initState();
    // Preload data
    Future.microtask(() {
      context.read<TableProvider>().loadTables();
      context.read<MenuProvider>().loadMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    // Better responsive breakpoints
    final isLargeScreen = screenWidth >= 1200;
    final isSmallScreen = screenWidth < 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern light background
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isSmallScreen 
            ? _buildMobileLayout(screenSize) 
            : _buildDesktopLayout(screenSize, isLargeScreen),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Size screenSize, bool isLargeScreen) {
    // More responsive width calculations
    final screenWidth = screenSize.width;
    
    // Calculate flexible widths based on screen size
    double tablesPanelFlex;
    double orderPanelFlex;
    double menuPanelFlex;
    
    if (screenWidth >= 1400) {
      // Large screens: more space for menu
      tablesPanelFlex = 2.5;
      menuPanelFlex = 5.0;
      orderPanelFlex = 3.0;
    } else if (screenWidth >= 1200) {
      // Medium-large screens: balanced
      tablesPanelFlex = 2.5;
      menuPanelFlex = 4.5;
      orderPanelFlex = 3.0;
    } else if (screenWidth >= 1000) {
      // Medium screens: compact tables
      tablesPanelFlex = 2.0;
      menuPanelFlex = 4.0;
      orderPanelFlex = 2.5;
    } else {
      // Small desktop screens: very compact
      tablesPanelFlex = 1.8;
      menuPanelFlex = 3.5;
      orderPanelFlex = 2.2;
    }
    
    return Row(
      children: [
        // Tables panel - flexible width
        Expanded(
          flex: tablesPanelFlex.round(),
          child: _TablesPanel(
            activeTableId: _activeTableId,
            onSelect: (id) {
              setState(() {
                _activeTableId = id;
              });
            },
            screenSize: screenSize,
          ),
        ),
        // Menu panel - flexible width (gets most space)
        Expanded(
          flex: menuPanelFlex.round(),
          child: _MenuPanel(
            onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
            activeCategoryId: _activeCategoryId,
            onItemAdd: _handleItemAdd,
            screenSize: screenSize,
          ),
        ),
        // Order panel - flexible width
        Expanded(
          flex: orderPanelFlex.round(),
          child: _OrderPanel(
            tableId: _activeTableId,
            onSubmitSuccess: _handleOrderSubmitSuccess,
            screenSize: screenSize,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size screenSize) {
    return Column(
      children: [
        // Top section with tables and order summary
        Container(
          height: screenSize.height * 0.35, // 35% of screen height
          child: Row(
            children: [
              // Tables panel - takes 60% of width
              Expanded(
                flex: 3,
                child: _TablesPanel(
                  activeTableId: _activeTableId,
                  onSelect: (id) {
                    setState(() {
                      _activeTableId = id;
                    });
                  },
                  isCompact: true,
                  screenSize: screenSize,
                ),
              ),
              // Order panel - takes 40% of width
              Expanded(
                flex: 2,
                child: _OrderPanel(
                  tableId: _activeTableId,
                  onSubmitSuccess: _handleOrderSubmitSuccess,
                  isCompact: true,
                  screenSize: screenSize,
                ),
              ),
            ],
          ),
        ),
        // Menu panel takes remaining space
        Expanded(
          child: _MenuPanel(
            onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
            activeCategoryId: _activeCategoryId,
            onItemAdd: _handleItemAdd,
            isCompact: true,
            screenSize: screenSize,
          ),
        ),
      ],
    );
  }

  void _handleItemAdd(MenuItemModel item, int quantity, Map<String, List<ModifierOption>> selectedModifiers, String? notes) {
    if (_activeTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a table first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    context.read<OrderProvider>().addItem(
      _activeTableId!,
      item,
      quantity: quantity,
      selectedModifiers: selectedModifiers,
      notes: notes,
    );
  }

  void _handleOrderSubmitSuccess(String orderId) {
    if (_activeTableId != null) {
      context.read<TableProvider>().setCurrentOrder(_activeTableId!, orderId);
    }
  }
}

class _TablesPanel extends StatelessWidget {
  final String? activeTableId;
  final ValueChanged<String> onSelect;
  final bool isCompact;
  final Size screenSize;

  const _TablesPanel({
    required this.activeTableId, 
    required this.onSelect,
    this.isCompact = false,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.tables.isEmpty) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
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
                padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: const Color(0xFF2563EB),
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tables',
                      style: buildCustomStyle(
                        FontWeightManager.bold, 
                        isCompact ? FontSize.s16 : FontSize.s18, 
                        0.30, 
                        const Color(0xFF1E293B)
                      ),
                    ),
                    const Spacer(),
                    if (provider.tables.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.tables.length}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold, 
                            FontSize.s12, 
                            0.21, 
                            const Color(0xFF059669)
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Tables list/grid
              Expanded(
                child: _buildTablesView(provider.tables),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTablesView(List<TableModel> tables) {
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
              'No tables available',
              style: buildCustomStyle(
                FontWeightManager.medium, 
                FontSize.s14, 
                0.21, 
                ColorManager.textColor.withOpacity(0.7)
              ),
            ),
          ],
        ),
      );
    }

    // Determine layout based on screen size and compact mode
    if (isCompact) {
      return _buildCompactTablesList(tables);
    } else {
      return _buildTableGrid(tables);
    }
  }

  Widget _buildCompactTablesList(List<TableModel> tables) {
    return ListView.builder(
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
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : [],
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
                              const Color(0xFF1E293B)
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getStatusText(table.status),
                            style: buildCustomStyle(
                              FontWeightManager.medium, 
                              FontSize.s11, 
                              0.21, 
                              _tableColor(table.status)
                            ),
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
                        boxShadow: table.status == TableStatus.occupied ? [
                          BoxShadow(
                            color: _tableColor(table.status).withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ] : [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableGrid(List<TableModel> tables) {
    // Calculate responsive grid columns
    int crossAxisCount;
    double childAspectRatio;
    
    if (screenSize.width >= 1200) {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    } else if (screenSize.width >= 900) {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }

    return GridView.builder(
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
                color: isActive 
                  ? const Color(0xFF2563EB).withOpacity(0.08) 
                  : _getTableBackgroundColor(table.status),
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
                      style: buildCustomStyle(
                        FontWeightManager.bold, 
                        FontSize.s12, 
                        0.21, 
                        const Color(0xFF1E293B)
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Status indicator - minimal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              FontSize.s6, 
                              0.14, 
                              _tableColor(table.status)
                            ),
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

  Color _getTableTextColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return ColorManager.textColor;
      case TableStatus.occupied:
        return Colors.red.shade700;
      case TableStatus.reserved:
        return Colors.purple.shade700;
      case TableStatus.cleaning:
        return Colors.blue.shade700;
      case TableStatus.maintenance:
        return Colors.orange.shade700;
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return 'FREE';
      case TableStatus.occupied:
        return 'BUSY';
      case TableStatus.reserved:
        return 'RSVD';
      case TableStatus.cleaning:
        return 'CLEAN';
      case TableStatus.maintenance:
        return 'MAINT';
    }
  }

  Color _tableColor(TableStatus s) {
    switch (s) {
      case TableStatus.available:
        return const Color(0xFF059669); // Modern green
      case TableStatus.occupied:
        return const Color(0xFFD97706); // Modern amber
      case TableStatus.reserved:
        return const Color(0xFF7C3AED); // Modern purple
      case TableStatus.cleaning:
        return const Color(0xFF0EA5E9); // Modern blue
      case TableStatus.maintenance:
        return const Color(0xFFDC2626); // Modern red
    }
  }
}

class _MenuPanel extends StatelessWidget {
  final ValueChanged<String?> onCategoryChanged;
  final String? activeCategoryId;
  final Function(MenuItemModel item, int quantity, Map<String, List<ModifierOption>> selectedModifiers, String? notes) onItemAdd;
  final bool isCompact;
  final Size screenSize;

  const _MenuPanel({
    required this.onCategoryChanged,
    required this.activeCategoryId,
    required this.onItemAdd,
    this.isCompact = false,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuProvider>(
      builder: (context, menu, _) {
        if (menu.isLoading && menu.items.isEmpty) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final categories = menu.categories;
        final selectedCategoryId = activeCategoryId ?? (categories.isNotEmpty ? categories.first.id : null);
        final items = selectedCategoryId != null ? menu.itemsByCategory(selectedCategoryId) : <MenuItemModel>[];
        
        // Calculate responsive grid columns with better aspect ratios
        int crossAxisCount;
        double childAspectRatio;
        
        if (isCompact) {
          // Mobile/small tablet layout
          if (screenSize.width > 600) {
            crossAxisCount = 2;
            childAspectRatio = 1.0; // Reduced from 1.4
          } else {
            crossAxisCount = 1;
            childAspectRatio = 1.2; // Reduced from 1.8
          }
        } else {
          // Desktop/large tablet layout
          if (screenSize.width > 1400) {
            crossAxisCount = 4;
            childAspectRatio = 0.9; // Reduced from 1.1
          } else if (screenSize.width > 1000) {
            crossAxisCount = 3;
            childAspectRatio = 1.0; // Reduced from 1.2
          } else {
            crossAxisCount = 2;
            childAspectRatio = 1.1; // Reduced from 1.3
          }
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
              // Enhanced header
              Container(
                padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF059669).withOpacity(0.05),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: const Color(0xFF059669),
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menu',
                      style: buildCustomStyle(
                        FontWeightManager.bold, 
                        isCompact ? FontSize.s16 : FontSize.s18, 
                        0.30, 
                        const Color(0xFF1E293B)
                      ),
                    ),
                    const Spacer(),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length} items',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold, 
                            FontSize.s12, 
                            0.21, 
                            const Color(0xFF059669)
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Enhanced categories with modern styling
              if (categories.isNotEmpty)
                Container(
                  height: isCompact ? 56 : 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, idx) {
                      final c = categories[idx];
                      final active = c.id == selectedCategoryId;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onCategoryChanged(c.id),
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 16 : 20, 
                                vertical: isCompact ? 8 : 10
                              ),
                              decoration: BoxDecoration(
                                color: active 
                                  ? const Color(0xFF2563EB) 
                                  : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: active 
                                    ? const Color(0xFF2563EB) 
                                    : Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: active ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: Text(
                                  c.name,
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold, 
                                    isCompact ? FontSize.s12 : FontSize.s13, 
                                    0.21, 
                                    active ? Colors.white : const Color(0xFF64748B)
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: categories.length,
                  ),
                ),
              // Menu items
              Expanded(
                child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: ColorManager.textColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No items in this category',
                            style: buildCustomStyle(
                              FontWeightManager.medium, 
                              FontSize.s14, 
                              0.21, 
                              ColorManager.textColor.withOpacity(0.7)
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(isCompact ? 8 : 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: isCompact ? 8 : 12,
                        crossAxisSpacing: isCompact ? 8 : 12,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, idx) {
                        final item = items[idx];
                        return _buildMenuItem(item, isCompact, context);
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

Widget _buildMenuItem(MenuItemModel item, bool compact, BuildContext context) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: item.isAvailable
          ? () {
              if (item.modifierGroups.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => ModifierSelectionModal(
                    menuItem: item,
                    onModifiersSelected: (selectedModifiers, notes) {
                      onItemAdd(item, 1, selectedModifiers, notes);
                    },
                  ),
                );
              } else {
                onItemAdd(item, 1, {}, null);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: item.isAvailable ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8.0 : 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Shrink to fit content
              children: [
                // Header with name and price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          compact ? FontSize.s10 : FontSize.s12,
                          0.21,
                          item.isAvailable
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 4 : 6,
                        vertical: compact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          compact ? FontSize.s9 : FontSize.s11,
                          0.23,
                          item.isAvailable
                              ? const Color(0xFF059669)
                              : const Color(0xFF059669).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),
                // Description
                Text(
                  item.description,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    compact ? FontSize.s8 : FontSize.s10,
                    0.21,
                    const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                // Tags
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: compact ? 3 : 4,
                        runSpacing: 2,
                        children: [
                          if (item.isVegetarian)
                            _buildCompactTag('VEG', const Color(0xFF059669), compact),
                          if (!item.isVegetarian)
                            _buildCompactTag('NON-VEG', const Color(0xFFDC2626), compact),
                          if (!item.isAvailable)
                            _buildCompactTag('OUT', const Color(0xFF6B7280), compact),
                        ],
                      ),
                    ),
                    if (item.isAvailable)
                      Container(
                        padding: EdgeInsets.all(compact ? 2 : 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.add,
                          color: const Color(0xFF2563EB),
                          size: compact ? 12 : 14,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTag(String text, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6, 
        vertical: compact ? 1 : 2
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.medium, 
          compact ? FontSize.s6 : FontSize.s8, 
          0.14, 
          color
        ),
      ),
    );
  }

  Widget _buildModernTag(String text, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8, 
        vertical: compact ? 2 : 3
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.semiBold, 
              compact ? FontSize.s8 : FontSize.s9, 
              0.14, 
              color
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTag(String text, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 4, 
        vertical: compact ? 1 : 2
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: buildCustomStyle(
          FontWeightManager.semiBold, 
          compact ? FontSize.s6 : FontSize.s8, 
          0.14, 
          color
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  final String? tableId;
  final ValueChanged<String> onSubmitSuccess;
  final bool isCompact;
  final Size screenSize;

  const _OrderPanel({
    required this.tableId, 
    required this.onSubmitSuccess,
    this.isCompact = false,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    if (tableId == null) {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.table_restaurant,
                  size: isCompact ? 48 : 64,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select a table to start order',
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.semiBold, 
                  isCompact ? FontSize.s14 : FontSize.s16, 
                  0.21, 
                  const Color(0xFF64748B)
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose from the tables panel to begin taking orders',
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.regular, 
                  isCompact ? FontSize.s11 : FontSize.s12, 
                  0.21, 
                  const Color(0xFF94A3B8)
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Consumer<OrderProvider>(
      builder: (context, order, _) {
        final items = order.getOrderForTable(tableId!);
        final total = order.getOrderTotal(tableId!);
        
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
            children: [
              // Enhanced header
              Container(
                padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD97706).withOpacity(0.05),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        color: const Color(0xFFD97706),
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order',
                            style: buildCustomStyle(
                              FontWeightManager.bold, 
                              isCompact ? FontSize.s16 : FontSize.s18, 
                              0.30, 
                              const Color(0xFF1E293B)
                            ),
                          ),
                          Text(
                            'Table $tableId',
                            style: buildCustomStyle(
                              FontWeightManager.medium, 
                              isCompact ? FontSize.s12 : FontSize.s13, 
                              0.21, 
                              const Color(0xFF64748B)
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold, 
                          isCompact ? FontSize.s14 : FontSize.s16, 
                          0.23, 
                          const Color(0xFF059669)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Order items
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: isCompact ? 36 : 48,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in order',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold, 
                                isCompact ? FontSize.s14 : FontSize.s16, 
                                0.21, 
                                const Color(0xFF64748B)
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add items from the menu to get started',
                              style: buildCustomStyle(
                                FontWeightManager.regular, 
                                isCompact ? FontSize.s11 : FontSize.s12, 
                                0.21, 
                                const Color(0xFF94A3B8)
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(isCompact ? 12 : 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (_, idx) {
                          final it = items[idx];
                          return _buildOrderItem(it, idx, order, isCompact);
                        },
                      ),
              ),
              // Enhanced action buttons
              SafeArea(
                top: false,
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade100,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: items.isEmpty ? null : () => order.clearOrder(tableId!),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: isCompact ? 44 : 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFDC2626),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Clear',
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold, 
                                    isCompact ? FontSize.s13 : FontSize.s14, 
                                    0.21, 
                                    items.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFFDC2626)
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: items.isEmpty || order.isSubmitting
                                ? null
                                : () async {
                                    final id = await order.submitOrder(tableId!);
                                    if (id != null) {
                                      onSubmitSuccess(id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Order submitted: $id'),
                                          backgroundColor: const Color(0xFF059669),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    } else if (order.error != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed: ${order.error}'),
                                          backgroundColor: const Color(0xFFDC2626),
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: isCompact ? 44 : 48,
                              decoration: BoxDecoration(
                                color: items.isEmpty || order.isSubmitting 
                                  ? const Color(0xFF94A3B8) 
                                  : const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: items.isNotEmpty && !order.isSubmitting ? [
                                  BoxShadow(
                                    color: const Color(0xFF059669).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: order.isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: isCompact ? 16 : 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Send to Kitchen',
                                          style: buildCustomStyle(
                                            FontWeightManager.semiBold, 
                                            isCompact ? FontSize.s13 : FontSize.s14, 
                                            0.21, 
                                            Colors.white
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(dynamic orderItem, int index, OrderProvider order, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  orderItem.item.name,
                  style: buildCustomStyle(
                    FontWeightManager.bold, 
                    compact ? FontSize.s13 : FontSize.s15, 
                    0.21, 
                    const Color(0xFF1E293B)
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${orderItem.totalPrice.toStringAsFixed(0)}',
                  style: buildCustomStyle(
                    FontWeightManager.bold, 
                    compact ? FontSize.s12 : FontSize.s14, 
                    0.21, 
                    const Color(0xFF059669)
                  ),
                ),
              ),
            ],
          ),
          
          // Modifiers
          if (orderItem.selectedModifiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                orderItem.selectedModifiers.entries
                    .map((e) => '${e.key.toUpperCase()}: ${e.value.map((o) => o.name).join(', ')}')
                    .join(' | '),
                style: buildCustomStyle(
                  FontWeightManager.medium, 
                  compact ? FontSize.s10 : FontSize.s11, 
                  0.21, 
                  const Color(0xFF2563EB)
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          // Notes
          if (orderItem.notes != null && orderItem.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 14,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      orderItem.notes!,
                      style: buildCustomStyle(
                        FontWeightManager.medium, 
                        compact ? FontSize.s10 : FontSize.s11, 
                        0.21, 
                        const Color(0xFFDC2626)
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Quantity controls with modern styling
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (orderItem.quantity > 1) {
                            order.updateItem(tableId!, index, orderItem.copyWith(quantity: orderItem.quantity - 1));
                          } else {
                            order.removeItem(tableId!, index);
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.remove,
                            size: compact ? 16 : 18,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: compact ? 32 : 40,
                      alignment: Alignment.center,
                      child: Text(
                        orderItem.quantity.toString(),
                        style: buildCustomStyle(
                          FontWeightManager.bold, 
                          compact ? FontSize.s14 : FontSize.s16, 
                          0.21, 
                          const Color(0xFF1E293B)
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          order.updateItem(tableId!, index, orderItem.copyWith(quantity: orderItem.quantity + 1));
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            size: compact ? 16 : 18,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Remove button with modern styling
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => order.removeItem(tableId!, index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: compact ? 16 : 18,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}