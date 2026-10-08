import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/quotation_print_service.dart';
import '../navigation/quotation_list_navigation.dart';

/// Existing row workflows, isolated from listing filters, fetching and export.
/// The quotation-to-cart mapping and print service calls are unchanged.
mixin QuotationListActions<T extends StatefulWidget> on State<T> {
  AuthModel get auth;
  QuotationsProvider get quotationProvider;
  LocalProductProvider get localProducts;
  QuotationListNavigation get quotationNavigation;
  bool isConvertingQuotation = false, isPrintingQuotation = false;
  Future<void> convertQuotationToOrder(Quotation quotation) async {
    final quotationId = quotation.id;
    if (quotationId == null) {
      AppToast.error(context, 'quotations.err_no_id'.tr);
      return;
    }
    if (isConvertingQuotation) return;

    setState(() => isConvertingQuotation = true);
    try {
      final authProvider = auth;
      final quotationsProvider = quotationProvider;
      final localProductProvider = localProducts;

      final details = await quotationsProvider.fetchQuotationDetails(
        accessToken: authProvider.token ?? '',
        quotationId: quotationId,
      );
      if (!mounted) return;

      if (details == null || (details.items ?? const []).isEmpty) {
        AppToast.error(
          context,
          'quotations.err_no_details'.tr,
        );
        return;
      }

      debugPrint(
        '🧾 [QuotationConvert] Loading quotation #$quotationId (${details.quotationNumber ?? quotation.quotationNumber}) into billing draft',
      );
      debugPrint(
        '🧾 [QuotationConvert] Customer id=${details.customer?.id}, inline=${details.customer?.isInline}, name="${details.customer?.name}", phone="${details.customer?.phone}"',
      );
      debugPrint(
        '🧾 [QuotationConvert] Delivery id=${details.deliveryMethodId}, method="${details.deliveryMethod}", charge=${details.deliveryCharge}, items=${details.items?.length ?? 0}',
      );

      final draftItems = <LocalCartItem>[];
      for (final quotationItem in details.items!) {
        final productId = quotationItem.productId;
        if (productId == null) continue;

        final product = localProductProvider.getProductById(productId) ??
            GetProduct(
              productId: productId,
              productName: quotationItem.productName,
              categoryId: quotationItem.categoryId,
              unit: quotationItem.unit,
              sellable: true,
            );
        final quantity = _parseQuotationNumber(quotationItem.quantity) ?? 0;
        if (quantity <= 0) continue;

        final saleUnitId = quotationItem.productSaleUnitId;
        final saleUnit = _findQuotationSaleUnit(product, saleUnitId);
        final saleUnitName = quotationItem.saleUnitName ?? saleUnit?.unitName;
        final saleUnitConversionRate = _parseQuotationNumber(
              quotationItem.saleUnitConversionRate,
            )?.toDouble() ??
            double.tryParse(saleUnit?.conversionRate ?? '');
        final effectiveSaleUnitRate = saleUnitId != null &&
                saleUnitConversionRate != null &&
                saleUnitConversionRate > 0
            ? saleUnitConversionRate
            : null;
        final hasSaleUnit = effectiveSaleUnitRate != null;
        final baseQuantity =
            hasSaleUnit ? quantity * effectiveSaleUnitRate : quantity;

        final selectedStock = _findQuotationStock(
                product, quotationItem.productStockId) ??
            localProductProvider.selectStockForQuantity(product, baseQuantity);
        final quotationUnitPrice = _parseQuotationNumber(
          quotationItem.unitPrice,
        );
        final price = quotationUnitPrice != null && hasSaleUnit
            ? quotationUnitPrice / effectiveSaleUnitRate
            : quotationUnitPrice ??
                (double.tryParse(product.price?.price?.toString() ?? '') ??
                    0.0);
        final productMrp = double.tryParse(product.mrp?.toString() ?? '');
        final mrp = productMrp != null && hasSaleUnit
            ? productMrp / effectiveSaleUnitRate
            : productMrp ?? price.toDouble();

        draftItems.add(
          LocalCartItem(
            product: product,
            price: price.toDouble(),
            mrp: mrp.toDouble(),
            taxRate: _parseQuotationNumber(quotationItem.taxRate)?.toDouble() ??
                product.totalTaxRate,
            taxAmount: _parseQuotationNumber(
              quotationItem.taxAmount,
            )?.toDouble(),
            quantity: baseQuantity,
            selectedStock: selectedStock,
            stockGroupIds: quotationItem.productStockId == null
                ? null
                : <int>[quotationItem.productStockId!],
            comment: quotationItem.comment,
            isManualPriceOverride: true,
            saleUnitId: saleUnitId,
            saleUnitName: saleUnitName,
            saleUnitConversionRate: effectiveSaleUnitRate,
          ),
        );
        debugPrint(
          '🧾 [QuotationConvert] Item product=$productId qty=${quotationItem.quantity} baseQty=$baseQuantity price=$price stock=${quotationItem.productStockId} saleUnit=$saleUnitId rate=$effectiveSaleUnitRate',
        );
      }

      if (draftItems.isEmpty) {
        AppToast.error(
          context,
          'quotations.err_no_items'.tr,
        );
        return;
      }

      final customer = details.customer;
      final quotationCustomerPhone =
          (customer?.phone?.trim().isNotEmpty ?? false)
              ? customer!.phone
              : quotation.customerPhone;
      final deliveryCharge = _parseQuotationNumber(
        details.deliveryCharge,
      )?.toDouble();
      localProductProvider.loadQuotationDraftForEditing(
        SavedOrder(
          id: 'quotation-$quotationId',
          orderNumber: details.quotationNumber ??
              quotation.quotationNumber ??
              'QT-$quotationId',
          items: draftItems,
          customerId: customer?.isInline == true ? null : customer?.id,
          customerName: customer?.name ?? quotation.customer,
          customerPhone: quotationCustomerPhone,
          createdAt: DateTime.now().toIso8601String(),
          total: _parseQuotationNumber(details.grandTotal)?.toDouble() ??
              _parseQuotationNumber(quotation.grandTotal)?.toDouble() ??
              0.0,
          deliveryMethod: details.deliveryMethod,
          deliveryMethodId: details.deliveryMethodId,
          deliveryCharge: deliveryCharge,
          comment: details.comment,
          address: _stringifyQuotationAddress(details.address),
          flatDiscount: _parseQuotationNumber(details.discount)?.toDouble(),
          customerType: customer?.isInline == true ? 'new' : 'existing',
          quotationId: quotationId,
          quotationNumber: details.quotationNumber ?? quotation.quotationNumber,
        ),
      );
      debugPrint(
        '🧾 [QuotationConvert] Draft loaded. quotationId=$quotationId, cartItems=${draftItems.length}, route=90',
      );

      quotationNavigation.openBilling();
      AppToast.success(context, 'quotations.loaded_billing'.tr);
    } catch (e) {
      debugPrint('Error converting quotation: $e');
      if (mounted) {
        AppToast.error(
          context,
          'quotations.err_load_billing'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => isConvertingQuotation = false);
    }
  }

  Stock? _findQuotationStock(GetProduct product, int? stockId) {
    if (stockId == null) return null;
    for (final stock in product.stock ?? const <Stock>[]) {
      if (stock.id == stockId) return stock;
    }
    return Stock(id: stockId, productId: product.productId);
  }

  SaleUnit? _findQuotationSaleUnit(GetProduct product, int? saleUnitId) {
    if (saleUnitId == null) return null;
    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      if (saleUnit.id == saleUnitId) return saleUnit;
    }
    return null;
  }

  String? _stringifyQuotationAddress(dynamic address) {
    if (address == null) return null;
    if (address is String) {
      final trimmed = address.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (address is Map) {
      final parts = <String>[];
      for (final key in [
        'address',
        'address_line',
        'address_line_1',
        'address_line_2',
        'street',
        'city',
        'state',
        'country',
        'postal_code',
        'pincode',
      ]) {
        final value = address[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          parts.add(value.toString().trim());
        }
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final fallback = address.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  num? _parseQuotationNumber(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  Future<void> printQuotation(Quotation quotation) async {
    final quotationId = quotation.id;
    if (quotationId == null) {
      AppToast.error(context, 'quotations.err_no_id'.tr);
      return;
    }
    if (isPrintingQuotation) return;

    setState(() => isPrintingQuotation = true);
    try {
      final authProvider = auth;
      final quotationsProvider = quotationProvider;

      final details = await quotationsProvider.fetchQuotationDetails(
        accessToken: authProvider.token ?? '',
        quotationId: quotationId,
      );
      if (!mounted) return;

      if (details == null) {
        AppToast.error(
          context,
          'quotations.err_no_details_print'.tr,
        );
        return;
      }

      await const QuotationPrintService().printQuotationDetails(
        context,
        details,
      );
    } catch (e) {
      debugPrint('Error printing quotation: $e');
      if (mounted) {
        AppToast.error(context, 'quotations.err_print'.tr);
      }
    } finally {
      if (mounted) setState(() => isPrintingQuotation = false);
    }
  }
}
