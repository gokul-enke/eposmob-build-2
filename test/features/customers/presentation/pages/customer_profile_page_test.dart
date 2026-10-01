import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/pages/customer_profile_page.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_profile_tab.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_chat_tab.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_info_tab.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_loyalty_tab.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../widgets/profile/profile_test_helpers.dart';

void main() {
  Future<CustomerProvider> pump(
    WidgetTester tester, {
    required Size size,
    bool select = true,
  }) async {
    useSurfaceSize(tester, size);
    final customers = CustomerProvider();
    if (select) customers.selectCustomer(testCustomer());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => FakeAppSettingsProvider(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: CustomerProfilePage())),
      ),
    );
    await tester.pump();
    return customers;
  }

  CustomerProfileTab selectedTab(WidgetTester tester) => tester
      .widget<DetailPageScaffold<CustomerProfileTab>>(
        find.byType(DetailPageScaffold<CustomerProfileTab>),
      )
      .selectedTab;

  Future<void> tapTab(WidgetTester tester, String label) async {
    final tab = find.text(label).first;
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('without a selected customer shows a message', (tester) async {
    await pump(tester, size: const Size(1280, 800), select: false);

    expect(find.text('No customer selected.'), findsOneWidget);
    expect(find.byType(DetailPageScaffold<CustomerProfileTab>), findsNothing);
  });

  testWidgets('picks up a customer selected later', (tester) async {
    final customers =
        await pump(tester, size: const Size(1280, 800), select: false);

    customers.selectCustomer(testCustomer(name: 'Ravi'));
    await tester.pump();

    expect(find.byType(CustomerInfoTab), findsOneWidget);
    expect(find.text('Ravi'), findsWidgets);
  });

  for (final (label, size) in [
    ('mobile', const Size(375, 812)),
    ('desktop', const Size(1280, 800)),
  ]) {
    final mobile = size.width < DetailLayoutBreakpoints.mobileBelow;
    final loyaltyLabel = mobile ? 'Loyalty' : 'Loyalty Card';
    const chatLabel = 'Chat';
    final infoLabel = mobile ? 'Info' : 'Information';

    testWidgets('$label: header, summary and all tabs in order',
        (tester) async {
      await pump(tester, size: size);

      expect(find.text('Customer Profile'), findsOneWidget);
      expect(find.text('All Customers'), findsOneWidget);
      expect(find.text('ID: 42'), findsOneWidget);
      expect(selectedTab(tester), CustomerProfileTab.info);
      expect(find.byType(CustomerInfoTab), findsOneWidget);

      final tabs = tester
          .widget<DetailPageScaffold<CustomerProfileTab>>(
            find.byType(DetailPageScaffold<CustomerProfileTab>),
          )
          .tabs;
      expect(tabs.map((t) => t.id), CustomerProfileTab.values);
      expect(tabs.first.label, infoLabel);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label: tabs switch the content without overflow',
        (tester) async {
      await pump(tester, size: size);

      await tapTab(tester, loyaltyLabel);
      expect(selectedTab(tester), CustomerProfileTab.loyalty);
      expect(find.byType(CustomerLoyaltyTab), findsOneWidget);
      expect(find.byType(CustomerInfoTab), findsNothing);

      await tapTab(tester, chatLabel);
      expect(selectedTab(tester), CustomerProfileTab.chat);
      expect(find.byType(CustomerChatTab), findsOneWidget);
      expect(find.text('No Messages Yet'), findsOneWidget);

      await tapTab(tester, infoLabel);
      expect(selectedTab(tester), CustomerProfileTab.info);
      expect(find.byType(CustomerInfoTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label: the Message quick action opens the chat tab',
        (tester) async {
      await pump(tester, size: size);

      final message = find.text('Message');
      await tester.ensureVisible(message);
      await tester.pumpAndSettle();
      await tester.tap(message);
      await tester.pumpAndSettle();

      expect(selectedTab(tester), CustomerProfileTab.chat);
      expect(find.byType(CustomerChatTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
