import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class ProductAutocomplete extends StatefulWidget {
  final Size size;
  final Function(GetProduct) onSelected;
  final List<GetProduct> productList;
  final GlobalKey autocompleteProductKey;
  final bool autofocus;

  const ProductAutocomplete({
    Key? key,
    required this.size,
    required this.onSelected,
    required this.productList,
    required this.autocompleteProductKey,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<ProductAutocomplete> createState() => _ProductAutocompleteState();
}

class _ProductAutocompleteState extends State<ProductAutocomplete> {
  final ValueNotifier<int?> _hoveredIndex = ValueNotifier<int?>(null);

  @override
  Widget build(BuildContext context) {
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          Autocomplete<GetProduct>(
            key: widget.autocompleteProductKey,
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return [];
              }
              debugPrint(textEditingValue.text);

              await productProvider.listAllProducts(
                  filterName: textEditingValue.text);

              return productProvider.productList!;
            },
            displayStringForOption: (GetProduct product) =>
                product.productName ?? '',
            onSelected: (GetProduct selectedProduct) {
              widget.onSelected(selectedProduct);
              debugPrint('Selected Product: ${selectedProduct.productName}');
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              return buildColumnWidgetForTextFields(
                controller: textEditingController,
                autofocus: widget.autofocus,
                focusNode: focusNode,
                onchanged: (query) {},
                size: widget.size,
                hintText: 'Search Product',
              );
            },
            optionsViewBuilder: (BuildContext context,
                AutocompleteOnSelected<GetProduct> onSelected,
                Iterable<GetProduct> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: BuildBoxShadowContainer(
                  circleRadius: 12,
                  width: widget.size.width / 3,
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final GetProduct option = options.elementAt(index);
                      return ValueListenableBuilder<int?>(
                        valueListenable: _hoveredIndex,
                        builder: (context, hoveredIndex, child) {
                          bool isHovered = hoveredIndex == index;
                          return MouseRegion(
                            onEnter: (_) => _hoveredIndex.value = index,
                            onExit: (_) => _hoveredIndex.value = null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? Colors.blue.shade50
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                title: Text(
                                  option.productName ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s12,
                                    0.16,
                                    isHovered
                                        ? Colors.blue.shade800
                                        : Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                trailing: Text(
                                  '${option.price?.price ?? ''} ${option.currency ?? ''}',
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s12,
                                    0.16,
                                    isHovered
                                        ? Colors.blue.shade900
                                        : Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                onTap: () {
                                  onSelected(option);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hoveredIndex.dispose();
    super.dispose();
  }
}
