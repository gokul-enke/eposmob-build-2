/// Read-only price for a prospective cart addition. Prices shown to the
/// cashier are per selected sale unit; [baseUnitPrice] is used internally.
class ProductPricePreview {
  const ProductPricePreview({
    required this.unitPrice,
    required this.standardUnitPrice,
    required this.baseUnitPrice,
    required this.baseQuantity,
    this.hasOffer = false,
    this.requiresSelection = false,
    this.offerAvailable = false,
  });

  final double unitPrice;
  final double standardUnitPrice;
  final double baseUnitPrice;
  final num baseQuantity;
  final bool hasOffer;
  final bool requiresSelection;
  final bool offerAvailable;

  double get total => baseUnitPrice * baseQuantity;
}
