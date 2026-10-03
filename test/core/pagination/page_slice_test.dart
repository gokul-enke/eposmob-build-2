import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/pagination/page_slice.dart';

void main() {
  final numbers = List.generate(45, (index) => index + 1);

  test('cuts the requested page', () {
    final slice = PageSlice.of(numbers, page: 2, perPage: 20);
    expect(slice.items.first, 21);
    expect(slice.items.length, 20);
    expect(slice.currentPage, 2);
    expect(slice.totalPages, 3);
    expect(slice.totalItems, 45);
  });

  test('the last page holds the remainder', () {
    expect(PageSlice.of(numbers, page: 3, perPage: 20).items,
        [41, 42, 43, 44, 45]);
  });

  test('pages past the end clamp to the last page, below 1 to the first', () {
    expect(PageSlice.of(numbers, page: 9, perPage: 20).currentPage, 3);
    expect(PageSlice.of(numbers, page: 0, perPage: 20).currentPage, 1);
  });

  test('an empty list still has one empty page', () {
    final slice = PageSlice.of(<int>[], page: 4, perPage: 20);
    expect(slice.items, isEmpty);
    expect(slice.currentPage, 1);
    expect(slice.totalPages, 1);
  });
}
