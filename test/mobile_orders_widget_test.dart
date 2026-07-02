import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/order_card.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class _FakeAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

SavedOrder _sampleOrder({
  required String id,
  double total = 42.5,
}) {
  return SavedOrder(
    id: id,
    orderNumber: 'ORD-$id',
    items: const [],
    createdAt: '2026-07-01T10:30:00Z',
    total: total,
  );
}

Widget _wrap(Widget child) {
  return GetMaterialApp(
    home: ChangeNotifierProvider<AppSettingsProvider>(
      create: (_) => _FakeAppSettingsProvider(),
      child: Scaffold(body: child),
    ),
  );
}

BoxDecoration? _cardDecoration(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.border != null) {
      return decoration;
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderCard desktop parity', () {
    testWidgets('highlights selected order with primary border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderCard(
            order: _sampleOrder(id: '1'),
            isSelected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      final decoration = _cardDecoration(tester);
      expect(decoration, isNotNull);
      final border = decoration!.border! as Border;
      expect(border.top.color, ColorManager.kPrimaryColor);
      expect(border.top.width, 2);
    });

    testWidgets('shows order number and total', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OrderCard(
            order: _sampleOrder(id: '2', total: 99.99),
            isSelected: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ORD-2'), findsOneWidget);
      expect(find.textContaining('99.99'), findsOneWidget);
      expect(find.textContaining('0'), findsWidgets);
    });
  });
}
