import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:provider/provider.dart';

class ProductDetailsDialog extends StatefulWidget {
  final GetProduct? product;
  final String? barcode; // barcode to fetch product details
  final double? unitPrice; // cart unit price (if any)
  final double? mrp; // cart mrp (if any)
  final num? quantity; // cart quantity (if any)
  final Stock? selectedStock; // selected stock (if any)
  final bool isCompact;
  final String currency;
  final VoidCallback? onAdd; // optional action button

  const ProductDetailsDialog({
    super.key,
    this.product,
    this.barcode,
    this.unitPrice,
    this.mrp,
    this.quantity,
    this.selectedStock,
    this.isCompact = false,
    this.currency = '',
    this.onAdd,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  GetProduct? selectedProduct;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      selectedProduct = widget.product;
    } else if (widget.barcode != null) {
      _fetchProductByBarcode(widget.barcode!);
    }
  }

  Future<void> _fetchProductByBarcode(String barcode) async {
    setState(() {
      isLoading = true;
    });

    try {
      final productProvider = Provider.of<LocalProductProvider>(context, listen: false);
      
      // Search for product by barcode in the products list
      GetProduct? product;
      try {
        product = productProvider.products.firstWhere(
          (p) => p.barcode != null && p.barcode!.toString().trim() == barcode.trim(),
        );
      } catch (e) {
        // Product not found
        product = null;
      }
      
      setState(() {
        selectedProduct = product;
        isLoading = false;
      });

      if (product == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product with barcode "$barcode" not found')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching product: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
              softWrap: true, // Enable text wrapping
              overflow: TextOverflow.visible, // Allow text to wrap instead of truncating
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s13,
              0.18,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product details...'),
            ],
          ),
        ),
      );
    }

    if (selectedProduct == null) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Product not found'),
              const SizedBox(height: 16),
              CustomRoundButton(
                title: "Close",
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: () => Navigator.pop(context),
                height: 45,
                width: 120,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
      );
    }

    final product = selectedProduct!;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9, // Increased from 0.8 to 0.9
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minWidth: 600, // Add minimum width to ensure adequate space
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Product Details in 3 columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Basic Info
                      Expanded(
                        child: Column(
                          children: [
                            _buildDetailRow(
                                'Product Name', product.productName ?? 'N/A'),
                            _buildDetailRow(
                                'Slug', product.productSlug ?? 'N/A'),
                            _buildDetailRow(
                                'Category', product.category?.name ?? 'N/A'),
                            _buildDetailRow(
                                'Barcode', product.barcode ?? 'N/A'),
                            _buildDetailRow('Unit', product.unit ?? 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Middle Column - Pricing Info
                      Expanded(
                        child: Column(
                          children: [
                            _buildDetailRow('Price',
                                product.price?.price?.toString() ?? 'N/A'),
                            _buildDetailRow(
                                'MRP', product.mrp?.toString() ?? 'N/A'),
                            _buildDetailRow(
                                'Purchase Price',
                                product.purchasePrice ??
                                    (product.stock != null &&
                                            product.stock!.isNotEmpty
                                        ? product.stock!.first.purchasePrice
                                        : null) ??
                                    'N/A'),
                            _buildDetailRow('Offer Price',
                                product.offerPrice?.toString() ?? 'N/A'),
                            _buildDetailRow(
                                'Currency', product.currency ?? 'N/A'),
                            _buildDetailRow(
                                'SKU', product.sku ?? 'Not Available'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Column - Additional Info
                      Expanded(
                        child: Column(
                          children: [
                            _buildDetailRow(
                                'Rating', product.rating ?? 'N/A'),
                            _buildDetailRow('Available Qty',
                                product.numberOfProductsAvailable ?? 'N/A'),
                            _buildDetailRow('Location',
                                product.productLocation?.toString() ?? 'N/A'),
                            if (product.weightInfo != null) ...[
                              _buildDetailRow(
                                  'Weight',
                                  product.weightInfo!.weight?.toString() ??
                                      'N/A'),
                              _buildDetailRow(
                                  'Is Weighted',
                                  product.weightInfo!.isWeighted == true
                                      ? 'Yes'
                                      : 'No'),
                            ] else ...[
                              _buildDetailRow('Weight', 'N/A'),
                              _buildDetailRow('Is Weighted', 'N/A'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description Section
                  if (product.description != null &&
                      product.description.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.20,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        product.description.toString(),
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s14,
                          0.20,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ],

                  // Product Properties Section
                  if (product.productProps != null &&
                      product.productProps!.isNotEmpty &&
                      product.productProps!.any((prop) => 
                        (prop.label?.isNotEmpty ?? false) || 
                        (prop.masterValue?.isNotEmpty ?? false))) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Product Properties',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.20,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.productProps!
                            .where((prop) => 
                              (prop.label?.isNotEmpty ?? false) || 
                              (prop.masterValue?.isNotEmpty ?? false))
                            .map((prop) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: ColorManager.kPrimaryColor
                                      .withOpacity(0.3)),
                            ),
                            child: Text(
                              '${prop.label ?? ''}: ${prop.masterValue ?? ''}',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.18,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Stock Information Section
                  const SizedBox(height: 16),
                  Text(
                    'Stock Information',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.20,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Show stock information in table format
                  if (product.stock != null && product.stock!.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            decoration: const BoxDecoration(
                              color: ColorManager.tableBGColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(0.6), // Sl No
                                1: FlexColumnWidth(1.2), // Quantity
                                2: FlexColumnWidth(1.2), // Price
                                3: FlexColumnWidth(1.2), // MRP
                                4: FlexColumnWidth(1.2), // Purchase Price
                                5: FlexColumnWidth(1.5), // Supplier
                                6: FlexColumnWidth(1.0), // SKU
                                7: FlexColumnWidth(1.2), // Date
                                8: FlexColumnWidth(1.2), // Expiry Date
                                9: FlexColumnWidth(1.0), // Rack
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildStockTableHeader('Sl No'),
                                    _buildStockTableHeader('Quantity'),
                                    _buildStockTableHeader('Price'),
                                    _buildStockTableHeader('MRP'),
                                    _buildStockTableHeader('Purchase Price'),
                                    _buildStockTableHeader('Supplier'),
                                    _buildStockTableHeader('SKU'),
                                    _buildStockTableHeader('Date'),
                                    _buildStockTableHeader('Expiry Date'),
                                    _buildStockTableHeader('Rack'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Table Body
                          ...product.stock!.asMap().entries.map((entry) {
                            int stockIndex = entry.key;
                            var stock = entry.value;
                            return Container(
                              decoration: BoxDecoration(
                                color: stockIndex % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.withOpacity(0.05),
                              ),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(0.6), // Sl No
                                  1: FlexColumnWidth(1.2), // Quantity
                                  2: FlexColumnWidth(1.2), // Price
                                  3: FlexColumnWidth(1.2), // MRP
                                  4: FlexColumnWidth(1.2), // Purchase Price
                                  5: FlexColumnWidth(1.5), // Supplier
                                  6: FlexColumnWidth(1.0), // SKU
                                  7: FlexColumnWidth(1.2), // Date
                                  8: FlexColumnWidth(1.2), // Expiry Date
                                  9: FlexColumnWidth(1.0), // Rack
                                },
                                border: null,
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  TableRow(
                                    children: [
                                      _buildStockTableCell(
                                          '${stockIndex + 1}'),
                                      _buildStockTableCell(
                                          stock.quantity?.toString() ??
                                              'N/A'),
                                      _buildStockTableCell(
                                          stock.price ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.mrp ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.purchasePrice ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.supplier ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.sku ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.date ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.expiryDate ?? 'N/A'),
                                      _buildStockTableCell(
                                          stock.rack ?? 'N/A'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          'No stock information available',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.20,
                            Colors.grey[600]!,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButton(
                  title: "Close",
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  borderColor: ColorManager.kPrimaryColor,
                  fct: () => Navigator.pop(context),
                  height: 45,
                  width: 120,
                  fontSize: FontSize.s12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
