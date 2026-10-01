/// Whether the store has to pay the supplier (to pay) or the supplier owes
/// the store (to receive) the balance.
enum SupplierPaymentType {
  toPay('to_pay'),
  toReceive('to_receive');

  const SupplierPaymentType(this.apiValue);

  /// Value sent as `payment_status`.
  final String apiValue;

  /// Unknown or missing values mean [toPay].
  static SupplierPaymentType parse(String? value) =>
      value?.trim().toLowerCase() == 'to_receive' ? toReceive : toPay;
}

/// KYC keys the supplier form edits.
abstract final class SupplierKycKeys {
  static const crNumber = 'CR_NUMBER';
  static const vatNumber = 'VAT_NUMBER';
  static const edited = {crNumber, vatNumber};
}

/// Result of [SupplierFormController.submit].
sealed class SupplierFormOutcome {
  const SupplierFormOutcome();
}

/// A supplier was created. [result] is the map the add-supplier dialog
/// resolves to: `{'status': 'success', 'name', 'phone', 'response'}`.
class SupplierCreated extends SupplierFormOutcome {
  const SupplierCreated({required this.result, required this.message});

  final Map<String, dynamic> result;
  final String message;
}

/// The supplier was updated.
class SupplierUpdated extends SupplierFormOutcome {
  const SupplierUpdated({required this.message});

  final String message;
}

/// Nothing was saved; [message] explains why (empty: nothing to show).
class SupplierFormFailed extends SupplierFormOutcome {
  const SupplierFormFailed(this.message);

  final String message;
}
