import 'package:get/get.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';

/// Translated display text for supplier data.
abstract final class SupplierLabels {
  static String balanceFilter(BalanceFilter filter) => switch (filter) {
        BalanceFilter.all => 'suppliers.all'.tr,
        BalanceFilter.positive => 'suppliers.positive'.tr,
        BalanceFilter.negative => 'suppliers.negative'.tr,
        BalanceFilter.zero => 'suppliers.zero'.tr,
      };

  static String countOnPage(int count) =>
      'supplier_list.count_on_page'.trParams({'count': '$count'});

  /// The value, or an em dash when blank.
  static String orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;
}
