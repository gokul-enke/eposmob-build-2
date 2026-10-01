import 'package:get/get.dart';

import 'package:pos_machine/core/filters/balance_filter.dart';

import '../../domain/customer_display.dart';

/// Translated display text for customer data.
abstract final class CustomerLabels {
  /// The customer's name, or the translated "Unnamed customer".
  static String name(String? value) =>
      CustomerNames.realName(value) ?? 'customers.unnamed'.tr;

  static String avatarSemantics(String? value) {
    final realName = CustomerNames.realName(value);
    return realName == null
        ? 'customers.unnamed'.tr
        : 'customers.avatar_label'.trParams({'name': realName});
  }

  static String type(CustomerType type) => switch (type) {
        CustomerType.b2b => 'customers.type_b2b'.tr,
        CustomerType.b2c => 'customers.type_b2c'.tr,
      };

  static String phoneOrPlaceholder(String? phone) =>
      phone?.isNotEmpty == true ? phone! : 'customers.not_provided'.tr;

  static String countOnPage(int count) => count == 1
      ? 'customers.count_on_page_one'.tr
      : 'customers.count_on_page'.trParams({'count': '$count'});

  static String balanceFilter(BalanceFilter filter) => switch (filter) {
        BalanceFilter.all => 'customers.all'.tr,
        BalanceFilter.positive => 'customers.positive'.tr,
        BalanceFilter.negative => 'customers.negative'.tr,
        BalanceFilter.zero => 'customers.zero'.tr,
      };
}
