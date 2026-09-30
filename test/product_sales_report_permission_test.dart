import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/role_provider.dart';

class _PermissionRoleProvider extends RoleProvider {
  _PermissionRoleProvider(this.permissions);

  final Set<String> permissions;

  @override
  bool currentUserHasPermissionSync(String permission) {
    return permissions.contains(permission);
  }
}

void main() {
  test('current Product Sales permission grants report access', () {
    final provider = _PermissionRoleProvider({
      'menu.reports.product_sales.access',
    });

    expect(provider.currentUserCanAccessProductSalesReportSync(), isTrue);
  });

  test('legacy Product Sales permission remains supported', () {
    final provider = _PermissionRoleProvider({'page_ProductSalesReport'});

    expect(provider.currentUserCanAccessProductSalesReportSync(), isTrue);
  });

  test('unrelated permissions do not grant Product Sales access', () {
    final provider = _PermissionRoleProvider({
      'menu.reports.supplier_transactions.access',
    });

    expect(provider.currentUserCanAccessProductSalesReportSync(), isFalse);
  });
}
