import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/features/quotations/data/quotation_list_repository.dart';
import 'package:pos_machine/features/quotations/domain/quotation_list_query.dart';

Quotation quotation(int id) => Quotation(
    id: id,
    quotationNumber: 'QTN-${id.toString().padLeft(5, '0')}',
    customer: 'Buyer $id',
    store: 'Main',
    quotationDate: '2026-09-28 00:00:00',
    expiryDate: '2026-10-28',
    status: id.isEven ? 'pending' : 'order created');

class FakeQuotationListSource implements QuotationListSource {
  final requests = <({QuotationListQuery query, int page})>[];
  final snapshots = <QuotationListQuery>[];
  bool fail = false;
  Future<QuotationListPageData> Function(QuotationListQuery query, int page)?
      handler;
  @override
  Future<QuotationListPageData> fetch(
      String token, QuotationListQuery query, int page) async {
    requests.add((query: query, page: page));
    if (handler != null) return handler!(query, page);
    if (fail) throw StateError('offline');
    return QuotationListPageData(
        rows: List.generate(3, (i) => quotation((page - 1) * 3 + i + 1)),
        current: page,
        last: 2,
        from: (page - 1) * 3 + 1,
        total: 6,
        perPage: 3);
  }

  @override
  Future<List<Quotation>> snapshot(String token, QuotationListQuery query,
      {void Function(int, int)? progress}) async {
    snapshots.add(query);
    if (fail) throw StateError('export offline');
    progress?.call(1, 2);
    progress?.call(2, 2);
    return List.generate(6, (i) => quotation(i + 1));
  }
}
