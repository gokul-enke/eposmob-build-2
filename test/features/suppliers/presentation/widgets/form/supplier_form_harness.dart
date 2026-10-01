/// Provider setup shared by the supplier form tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

/// One recorded create / update call.
class SupplierCall {
  SupplierCall(this.args);

  final Map<String, Object?> args;

  Object? operator [](String key) => args[key];
}

/// Records create / update calls instead of sending them.
class RecordingSupplierProvider extends SupplierProvider {
  RecordingSupplierProvider({
    this.createResponse = const {'status': 'success', 'message': 'Created'},
    this.updateResponse = const {'status': 'success', 'message': 'Updated'},
  });

  Map<String, dynamic> createResponse;
  Map<String, dynamic> updateResponse;
  Object? throwOnCall;

  final created = <SupplierCall>[];
  final updated = <SupplierCall>[];

  @override
  Future<Map<String, dynamic>> addSupplier({
    required String name,
    required String email,
    required String phone,
    required String accessToken,
    required String balance,
    required String paymentStatus,
    required String address,
    required String altPhone,
    List<int> productCategories = const [],
    String? taxNumber,
    List<SupplierKyc> kyc = const [],
  }) async {
    created.add(SupplierCall({
      'name': name,
      'email': email,
      'phone': phone,
      'accessToken': accessToken,
      'balance': balance,
      'paymentStatus': paymentStatus,
      'address': address,
      'altPhone': altPhone,
      'taxNumber': taxNumber,
      'kyc': {for (final entry in kyc) entry.key: entry.value},
    }));
    final error = throwOnCall;
    if (error != null) throw error;
    return createResponse;
  }

  @override
  Future<Map<String, dynamic>> updateSupplier({
    required int id,
    required String name,
    required String phone,
    required String accessToken,
    required double balance,
    String? email,
    String? address,
    String? altPhone,
    String? paymentStatus,
    String? taxNumber,
    List<SupplierKyc>? kyc,
  }) async {
    updated.add(SupplierCall({
      'id': id,
      'name': name,
      'phone': phone,
      'accessToken': accessToken,
      'balance': balance,
      'email': email,
      'address': address,
      'altPhone': altPhone,
      'paymentStatus': paymentStatus,
      'taxNumber': taxNumber,
      'kyc': {
        for (final entry in kyc ?? const <SupplierKyc>[]) entry.key: entry.value
      },
    }));
    final error = throwOnCall;
    if (error != null) throw error;
    return updateResponse;
  }
}

Supplier sampleSupplier({
  String paymentType = 'to_receive',
  double balance = -150.5,
}) =>
    Supplier(
      id: 7,
      name: 'Acme Traders',
      email: 'acme@example.com',
      phone: '9876543210',
      altPhone: '5551234567',
      taxNumber: 'TX-1',
      kyc: const [
        SupplierKyc(key: 'cr_number', value: 'CR-9'),
        SupplierKyc(key: 'LICENSE', value: 'L-1'),
      ],
      vatNumber: 'VAT-LEGACY',
      productCategories: '',
      address: 'Main Street 1',
      balance: balance,
      paymentType: paymentType,
      companyId: 1,
      currentBalance: 0,
      balanceStatus: '',
      userId: 1,
      transactions: const [],
      purchases: const [],
    );

/// Wraps [child] in the providers the supplier form reads.
Widget wrapSupplierForm(Widget child, {required SupplierProvider provider}) {
  final auth = AuthModel()..login('test-token', 1);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>.value(value: auth),
      ChangeNotifierProvider<SupplierProvider>.value(value: provider),
    ],
    child: GetMaterialApp(locale: const Locale('en'), home: child),
  );
}

/// Call inside a test. Collects "RenderFlex overflowed" errors; other errors
/// are reported.
List<FlutterErrorDetails> captureOverflowErrors() {
  final overflows = <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      overflows.add(details);
    } else {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
  return overflows;
}

/// Lets the toast's timer run out.
Future<void> settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Finder supplierField(String name) =>
    find.byKey(ValueKey('supplier-form-$name'));
