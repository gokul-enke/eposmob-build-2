import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/role_provider.dart';

class _PermissionRoleProvider extends RoleProvider {
  _PermissionRoleProvider(this.permissions, {this.role});

  final Set<String> permissions;
  final String? role;

  @override
  String? get currentUserRole => role;

  @override
  bool currentUserHasPermissionSync(String permission) {
    return permissions.contains(permission);
  }
}

void main() {
  test('app menu permissions grant the order reports', () {
    final sales = _PermissionRoleProvider({'menu.reports.sales_report.access'});
    expect(sales.currentUserCanAccessSalesReportSync(), isTrue);
    expect(sales.currentUserCanAccessDiscountSaleReportSync(), isFalse);

    final discount =
        _PermissionRoleProvider({'menu.reports.discount_sales.access'});
    expect(discount.currentUserCanAccessDiscountSaleReportSync(), isTrue);
    expect(discount.currentUserCanAccessSalesReportSync(), isFalse);
  });

  test('web page permissions alone do not show them', () {
    final provider = _PermissionRoleProvider(
        {'page_SalesReport', 'page_DiscountSaleReport'});
    expect(provider.currentUserCanAccessSalesReportSync(), isFalse);
    expect(provider.currentUserCanAccessDiscountSaleReportSync(), isFalse);
  });

  test('company admins need the App Permission too', () {
    final admin = _PermissionRoleProvider({}, role: 'company_admin');
    expect(admin.currentUserCanAccessSalesReportSync(), isFalse);
    expect(admin.currentUserCanAccessDiscountSaleReportSync(), isFalse);
    final ticked = _PermissionRoleProvider({'menu.reports.sales_report.access'},
        role: 'company_admin');
    expect(ticked.currentUserCanAccessSalesReportSync(), isTrue);
    expect(ticked.currentUserCanAccessDiscountSaleReportSync(), isFalse);
  });

  test('unrelated permissions do not show them', () {
    final other = _PermissionRoleProvider({'menu.reports.product_sales.access'},
        role: 'sales_executive');
    expect(other.currentUserCanAccessSalesReportSync(), isFalse);
    expect(other.currentUserCanAccessDiscountSaleReportSync(), isFalse);
  });
}
