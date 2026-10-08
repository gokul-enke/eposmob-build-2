import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/quotations_provider.dart';

class QuotationListNavigation {
  const QuotationListNavigation(this.sidebar, this.quotations);
  final SideBarController sidebar;
  final QuotationsProvider quotations;
  void openNew() => sidebar.index.value = 86;
  void openView(int? id) {
    quotations.setSelectedQuotationId(id);
    sidebar.index.value = 88;
  }

  void openBilling() => sidebar.index.value = 90;
}
