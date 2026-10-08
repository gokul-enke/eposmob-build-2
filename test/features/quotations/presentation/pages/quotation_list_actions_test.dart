import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/features/quotations/presentation/pages/quotation_list_actions.dart';
import 'package:pos_machine/features/quotations/presentation/navigation/quotation_list_navigation.dart';

class DetailsProvider extends QuotationsProvider {
  Future<QuotationDetailsData?> Function()? details;
  final requests = <({String token, dynamic id})>[];
  @override
  Future<QuotationDetailsData?> fetchQuotationDetails(
      {required String accessToken, required dynamic quotationId}) async {
    requests.add((token: accessToken, id: quotationId));
    return details?.call();
  }
}

class DraftProducts extends Fake implements LocalProductProvider {
  SavedOrder? draft;
  final product = GetProduct(
      productId: 11,
      mrp: '72',
      stock: [Stock(id: 19, productId: 11)],
      saleUnits: [SaleUnit(id: 7, unitName: 'Pack', conversionRate: '6')]);
  final fallbackQuantities = <num>[];
  @override
  GetProduct? getProductById(int productId) => productId == 11 ? product : null;
  @override
  Stock? selectStockForQuantity(GetProduct product, num quantity) {
    fallbackQuantities.add(quantity);
    return null;
  }

  @override
  void loadQuotationDraftForEditing(SavedOrder draft) => this.draft = draft;
}

class ActionHost extends StatefulWidget {
  const ActionHost(
      {super.key,
      required this.auth,
      required this.quotes,
      required this.products,
      required this.navigation});
  final AuthModel auth;
  final DetailsProvider quotes;
  final DraftProducts products;
  final QuotationListNavigation navigation;
  @override
  State<ActionHost> createState() => ActionHostState();
}

class ActionHostState extends State<ActionHost>
    with QuotationListActions<ActionHost> {
  @override
  AuthModel get auth => widget.auth;
  @override
  QuotationsProvider get quotationProvider => widget.quotes;
  @override
  LocalProductProvider get localProducts => widget.products;
  @override
  QuotationListNavigation get quotationNavigation => widget.navigation;
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  for (final inline in [false, true]) {
    testWidgets(
        'convert retains sale-unit, stock, tax and customer mapping (inline=$inline)',
        (tester) async {
      final auth = AuthModel()..login('token', 1);
      final quotes = DetailsProvider();
      final products = DraftProducts();
      final sidebar = SideBarController();
      final key = GlobalKey<ActionHostState>();
      quotes.details = () async => QuotationDetailsData(
          id: 22,
          quotationNumber: 'QTN-00022',
          customer: QuotationCustomer(
              id: 8, name: 'Buyer', phone: '00123', isInline: inline),
          address: {'address_line_1': 'Road', 'city': 'Town'},
          grandTotal: '1,200.50',
          discount: '5.50',
          deliveryCharge: '12.50',
          deliveryMethodId: '3',
          deliveryMethod: 'Delivery',
          comment: 'Keep note',
          items: [
            QuotationItem(
                productId: 11,
                quantity: '2',
                unitPrice: '60',
                productStockId: 19,
                productSaleUnitId: 7,
                taxRate: '15',
                taxAmount: '18',
                comment: 'Pack note'),
            QuotationItem(
                productId: 12,
                productName: 'Missing local product',
                unit: 'PC',
                quantity: '3',
                unitPrice: '5'),
            QuotationItem(productId: 13, quantity: '0', unitPrice: '9'),
            QuotationItem(quantity: '1', unitPrice: '9'),
          ]);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ActionHost(
                  key: key,
                  auth: auth,
                  quotes: quotes,
                  products: products,
                  navigation: QuotationListNavigation(sidebar, quotes)))));
      await key.currentState!.convertQuotationToOrder(Quotation(id: 22));
      await tester.pumpAndSettle();
      final draft = products.draft!;
      expect(quotes.requests.single, (token: 'token', id: 22));
      expect(draft.items, hasLength(2));
      final pack = draft.items.first;
      expect(identical(pack.product, products.product), isTrue);
      expect(pack.quantity, 12);
      expect(pack.price, 10);
      expect(pack.mrp, 12);
      expect(pack.saleUnitId, 7);
      expect(pack.saleUnitName, 'Pack');
      expect(pack.saleUnitConversionRate, 6);
      expect(pack.selectedStock!.id, 19);
      expect(pack.stockGroupIds, [19]);
      expect(pack.taxRate, 15);
      expect(pack.taxAmount, 18);
      expect(pack.comment, 'Pack note');
      expect(pack.isManualPriceOverride, isTrue);
      expect(draft.items.last.product.productId, 12);
      expect(draft.items.last.quantity, 3);
      expect(draft.items.last.price, 5);
      expect(products.fallbackQuantities, [3]);
      expect(draft.customerId, inline ? null : 8);
      expect(draft.customerType, inline ? 'new' : 'existing');
      expect(draft.customerPhone, '00123');
      expect(draft.address, 'Road, Town');
      expect(draft.total, 1200.50);
      expect(draft.flatDiscount, 5.50);
      expect(draft.deliveryCharge, 12.50);
      expect(draft.deliveryMethodId, '3');
      expect(draft.comment, 'Keep note');
      expect(draft.quotationId, 22);
      expect(draft.quotationNumber, 'QTN-00022');
      expect(sidebar.index.value, 90);
      expect(key.currentState!.isConvertingQuotation, isFalse);
      auth.dispose();
      quotes.dispose();
    });
  }
  testWidgets('single conversion in flight; disposed page cannot load a draft',
      (tester) async {
    final pending = Completer<QuotationDetailsData?>();
    final quotes = DetailsProvider()..details = () => pending.future;
    final products = DraftProducts();
    final auth = AuthModel()..login('token', 1);
    final sidebar = SideBarController();
    final key = GlobalKey<ActionHostState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ActionHost(
                key: key,
                auth: auth,
                quotes: quotes,
                products: products,
                navigation: QuotationListNavigation(sidebar, quotes)))));
    final state = key.currentState!;
    final first = state.convertQuotationToOrder(Quotation(id: 22));
    await state.convertQuotationToOrder(Quotation(id: 23));
    expect(quotes.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(QuotationDetailsData(
        items: [QuotationItem(productId: 11, quantity: '1')]));
    await first;
    expect(products.draft, isNull);
    expect(sidebar.index.value, isNot(90));
    expect(tester.takeException(), isNull);
    auth.dispose();
    quotes.dispose();
  });
  test('list navigation retains existing create and details destinations', () {
    final quotes = QuotationsProvider();
    final sidebar = SideBarController();
    final navigation = QuotationListNavigation(sidebar, quotes);
    navigation.openNew();
    expect(sidebar.index.value, 86);
    navigation.openView(22);
    expect(sidebar.index.value, 88);
    expect(quotes.selectedQuotationId, 22);
    quotes.dispose();
  });
}
