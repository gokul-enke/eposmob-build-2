import 'package:pos_machine/features/offers/domain/product_offer.dart';
import 'package:pos_machine/features/offers/domain/product_offer_catalog.dart';

/// 2026-10-06 12:00 UTC — inside every "active" fixture window.
final offerTestNow = DateTime.utc(2026, 10, 6, 12);

ProductOfferLine offerLine({
  required int productId,
  ProductOfferType type = ProductOfferType.percentage,
  double value = 10,
  int? stockId,
  int? lineId,
  int? categoryDistance,
}) {
  return ProductOfferLine(
    lineId: lineId,
    productId: productId,
    stockId: stockId,
    categoryDistance: categoryDistance,
    type: type,
    value: value,
  );
}

ProductOffer productOffer({
  int id = 9,
  int version = 1,
  String name = 'Test Offer',
  DateTime? validFrom,
  DateTime? validUntil,
  bool companyWide = false,
  int storeId = 1,
  required List<ProductOfferLine> lines,
}) {
  return ProductOffer(
    id: id,
    version: version,
    name: name,
    storeId: companyWide ? null : storeId,
    validFrom: validFrom ?? DateTime.utc(2026, 10, 1),
    validUntil: validUntil ?? DateTime.utc(2026, 11, 1),
    lines: lines,
  );
}

ProductOfferCatalog offerCatalog(
  List<ProductOffer> offers, {
  bool enabled = true,
}) {
  return ProductOfferCatalog(
    enabled: enabled,
    storeId: 1,
    offers: {for (final offer in offers) offer.id: offer},
  );
}
