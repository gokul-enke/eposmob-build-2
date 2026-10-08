import 'package:flutter/material.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/day_closes/presentation/pages/day_close_list_page.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:provider/provider.dart';

import '../widgets/closing/day_close_modal.dart';
import '../widgets/closing/open_shift_modal.dart';

/// Operator Daily Sales Close list. Listing, filters and export live in
/// `features/day_closes`; this page wires the Sales modals and navigation.
class DailySalesCloseListPage extends StatelessWidget {
  const DailySalesCloseListPage({super.key, this.readSource});
  final Future<DayCloseListSource> Function()? readSource;

  @override
  Widget build(BuildContext context) => DayCloseListPage(
        readSource: readSource,
        onView: (context, row) {
          context.read<SalesProvider>()
            ..setSelectedDailySalesCloseData(row)
            ..setReturnIndex(SideBarController.dailySalesCloseListScreenIndex);
          SalesNavigation.openDailyCloseDetails();
        },
        onOpenShift: (context, onSuccess) => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => OpenShiftModal(onSuccess: onSuccess)),
        onDayClose: (context, onSuccess, draft) => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
                DayCloseModal(onSuccess: onSuccess, openDraft: draft)),
      );
}
