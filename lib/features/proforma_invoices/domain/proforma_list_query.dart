Map<String, dynamic> proformaMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String proformaText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? '-' : text;
}

int? proformaInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class ProformaListQuery {
  const ProformaListQuery(
      {this.invoiceNumber = '', this.customerSearch = '', this.status = 'All'});
  final String invoiceNumber, customerSearch, status;
  Map<String, String> toParameters() => {
        if (invoiceNumber.trim().isNotEmpty)
          'invoice_number': invoiceNumber.trim(),
        if (customerSearch.trim().isNotEmpty)
          'customer_search': customerSearch.trim(),
        if (status != 'All') 'status': status,
      };
}
