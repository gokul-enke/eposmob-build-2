import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/models/customer_list.dart';
import 'customer_provider.dart';

/// Reads the access token used for the address API calls.
typedef AccessTokenReader = Future<String?> Function();

/// Re-fetches one customer; resolves with the raw API response.
typedef CustomerReloader = Future<dynamic> Function(
  String accessToken,
  int customerId,
);

/// Creates an address; resolves with the raw API response.
typedef AddressCreator = Future<dynamic> Function(
  String accessToken,
  Map<String, dynamic> data,
);

/// Updates an address; resolves with the raw API response.
typedef AddressUpdater = Future<dynamic> Function(
  String accessToken,
  int addressId,
  Map<String, dynamic> data,
);

/// Outcome of [CustomerAddressController.save].
@immutable
class AddressSaveResult {
  const AddressSaveResult._(this.success, this.message, this.address);

  const AddressSaveResult.saved(Address address, String message)
      : this._(true, message, address);

  const AddressSaveResult.failed(String message) : this._(false, message, null);

  final bool success;

  /// User-facing message (server message when it sent one).
  final String message;

  /// The saved address (only when [success]).
  final Address? address;
}

/// State for one customer's address book: the current address list, a
/// reload from the API, and add/update through the customer repository.
class CustomerAddressController extends ChangeNotifier {
  CustomerAddressController({
    required CustomerListModelData customer,
    required AccessTokenReader readToken,
    required CustomerReloader reloadCustomer,
    required AddressCreator createAddress,
    required AddressUpdater updateAddress,
  })  : _customer = customer,
        _readToken = readToken,
        _reloadCustomer = reloadCustomer,
        _createAddress = createAddress,
        _updateAddress = updateAddress;

  /// Wires the controller to [CustomerProvider] (reload) and its repository
  /// (add/update).
  factory CustomerAddressController.withProvider({
    required CustomerListModelData customer,
    required CustomerProvider customerProvider,
    required AccessTokenReader readToken,
  }) {
    return CustomerAddressController(
      customer: customer,
      readToken: readToken,
      reloadCustomer: customerProvider.reloadSelectedCustomer,
      createAddress: customerProvider.repository.addAddress,
      updateAddress: customerProvider.repository.updateAddress,
    );
  }

  final AccessTokenReader _readToken;
  final CustomerReloader _reloadCustomer;
  final AddressCreator _createAddress;
  final AddressUpdater _updateAddress;

  CustomerListModelData _customer;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _disposed = false;

  CustomerListModelData get customer => _customer;
  List<Address> get addresses => _customer.addresses ?? const [];
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  /// The last [reload] did not return fresh data; the list shows what the
  /// controller already had.
  bool get loadFailed => _loadFailed;

  /// Re-fetches the customer to get the latest addresses. Keeps the current
  /// list when the request fails.
  Future<void> reload() async {
    final customerId = _customer.id;
    if (customerId == null) return;
    _isLoading = true;
    _loadFailed = false;
    _notify();
    try {
      final token = await _readToken();
      if (token == null) {
        _loadFailed = true;
        return;
      }
      final response = await _reloadCustomer(token, customerId);
      if (response is Map && response['status'] == 'success') {
        _customer = CustomerListModelData.fromJson(
          Map<String, dynamic>.from(response['data'] as Map),
        );
      } else {
        _loadFailed = true;
      }
    } catch (e) {
      _loadFailed = true;
      debugPrint('CustomerAddressController: reload failed: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Adds (when [existing] is null) or updates an address with [data] (see
  /// [buildAddressPayload]). On success the saved address replaces or joins
  /// the current list.
  Future<AddressSaveResult> save({
    required Map<String, dynamic> data,
    Address? existing,
  }) async {
    if (_isSaving) {
      return AddressSaveResult.failed('general.action_failed'.tr);
    }
    _isSaving = true;
    _notify();
    try {
      final token = await _readToken();
      if (token == null) {
        return AddressSaveResult.failed(
            'customer_profile.error_login_again'.tr);
      }
      final existingId = existing?.id;
      final dynamic response = existing == null || existingId == null
          ? await _createAddress(token, data)
          : await _updateAddress(token, existingId, data);

      if (response is! Map || response['status'] != 'success') {
        final message = response is Map ? response['message'] : null;
        return AddressSaveResult.failed(
          message?.toString() ?? 'general.action_failed'.tr,
        );
      }
      final body = response['data'];
      final saved = body is Map
          ? Address.fromJson(Map<String, dynamic>.from(body))
          : existing ?? Address.fromJson(data);
      upsert(saved);
      return AddressSaveResult.saved(
        saved,
        response['message']?.toString() ?? 'general.success'.tr,
      );
    } catch (e) {
      return AddressSaveResult.failed('${'general.error_prefix'.tr} $e');
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  /// Replaces the address with the same id, or appends [address].
  void upsert(Address address) {
    final list = List<Address>.of(addresses);
    final index =
        address.id == null ? -1 : list.indexWhere((a) => a.id == address.id);
    if (index == -1) {
      list.add(address);
    } else {
      list[index] = address;
    }
    _customer = _customer.copyWithAddresses(list);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The add/update address request body. Name and phone come from the
/// address being edited, else from the customer.
Map<String, dynamic> buildAddressPayload({
  required CustomerListModelData customer,
  Address? existing,
  required String address,
  required String city,
  required String landmark,
  required String type,
  String? stateId,
  String? districtId,
  String? pincodeId,
}) {
  return {
    'customer_id': customer.id,
    'name': existing?.name ?? customer.name,
    'phone': existing?.phone ?? customer.phone,
    'address': address,
    'city': city,
    'state_id': stateId,
    'district_id': districtId,
    'pincode_id': pincodeId,
    'landmark': landmark,
    'type': type,
  };
}
