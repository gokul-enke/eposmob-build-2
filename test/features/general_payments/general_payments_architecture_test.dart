import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/general_payments/presentation/navigation/general_payment_navigation.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/presentation/pages/general_payment_create_page.dart';
import 'package:pos_machine/features/general_payments/presentation/pages/general_payment_list_page.dart';
import 'package:pos_machine/providers/role_provider.dart';

class _Roles extends RoleProvider {
  _Roles(this.granted);
  final Set<String> granted;
  @override
  bool currentUserHasPermissionSync(String permission) =>
      granted.contains(permission);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('layers keep their dependency boundaries and file size budget', () {
    final files = Directory('lib/features/general_payments')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      final code = file.readAsStringSync();
      expect(code.split('\n').length, lessThanOrEqualTo(400), reason: path);
      final imports = RegExp(r"import '([^']+)'", multiLine: true)
          .allMatches(code)
          .map((m) => m[1]!)
          .toList();
      if (path.contains('/domain/')) {
        expect(
            imports.where((s) =>
                s.startsWith('package:') ||
                s.contains('data/') ||
                s.contains('presentation/')),
            isEmpty,
            reason: path);
      }
      if (path.contains('/data/')) {
        expect(
            imports.where((s) =>
                s.contains('presentation/') ||
                s.contains('providers/') ||
                s.contains('material.dart') ||
                s.contains('widgets.dart')),
            isEmpty,
            reason: path);
        expect(code.contains('SharedPreferences'), isFalse, reason: path);
        expect(code.contains('BuildContext'), isFalse, reason: path);
      }
      if (path.contains('/widgets/') || path.contains('/state/')) {
        expect(
            imports.where((s) =>
                s.contains('provider/provider.dart') ||
                s.contains('providers/') ||
                s.contains('http.dart')),
            isEmpty,
            reason: path);
        expect(code.contains('context.read'), isFalse, reason: path);
      }
      if (!path.contains('/navigation/')) {
        expect(code.contains('index.value ='), isFalse, reason: path);
      }
    }
  });

  test('the list is slot 104 and New Entry 105, opened through navigation', () {
    final sidebar = Get.put(SideBarController());
    expect(sidebar.screens[SideBarController.generalPaymentListScreenIndex],
        isA<GeneralPaymentListPage>());
    expect(sidebar.screens[SideBarController.generalPaymentCreateScreenIndex],
        isA<GeneralPaymentCreatePage>());
    sidebar.index.value = 0;
    GeneralPaymentNavigation.openList();
    expect(Get.find<SideBarController>(), same(sidebar));
    expect(sidebar.index.value, 104);
    GeneralPaymentNavigation.openCreate(type: GeneralPaymentType.loan);
    expect(sidebar.index.value, 105);
    expect(GeneralPaymentNavigation.takeCreateRequest()?.type,
        GeneralPaymentType.loan);
    expect(GeneralPaymentNavigation.takeCreateRequest(), isNull);
    expect(GeneralPaymentNavigation.sectionIndices, {104, 105});
  });

  test('the Accounts menu needs its own App Permission', () {
    expect(RoleProvider.generalPaymentsPermission,
        'menu.accounts.general_payments.access');
    expect(
        _Roles({'menu.accounts.general_payments.access'})
            .currentUserCanAccessGeneralPaymentsSync(),
        isTrue);
    expect(_Roles({}).currentUserCanAccessGeneralPaymentsSync(), isFalse);
    expect(
        _Roles({
          'menu.transactions.invoice.access',
          'menu.transactions.receipts.access',
        }).currentUserCanAccessGeneralPaymentsSync(),
        isFalse,
        reason: 'Transactions access no longer shows it');
  });
}
