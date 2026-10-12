import 'proforma_list_query.dart';

/// The existing response sections. Customer and quotation maps are prepared
/// before opening the dialog, as in the legacy view; item rows stay view data.
class ProformaDetails {
  ProformaDetails.fromMap(this.invoice)
      : customer = proformaMap(invoice['customer']),
        quotation = proformaMap(invoice['quotation']),
        items = invoice['items'] is List ? invoice['items'] as List : const [];

  final Map<String, dynamic> invoice;
  final Map<String, dynamic> customer;
  final Map<String, dynamic> quotation;
  final List<dynamic> items;
}
