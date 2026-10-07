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

ProductPricePreview previewMarketProductPrice(
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

String formatMarketPrice(double price, String currency, {int? decimals}) {
  // Keep the offer engine's third decimal when it is significant.
  final precision = decimals ??
      ((price - double.parse(price.toStringAsFixed(2))).abs() > 0.0001 ? 3 : 2);
  return '${currency.isEmpty ? '' : '$currency '}${price.toStringAsFixed(precision)}';
}

class MarketProductPrice extends StatelessWidget {
  const MarketProductPrice(
      {super.key,
      required this.product,
      this.currency = '',
      this.fontSize = 14});

  final GetProduct product;
  final String currency;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final price = previewMarketProductPrice(context, product);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatMarketPrice(price.unitPrice, currency),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  color: ColorManager.kPrimaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize)),
        ),
        if (price.hasOffer)
          OfferPriceBadge(
              standardPrice: price.standardUnitPrice,
              fontSize: fontSize < 14 ? 8 : 10),
        if (price.offerAvailable)
          Text('offers.available'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: fontSize < 14 ? 8 : 10,
                  color: Colors.green.shade800)),
      ],
    );
  }
}
