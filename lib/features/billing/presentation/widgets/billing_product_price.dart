import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/domain/product_price_preview.dart';
import 'package:pos_machine/features/offers/presentation/widgets/cart_offer_badge.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// One base unit for a listing, or the requested addition for an entry form.
/// This only previews the cart's rules; it never reserves stock.
ProductPricePreview previewBillingProductPrice(
  BuildContext context,
  GetProduct product, {
  num quantity = 1,
  int? saleUnitId,
  bool includeCartQuantity = false,
  bool listen = true,
}) {
  final local = Provider.of<LocalProductProvider?>(context, listen: listen);
  if (local == null) {
    final price = double.tryParse(product.price?.price?.toString() ?? '') ?? 0;
    return ProductPricePreview(
        unitPrice: price,
        standardUnitPrice: price,
        baseUnitPrice: price,
        baseQuantity: quantity);
  }
  final settings = Provider.of<AppSettingsProvider?>(context, listen: listen);
  final general =
      Provider.of<GeneralSettingsProvider?>(context, listen: listen);
  final store =
      Provider.of<StoreSessionProvider?>(context, listen: listen)?.activeStore;
  final master = Provider.of<MasterDataProvider?>(context, listen: listen);
  return local.previewProductPrice(
    product: product,
    quantity: quantity,
    saleUnitId: saleUnitId,
    includeCartQuantity: includeCartQuantity,
    variantsEnabled: settings?.appSettings?.productVariantEnabled ?? false,
    stockEnabled: general?.generalSettings?.stockEnabled,
    hideNonStockProduct: settings?.appSettings?.posHideNonStockProduct ?? false,
    activeStoreId: store?.storeId ?? local.offerRepository.catalog.storeId,
    activeStoreName: store?.storeName,
    groupingFields: master?.activeStockGroupingFields,
  );
}

String formatBillingPrice(double price, String currency, {int? decimals}) {
  // Keep the offer engine's third decimal when it is significant.
  final precision = decimals ??
      ((price - double.parse(price.toStringAsFixed(2))).abs() > 0.0001 ? 3 : 2);
  return '${currency.isEmpty ? '' : '$currency '}${price.toStringAsFixed(precision)}';
}

/// A live listing price shared by desktop suggestions and the mobile market.
class BillingProductPrice extends StatelessWidget {
  const BillingProductPrice({
    super.key,
    required this.product,
    this.currency = '',
    this.priceStyle,
    this.badgeFontSize = 10,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final GetProduct product;
  final String currency;
  final TextStyle? priceStyle;
  final double badgeFontSize;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => _ProductPriceContent(
        price: previewBillingProductPrice(context, product),
        currency: currency,
        priceStyle: priceStyle ??
            const TextStyle(
                fontFamily: 'Poppins',
                color: ColorManager.kPrimaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 14),
        badgeFontSize: badgeFontSize,
        crossAxisAlignment: crossAxisAlignment,
      );
}

/// Compact price overlay for sidebar and quick-access product cards.
class BillingProductPriceTag extends StatelessWidget {
  const BillingProductPriceTag({super.key, required this.product});

  final GetProduct product;

  @override
  Widget build(BuildContext context) {
    final price = previewBillingProductPrice(context, product);
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final hasDetails = price.hasOffer || price.offerAvailable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: hasDetails
            ? Colors.white
            : ColorManager.kPrimaryColor.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
      ),
      child: _ProductPriceContent(
        price: price,
        currency: currency,
        priceStyle: TextStyle(
            color: hasDetails ? ColorManager.kPrimaryColor : Colors.white,
            fontSize: 8),
        badgeFontSize: 7,
        crossAxisAlignment: CrossAxisAlignment.end,
      ),
    );
  }
}

class _ProductPriceContent extends StatelessWidget {
  const _ProductPriceContent({
    required this.price,
    required this.currency,
    required this.priceStyle,
    required this.badgeFontSize,
    required this.crossAxisAlignment,
  });

  final ProductPricePreview price;
  final String currency;
  final TextStyle priceStyle;
  final double badgeFontSize;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final alignment = crossAxisAlignment == CrossAxisAlignment.end
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(formatBillingPrice(price.unitPrice, currency),
              style: priceStyle),
        ),
        if (price.hasOffer)
          OfferPriceBadge(
              standardPrice: price.standardUnitPrice, fontSize: badgeFontSize),
        if (price.offerAvailable)
          Text('offers.available'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: badgeFontSize, color: Colors.green.shade800)),
      ],
    );
  }
}
