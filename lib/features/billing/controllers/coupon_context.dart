import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

T? _optionalProvider<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

Future<void> loadCouponCategories(BuildContext context) async {
  await _optionalProvider<CategoryProvider>(context)
      ?.ensureCategories(CategoryListScope.all);
}

void prepareCouponContext(BuildContext context, LocalProductProvider cart) {
  final categories = _optionalProvider<CategoryProvider>(context);
  cart.setCouponContext(
    storeId:
        _optionalProvider<StoreSessionProvider>(context)?.activeStore?.storeId,
    categoryParents: {
      for (final category in [
        ...?categories?.allCategories,
        ...?categories?.sellableCategories,
      ])
        if (category.categoryId case final id?) id: category.parent?.id,
    },
  );
}

List<String> couponRuleDescriptions(BuildContext context, DiscountData coupon,
    LocalProductProvider cart, String currency) {
  String money(num amount) =>
      '$currency ${AmountHelper.formatAmount(amount.toDouble())}';
  String? productName;
  for (final product in cart.products) {
    if (product.productId == coupon.productId) {
      productName = product.productName;
    }
  }
  String? categoryName;
  for (final category
      in _optionalProvider<CategoryProvider>(context)?.allCategories ?? []) {
    if (category.categoryId == coupon.categoryId) {
      categoryName = category.categoryName;
    }
  }
  return [
    if (coupon.productId != null)
      'Applies to ${productName ?? 'the selected product'} only'
    else if (coupon.categoryId != null)
      'Applies to ${categoryName ?? 'the selected category'} and its subcategories',
    'Items with offers are excluded',
    if (coupon.discountCouponLimitAmount > 0)
      'Maximum discount: ${money(coupon.discountCouponLimitAmount)}',
    if ((coupon.discountCouponMinAmount ?? 0) > 0)
      'Minimum order: ${money(coupon.discountCouponMinAmount!)}',
    if ((coupon.discountCouponMaxAmount ?? 0) > 0)
      'Maximum order: ${money(coupon.discountCouponMaxAmount!)}',
    if (coupon.validFromDate.isNotEmpty) 'Valid from: ${coupon.validFromDate}',
    if (coupon.validToDate.isNotEmpty) 'Valid through: ${coupon.validToDate}',
    if (coupon.remainingUses != null)
      'Uses remaining: ${coupon.remainingUses}'
    else if (coupon.discountCouponLimitCount > 0)
      'Usage limit: ${coupon.discountCouponLimitCount}',
  ];
}

bool ensureCouponValidForCheckout(
    BuildContext context, LocalProductProvider cart) {
  if (cart.appliedCoupon == null) return true;
  prepareCouponContext(context, cart);
  final error = cart.discountValidationError;
  if (error == null) return true;
  showScaffoldError(
      context: context, message: '$error Reapply or remove the coupon.');
  return false;
}
