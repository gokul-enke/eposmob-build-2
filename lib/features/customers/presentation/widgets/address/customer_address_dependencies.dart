import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_address_controller.dart';
import '../../state/customer_provider.dart';

/// Reads an app-level provider, or null when it is not in the tree.
T? _maybeRead<T>(BuildContext context) {
  try {
    return Provider.of<T>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Token reader for the address screens: the signed-in token, else the one
/// saved in preferences.
AccessTokenReader customerAddressTokenReader(BuildContext context) {
  final auth = _maybeRead<AuthModel>(context);
  final prefs = _maybeRead<SharedPreferenceProvider>(context);
  return () async => auth?.token ?? await prefs?.getToken();
}

/// Builds a [CustomerAddressController] from the app providers. Call from
/// `initState` (or a callback), never from `build`.
CustomerAddressController createCustomerAddressController(
  BuildContext context,
  CustomerListModelData customer,
) {
  return CustomerAddressController.withProvider(
    customer: customer,
    customerProvider: Provider.of<CustomerProvider>(context, listen: false),
    readToken: customerAddressTokenReader(context),
  );
}
