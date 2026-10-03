import '../../domain/models/customer_list.dart';

/// Whether the customer owes the store (to pay) or the store owes the
/// customer (to receive) the opening balance.
enum CustomerPaymentType {
  none(''),
  toPay('to_pay'),
  toReceive('to_receive');

  const CustomerPaymentType(this.apiValue);

  /// Value sent as `payment_type`.
  final String apiValue;

  /// Unknown or missing values fall back to [fallback].
  static CustomerPaymentType parse(
    String? value, {
    CustomerPaymentType fallback = CustomerPaymentType.none,
  }) {
    switch (value?.trim().toLowerCase()) {
      case 'to_pay':
        return toPay;
      case 'to_receive':
        return toReceive;
      default:
        return fallback;
    }
  }
}

/// Gender values the API accepts.
abstract final class CustomerGenders {
  static const values = ['male', 'female', 'other'];
}

/// Result of [CustomerFormController.submit].
sealed class CustomerFormOutcome {
  const CustomerFormOutcome();
}

/// A customer was created. [result] is the map the add-customer dialog
/// resolves to: `{'status': 'success', 'phone', 'name', 'response'}`.
class CustomerCreated extends CustomerFormOutcome {
  const CustomerCreated({required this.result, required this.message});

  final Map<String, dynamic> result;
  final String message;
}

/// The customer was updated; [customer] holds the edited values.
class CustomerUpdated extends CustomerFormOutcome {
  const CustomerUpdated({required this.customer, required this.message});

  final CustomerListModelData customer;
  final String message;
}

/// Edit mode: nothing differs from the saved customer, no request was sent.
class CustomerUnchanged extends CustomerFormOutcome {
  const CustomerUnchanged();
}

/// Nothing was saved; [message] explains why.
class CustomerFormFailed extends CustomerFormOutcome {
  const CustomerFormFailed(this.message);

  final String message;
}

/// Formats [date] as `yyyy-MM-dd` (the API's date format).
String formatCustomerDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Loose name matching used to map a picked map location (free text) onto
/// the state / district / pincode lists: ignores case and words such as
/// "province" or "district", accepts containment and ≥ 75 % similarity.
abstract final class LocationNameMatcher {
  static const _noiseWords = [
    'province',
    'region',
    'governorate',
    'district',
    'municipality',
    'city',
    'state',
  ];

  static String _normalize(String input) {
    var clean = input.toLowerCase().trim();
    for (final word in _noiseWords) {
      clean = clean.replaceAll(word, '');
    }
    return clean.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matches(String source, String target) {
    final a = _normalize(source);
    final b = _normalize(target);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    final longest = a.length > b.length ? a.length : b.length;
    return 1.0 - (_levenshtein(a, b) / longest) >= 0.75;
  }

  /// First entry whose value matches [name], or `null`.
  static MapEntry<String, String>? find(
    List<MapEntry<String, String>> entries,
    String name,
  ) {
    for (final entry in entries) {
      if (matches(entry.value, name)) return entry;
    }
    return null;
  }

  static int _levenshtein(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final best = previous[j] + 1 < current[j - 1] + 1
            ? previous[j] + 1
            : current[j - 1] + 1;
        current[j] =
            best < previous[j - 1] + cost ? best : previous[j - 1] + cost;
      }
      previous = current;
    }
    return previous[b.length];
  }
}
