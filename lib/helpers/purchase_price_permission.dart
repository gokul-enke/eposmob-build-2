import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';

const String purchaseOrdersAccessPermission = 'menu.purchase.orders.access';

bool canViewPurchasePrice(
  BuildContext context, {
  bool listen = false,
}) {
  return Provider.of<RoleProvider>(context, listen: listen)
      .currentUserHasPermissionSync(purchaseOrdersAccessPermission);
}
