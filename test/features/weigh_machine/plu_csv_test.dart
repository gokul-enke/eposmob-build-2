import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  test('exports only weighted products and preserves CSV data', () {
    final weighted = GetProduct(
      productId: 1,
      productName: 'Apples, "red"',
      category: ProductCategory(name: 'Fruit'),
      barcode: '0000123',
      price: ProductPrice(price: '4'),
      mrp: '5.5',
      unit: 'KG',
      purchasePrice: '2',
      names: {'ar': 'تفاح'},
      weightInfo: WeightInfo(isWeighted: true),
    );
    final ordinary = GetProduct(
      productId: 2,
      productName: 'Bag',
      weightInfo: WeightInfo(isWeighted: false),
    );

    final items = PluCsv.weighted([weighted, ordinary]);
    expect(items, [weighted]);
    expect(
      PluCsv.build(items),
      'Product Name,Category,Barcode,Price,MRP,Unit,Purchase Price,Arabic Name\r\n'
      '"Apples, ""red""",Fruit,0000123,4.00,5.50,KG,2.00,تفاح\r\n',
    );
  });
}
