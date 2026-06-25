import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_grid.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/new_order_button.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_app_bar.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_search_bar.dart';
import 'package:pos_machine/features/billing/presentation/pages/add_product_mobile.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class MarketHomeWidget extends StatefulWidget {
  const MarketHomeWidget({
    super.key,
    required this.onNewOrder,
  });

  final VoidCallback onNewOrder;

  @override
  State<MarketHomeWidget> createState() => _MarketHomeWidgetState();
}

class _MarketHomeWidgetState extends State<MarketHomeWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All products';
  ProductViewMode _viewMode = ProductViewMode.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Consumer<LocalProductProvider>(
            builder: (context, provider, _) {
              final products = _visibleProducts(provider.sellableProducts);
              final categories = _categories(provider.sellableProducts);

              String layoutTitle = 'Grid Layout';
              if (_viewMode == ProductViewMode.list) {
                layoutTitle = 'List Layout';
              } else if (_viewMode == ProductViewMode.dense) {
                layoutTitle = 'Dense Layout';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: MobileSearchBar(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _query = value.trim());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      NewOrderButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddProductMobileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  _CategoryChips(
                    categories: categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (category) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        layoutTitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = ProductViewMode.grid),
                        child: _ViewModeIcon(
                          icon: Icons.grid_view,
                          selected: _viewMode == ProductViewMode.grid,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = ProductViewMode.list),
                        child: _ViewModeIcon(
                          icon: Icons.table_rows_outlined,
                          selected: _viewMode == ProductViewMode.list,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _viewMode = ProductViewMode.dense),
                        child: _ViewModeIcon(
                          icon: Icons.apps,
                          selected: _viewMode == ProductViewMode.dense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: MarketProductGrid(
                      products: products,
                      viewMode: _viewMode,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<GetProduct> _visibleProducts(List<GetProduct> products) {
    return products.where((product) {
      final name = product.productName?.toLowerCase() ?? '';
      final category = product.category?.name ?? '';
      final matchesSearch = _query.isEmpty || name.contains(_query.toLowerCase());
      final matchesCategory = _selectedCategory == 'All products' ||
          category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> _categories(List<GetProduct> products) {
    final names = <String>{};
    for (final product in products) {
      final name = product.category?.name?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return ['All products', ...names.take(8)];
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(category),
            onSelected: (_) => onSelected(category),
            selectedColor: ColorManager.kPrimaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? ColorManager.kPrimaryColor : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            labelStyle: TextStyle(
              fontFamily: 'Poppins',
              color: selected ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          );
        },
      ),
    );
  }
}

class _ViewModeIcon extends StatelessWidget {
  const _ViewModeIcon({
    required this.icon,
    required this.selected,
  });

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? ColorManager.kPrimaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : Colors.black54,
      ),
    );
  }
}
