import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';

/// Permission keys for dashboard widgets, as configured under
/// Admin panel > Roles > Dashboard Widgets.
class DashboardPermissions {
  DashboardPermissions._();

  /// Whole widget, e.g. `dashboard.widgets.latest_orders.access`.
  static String widget(String name) => 'dashboard.widgets.$name.access';

  /// Single card of a widget, e.g.
  /// `dashboard.widgets.products_stats.low_stock.access`.
  static String field(String widget, String field) =>
      'dashboard.widgets.$widget.$field.access';
}

/// Whether the current user's role grants [permission].
///
/// Returns false until the roles list has loaded, so restricted widgets are
/// never shown by mistake. Listens to [RoleProvider] by default so the
/// dashboard rebuilds once roles arrive.
bool canSeeDashboardItem(
  BuildContext context,
  String permission, {
  bool listen = true,
}) {
  final roleProvider = Provider.of<RoleProvider>(context, listen: listen);
  final roleName = roleProvider.currentUserRole;
  if (roleName == null) return false;
  return roleProvider.roles.any((role) =>
      role.originalName == roleName && role.permissions.contains(permission));
}
