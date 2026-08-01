import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/widgets/customer_ui.dart';

void main() {
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

  testWidgets('pagination fills its parent and uses the shared radius',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CustomerPaginationBar(
                currentPage: 1,
                totalPages: 3,
                visibleItemCount: 20,
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final pagination = find.byKey(const ValueKey('customer_pagination_bar'));
    expect(tester.getSize(pagination).width, 360);

    final container = tester.widget<Container>(pagination);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.border, isNotNull);
  });
}
