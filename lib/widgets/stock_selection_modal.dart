// Add this class after the ProductSelectionModal class
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/features/billing/domain/non_stock_visibility.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

// Class to represent combined stocks with same pricing
class CombinedStock {
  final String? price;
  final String? mrp;
  final String? purchasePrice;
  final String? unit;
  final String? hsnCode;
  final String? wholesalePrice;
  final int? wholesaleMinUnit;
  final num totalQuantity;
  final List<Stock> originalStocks;

  CombinedStock({
    required this.price,
    required this.mrp,
    required this.purchasePrice,
    required this.unit,
    required this.hsnCode,
    required this.wholesalePrice,
    required this.wholesaleMinUnit,
    required this.totalQuantity,
    required this.originalStocks,
  });

  // Get the stock with earliest expiry date for other properties
  Stock get firstStock {
    if (originalStocks.length == 1) return originalStocks.first;

    // Sort by expiry date (earliest first), then by date (earliest first)
    List<Stock> sortedStocks = List.from(originalStocks);
    sortedStocks.sort((a, b) {
      // First priority: expiry date (earliest first)
      if (a.expiryDate != null && b.expiryDate != null) {
        try {
          DateTime dateA = DateTime.parse(a.expiryDate!);
          DateTime dateB = DateTime.parse(b.expiryDate!);
          int expiryComparison = dateA.compareTo(dateB);
          if (expiryComparison != 0) return expiryComparison;
        } catch (e) {
          // If parsing fails, fall through to next comparison
        }
      }

      // Second priority: stock date (earliest first)
      if (a.date != null && b.date != null) {
        try {
          DateTime dateA = DateTime.parse(a.date!);
          DateTime dateB = DateTime.parse(b.date!);
          return dateA.compareTo(dateB);
        } catch (e) {
          // If parsing fails, use ID as fallback
        }
      }

      // Fallback: use ID
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return sortedStocks.first;
  }
}

class StockSelectionModal extends StatefulWidget {
  final GetProduct product;
  final List<Stock> stockOptions;

  const StockSelectionModal({
    Key? key,
    required this.product,
    required this.stockOptions,
  }) : super(key: key);

  @override
  State<StockSelectionModal> createState() => _StockSelectionModalState();
}

/// Default stock grouping fields used when no active fields are provided.
/// Only price and unit are checked — stocks with the same selling price
/// and unit are grouped together regardless of other attribute differences.
const Set<String> kDefaultStockGroupingFields = {
  'price',
  'unit',
};

/// Builds a grouping key for a stock using only the specified [activeFields].
/// Fields not in [activeFields] are excluded from the key, so stocks that
/// differ only in excluded fields will be grouped together.
String buildStockGroupingKey(Stock stock, Set<String> activeFields) {
  final parts = <String>[];
  if (activeFields.contains('price')) parts.add('${stock.price}');
  if (activeFields.contains('mrp')) parts.add('${stock.mrp}');
  if (activeFields.contains('purchasePrice')) {
    parts.add('${stock.purchasePrice}');
  }
  if (activeFields.contains('unit')) parts.add('${stock.unit}');
  if (activeFields.contains('hsnCode')) parts.add('${stock.hsnCode}');
  if (activeFields.contains('taxRate')) parts.add('${stock.taxRate}');
  if (activeFields.contains('wholesalePrice')) {
    parts.add('${stock.wholesalePrice}');
  }
  if (activeFields.contains('wholesaleMinUnit')) {
    parts.add('${stock.wholesaleMinUnit}');
  }
  return parts.join('_');
}

/// Groups stocks by identical pricing attributes and sums their quantities.
///
/// [activeFields] controls which Stock attributes are used for grouping.
/// Only fields present in [activeFields] contribute to the grouping key.
/// When [activeFields] is null, all fields are used (backward-compatible).
///
/// Useful for deciding whether a stock-selection modal is needed (>1 group)
/// or the single group can be auto-selected.
List<CombinedStock> groupStocksByPricing(
  List<Stock> stocks, {
  Set<String>? activeFields,
}) {
  final fields = activeFields ?? kDefaultStockGroupingFields;
  final Map<String, List<Stock>> grouped = {};

  for (final stock in stocks) {
    final key = buildStockGroupingKey(stock, fields);
    grouped.putIfAbsent(key, () => []).add(stock);
  }

  return grouped.entries.map((entry) {
    final stockList = entry.value;
    final totalQuantity =
        stockList.fold<num>(0, (sum, s) => sum + (s.quantity ?? 0));
    return CombinedStock(
      price: stockList.first.price,
      mrp: stockList.first.mrp,
      purchasePrice: stockList.first.purchasePrice,
      unit: stockList.first.unit,
      hsnCode: stockList.first.hsnCode,
      wholesalePrice: stockList.first.wholesalePrice,
      wholesaleMinUnit: stockList.first.wholesaleMinUnit,
      totalQuantity: totalQuantity,
      originalStocks: stockList,
    );
  }).toList();
}

class _StockSelectionModalState extends State<StockSelectionModal> {
  Set<int> expandedItems = {};

  @override
  Widget build(BuildContext context) {
    // Get currency from app settings
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';

    // POS_HIDE_NONSTOCK_PRODUCT: drop empty stock rows before grouping so a
    // zero-quantity batch never appears as a selectable option.
    final hideNonStockProduct = NonStockVisibility.isEnabledIn(context);
    final stockOptions = hideNonStockProduct
        ? NonStockVisibility.visibleStocks(widget.stockOptions)
        : widget.stockOptions;

    // Group stocks by pricing information (using master data active fields)
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    List<CombinedStock> combinedStocks = groupStocksByPricing(
      stockOptions,
      activeFields: masterDataProvider.activeStockGroupingFields,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'stock.multiple_options_available'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s16,
                      0.21,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'stock.product_prefix'.tr + (widget.product.localizedName ?? ''),
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s16,
                0.21,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 12),
            // Stock list
            Expanded(
              child: MouseRegion(
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
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: combinedStocks.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final combinedStock = combinedStocks[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 8),
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  combinedStock.originalStocks.length > 1
                                      ? 'Combined Stock (${combinedStock.originalStocks.length} stocks)'
                                      : 'Stock ID: ${combinedStock.firstStock.id}',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s14,
                                    0.21,
                                    ColorManager.textColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'stock.price_prefix'.tr +
                                          '$currency ${combinedStock.price ?? "0.00"}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'stock.mrp_prefix'.tr +
                                          '$currency ${combinedStock.mrp ?? "0.00"}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'stock.available_quantity_prefix'.tr +
                                          combinedStock.totalQuantity.toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    // Show expiry date for single stock entries
                                    if (combinedStock.originalStocks.length ==
                                            1 &&
                                        combinedStock.firstStock.expiryDate !=
                                            null)
                                      Text(
                                        'stock.expiry_date_prefix'.tr +
                                            combinedStock.firstStock.expiryDate!,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.orange),
                                      ),
                                    if (combinedStock.originalStocks.length > 1)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () {
                                          setState(() {
                                            if (expandedItems.contains(index)) {
                                              expandedItems.remove(index);
                                            } else {
                                              expandedItems.add(index);
                                            }
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              'stock.from_entries'.trParams({
                                                'count': combinedStock
                                                    .originalStocks.length
                                                    .toString(),
                                              }),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              expandedItems.contains(index)
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              size: 16,
                                              color: ColorManager.kPrimaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorManager.kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontSize: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () {
                                    // Return both product and selected combined stock
                                    // For combined stocks, return the first stock but with updated quantity
                                    Stock selectedStock =
                                        combinedStock.firstStock.copyWith(
                                      quantity: combinedStock.totalQuantity,
                                      price: combinedStock.price,
                                      mrp: combinedStock.mrp,
                                      unit: combinedStock.unit,
                                      purchasePrice:
                                          combinedStock.purchasePrice,
                                      hsnCode: combinedStock.hsnCode,
                                      wholesalePrice:
                                          combinedStock.wholesalePrice,
                                      wholesaleMinUnit:
                                          combinedStock.wholesaleMinUnit,
                                    );

                                    Navigator.pop(context, {
                                      'product': widget.product,
                                      'stock': selectedStock,
                                      'originalStocks': combinedStock
                                          .originalStocks, // Include original stocks for reference
                                    });
                                  },
                                  child: Text('general.choose'.tr),
                                ),
                              ),
                              // Show expanded stock details inside the same card
                              if (combinedStock.originalStocks.length > 1 &&
                                  expandedItems.contains(index))
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        200, // Fixed max height for expanded section
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(7),
                                      bottomRight: Radius.circular(7),
                                    ),
                                    border: Border(
                                      top: BorderSide(
                                          color: Colors.grey[300]!, width: 1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Header section
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2_rounded,
                                            color: ColorManager.kPrimaryColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'stock.individual_details'.tr,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: ColorManager.kPrimaryColor,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ColorManager.kPrimaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'stock.items_count'.trParams({
                                                'count': combinedStock
                                                    .originalStocks.length
                                                    .toString(),
                                              }),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Stock items - wrapped in scrollable container
                                      Flexible(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: combinedStock
                                              .originalStocks.length,
                                          itemBuilder: (context, stockIndex) {
                                            final stock = combinedStock
                                                .originalStocks[stockIndex];
                                            return Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.grey[300]!),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.03),
                                                    spreadRadius: 1,
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  // Stock icon
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: stock.expiryDate !=
                                                              null
                                                          ? Colors.orange
                                                              .withOpacity(0.1)
                                                          : Colors.grey
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Icon(
                                                      Icons.inventory,
                                                      color: stock.expiryDate !=
                                                              null
                                                          ? Colors.orange
                                                          : Colors.grey,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Stock details
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              'stock.stock_id_prefix'.tr,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                            Text(
                                                              '${stock.id}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.inventory_2,
                                                              size: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                              'stock.quantity_prefix'.tr +
                                                                  stock.quantity
                                                                      .toString(),
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 16),
                                                            Icon(
                                                              stock.expiryDate !=
                                                                      null
                                                                  ? Icons
                                                                      .schedule
                                                                  : Icons
                                                                      .all_inclusive,
                                                              size: 12,
                                                              color:
                                                                  stock.expiryDate !=
                                                                          null
                                                                      ? Colors
                                                                          .orange
                                                                      : Colors
                                                                          .grey,
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                stock.expiryDate !=
                                                                        null
                                                                    ? stock
                                                                        .expiryDate!
                                                                    : 'No expiry',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  color: stock.expiryDate !=
                                                                          null
                                                                      ? Colors
                                                                          .orange
                                                                      : Colors
                                                                          .grey,
                                                                  fontWeight: stock
                                                                              .expiryDate !=
                                                                          null
                                                                      ? FontWeight
                                                                          .w500
                                                                      : FontWeight
                                                                          .normal,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Choose button
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          ColorManager
                                                              .kPrimaryColor,
                                                      foregroundColor:
                                                          Colors.white,
                                                      textStyle:
                                                          const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      minimumSize:
                                                          const Size(60, 28),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      // Return the specific individual stock
                                                      Navigator.pop(context, {
                                                        'product':
                                                            widget.product,
                                                        'stock': stock,
                                                        'originalStocks': [
                                                          stock
                                                        ], // Single stock in array
                                                      });
                                                    },
                                                    child: Text('general.choose'.tr),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Close Button
                CustomRoundButton(
                  title: 'general.cancel'.tr,
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 120,
                  textColor: Colors.blue,
                  borderColor: Colors.blue,
                  boxColor: Colors.white,
                  fct: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
