import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/profile/supplier_edit_tab.dart';

import '../form/supplier_form_harness.dart';

void main() {
  tearDown(() => Get.delete<SideBarController>(force: true));

  testWidgets('renders at phone width without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overflows = captureOverflowErrors();
    await tester.pumpWidget(wrapSupplierForm(
      Scaffold(body: SupplierEditTab(supplier: sampleSupplier())),
      provider: RecordingSupplierProvider(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit Supplier Information'), findsOneWidget);
    expect(find.text('Acme Traders'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(overflows, isEmpty);
  });

  testWidgets('a successful save opens the suppliers list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sidebar = Get.put(SideBarController());
    final provider = RecordingSupplierProvider();
    await tester.pumpWidget(wrapSupplierForm(
      Scaffold(body: SupplierEditTab(supplier: sampleSupplier())),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.pump(SupplierEditTab.leaveDelay);

    expect(provider.updated, hasLength(1));
    expect(sidebar.index.value, SideBarController.suppliersScreenIndex);
    await settleToast(tester);
  });
}
