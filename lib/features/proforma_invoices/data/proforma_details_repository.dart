import 'package:pos_machine/providers/quotations_provider.dart';

/// Keeps the existing details endpoint, authentication and provider contract.
class ProformaDetailsRepository {
  const ProformaDetailsRepository(this._provider);

  final QuotationsProvider _provider;

  Future<Map<String, dynamic>> fetchDetails({
    required String accessToken,
    required dynamic invoiceId,
  }) =>
      _provider.fetchProformaInvoiceDetails(
        accessToken: accessToken,
        invoiceId: invoiceId,
      );
}
