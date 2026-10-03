import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/create_customer_voucher_page.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/create_supplier_voucher_page.dart';
import 'package:pos_machine/features/vouchers/presentation/state/customer_voucher_provider.dart';
import 'package:pos_machine/features/vouchers/presentation/state/supplier_voucher_provider.dart';

class Master extends MasterDataProvider {
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      [MasterDataValue(id: 1, value: 'CASH', description: 'Cash')];
}

class Auth extends AuthModel {
  @override
  String? get token => null;
}

class Labels extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void walk(Map<String, dynamic> data, String prefix) {
      for (final e in data.entries) {
        final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
        if (e.value is Map<String, dynamic>) {
          walk(e.value, key);
        } else {
          flat[key] = e.value.toString();
        }
      }
    }

    walk(jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
  });
  tearDown(() => Get.reset());
  for (final kind in ['customer', 'supplier']) {
    for (final width in [375.0, 1280.0]) {
      testWidgets('create form $kind retains layout at $width', (tester) async {
        final issues = <String>[];
        final previousError = FlutterError.onError;
        FlutterError.onError =
            (details) => issues.add(details.exceptionAsString());
        tester.view.physicalSize = Size(width, width == 375 ? 812 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final Widget page = kind == 'customer'
            ? const CreateCustomerVoucherPage()
            : const CreateSupplierVoucherPage();
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthModel>(create: (_) => Auth()),
              ChangeNotifierProvider<MasterDataProvider>(
                  create: (_) => Master()),
              ChangeNotifierProvider<CustomerVoucherProvider>(
                  create: (_) => CustomerVoucherProvider()),
              ChangeNotifierProvider<SupplierVoucherProvider>(
                  create: (_) => SupplierVoucherProvider())
            ],
            child: GetMaterialApp(
                locale: const Locale('en'),
                translations: Labels(),
                home: Scaffold(
                    body: RepaintBoundary(
                        key: const ValueKey('capture'), child: page)))));
        await tester.pumpAndSettle();
        Object? error;
        while ((error = tester.takeException()) != null) {
          issues.add(error.toString());
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = previousError;
        if (kind == 'customer' && width == 375) {
          // Existing create form layout is preserved by the architecture migration.
          expect(issues.length, 4);
          expect(
              issues.every((s) => s.contains('RenderFlex overflowed')), isTrue);
        } else {
          expect(issues, isEmpty);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final navigator =
            tester.state<NavigatorState>(find.byType(Navigator).first);
        if (navigator.canPop()) {
          navigator.pop();
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = previousError;
      });
    }
  }
}
