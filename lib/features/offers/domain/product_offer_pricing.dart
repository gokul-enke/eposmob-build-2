import 'product_offer.dart';
import 'product_offer_catalog.dart';

/// The offer applied to one cart line.
class ProductOfferPrice {
  const ProductOfferPrice({
    required this.price,
    required this.standardPrice,
    required this.offerId,
    required this.offerVersion,
    this.offerName = '',
  });

  /// Offer price for one base unit, rounded to 3 decimals.
  final double price;

  /// Price for one base unit before the offer.
  final double standardPrice;
  final int offerId;
  final int offerVersion;
  final String offerName;
}

/// Picks the offer price for one cart line, or null when the standard price
/// applies.
///
/// The feed carries every eligible rule, so the winner is chosen here, at the
/// time of sale (a product offer may have ended while a category offer is
/// still running). Among the rules that are valid now, for this store,
/// product and batch, exactly one wins (offers never stack):
///
/// 1. a product rule before a category rule;
/// 2. a store-specific offer before a company-wide one;
/// 3. product rules: a batch rule before a product-wide rule, then the highest
///    line id;
/// 4. category rules: the nearest category first (`category_distance`
///    ascending), then the highest offer id.
///
/// The winner's price is used even if it would not lower the price: the next
/// rule is never tried. Other rules:
/// - offers are off unless `POS_OFFERS` is enabled;
/// - only base-unit lines get an offer (no pack/case/box sale units);
/// - when the quantity qualifies for wholesale, the wholesale price wins;
/// - a batch rule applies only when the cart line draws from that one batch;
/// - minimum-price (margin) rules are not applied to offer prices.
///
/// [stockIds] are the batches the cart line draws from (empty when none).
/// [at] should come from `ProductOfferRepository.trustedNow`.
ProductOfferPrice? resolveProductOfferPrice({
  required ProductOfferCatalog catalog,
  required int? productId,
  required double standardUnitPrice,
  required DateTime at,
  Iterable<int> stockIds = const <int>[],
  bool isBaseUnit = true,
  bool usesWholesalePrice = false,
}) {
  if (!catalog.enabled || productId == null) return null;
  if (!isBaseUnit || usesWholesalePrice) return null;
  if (standardUnitPrice <= 0) return null;

  final lineStocks = stockIds.toSet();
  final singleStockId = lineStocks.length == 1 ? lineStocks.first : null;

  (ProductOffer, ProductOfferLine)? winner;
  List<int>? winnerRank;
  for (final entry in catalog.activeLinesFor(productId, at)) {
    final (offer, line) = entry;
    // A store-specific offer for another store never applies.
    if (offer.storeId != null && offer.storeId != catalog.storeId) continue;
    // A batch rule applies only to a cart line that uses exactly that batch.
    if (line.stockId != null && line.stockId != singleStockId) continue;

    final rank = _rank(offer, line);
    if (winnerRank == null || _compare(rank, winnerRank) < 0) {
      winner = entry;
      winnerRank = rank;
    }
  }
  if (winner == null) return null;

  final (offer, line) = winner;
  final price = line.priceFor(standardUnitPrice);
  if (price == null) return null;
  return ProductOfferPrice(
    price: price,
    standardPrice: standardUnitPrice,
    offerId: offer.id,
    offerVersion: offer.version,
    offerName: offer.name,
  );
}

/// Lower ranks win. Compared element by element.
List<int> _rank(ProductOffer offer, ProductOfferLine line) {
  final isCategory = line.isCategoryLine;
  return [
    isCategory ? 1 : 0,
    offer.storeId != null ? 0 : 1,
    line.stockId != null ? 0 : 1,
    isCategory ? line.categoryDistance! : -(line.lineId ?? 0),
    -offer.id,
  ];
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    final result = a[i].compareTo(b[i]);
    if (result != 0) return result;
  }
  return 0;
}
