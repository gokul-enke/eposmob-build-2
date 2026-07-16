import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_card_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_desktop_table.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_filter_panel.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_page_header.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_ui.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  final customers = [
    CustomerListModelData(
      id: 1,
      name: 'Ava Williams',
      email: 'ava@example.com',
      phone: '+91 98765 43210',
      balance: 2450,
      customerType: 'B2C',
    ),
    CustomerListModelData(
      id: 2,
      name: 'Northwind Traders',
      email: 'accounts@northwind.example',
      phone: '+91 91234 56789',
      balance: -320.75,
      customerType: 'B2B',
    ),
    CustomerListModelData(
      id: 3,
      name: 'Mia Anderson',
      email: 'mia@example.com',
      phone: '+91 99887 76655',
      balance: 0,
      customerType: 'B2C',
    ),
  ];

  Future<void> pumpPreview(
    WidgetTester tester, {
    required Size size,
    required bool mobile,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    addTearDown(nameController.dispose);
    addTearDown(emailController.dispose);
    addTearDown(phoneController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3C92F5),
          ),
        ),
        home: Scaffold(
          backgroundColor: CustomerUiColors.canvas,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomerPageHeader(
                    onAddCustomer: () {},
                    onRefresh: () {},
                  ),
                  const SizedBox(height: 14),
                  if (!mobile) ...[
                    CustomerFilterPanel(
                      nameController: nameController,
                      emailController: emailController,
                      phoneController: phoneController,
                      selectedBalanceFilter: 'All',
                      onSearch: () {},
                      onBalanceChanged: (_) {},
                      onReset: () {},
                    ),
                    const SizedBox(height: 14),
                  ],
                  Expanded(
                    child: mobile
                        ? CustomerCardList(
                            customers: customers,
                            currentPage: 1,
                            itemsPerPage: 20,
                            onViewCustomer: (_) {},
                          )
                        : CustomerDesktopTable(
                            customers: customers,
                            currentPage: 1,
                            itemsPerPage: 20,
                            onViewCustomer: (_) {},
                          ),
                  ),
                  CustomerPaginationBar(
                    currentPage: 1,
                    totalPages: 4,
                    visibleItemCount: customers.length,
                    onPageChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop customer list visual regression', (tester) async {
    await pumpPreview(
      tester,
      size: const Size(1366, 768),
      mobile: false,
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/customer_list_desktop.png'),
    );
  });

  testWidgets('phone customer list visual regression', (tester) async {
    await pumpPreview(
      tester,
      size: const Size(390, 844),
      mobile: true,
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/customer_list_phone.png'),
    );
  });

  testWidgets('pagination buttons preserve page boundaries', (tester) async {
    var selectedPage = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerPaginationBar(
            currentPage: 2,
            totalPages: 3,
            visibleItemCount: 20,
            onPageChanged: (page) => selectedPage = page,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Previous page'));
    expect(selectedPage, 1);

    await tester.tap(find.byTooltip('Next page'));
    expect(selectedPage, 3);
  });
}
