import 'package:flutter/foundation.dart';
import 'package:pos_machine/core/ui/location/location_picker_dialog.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/providers/location_provider.dart';

import 'customer_form_values.dart';

/// State → district → pincode selection of the customer form, backed by the
/// app's [LocationProvider] lists. Notifies when a selection, a loading flag
/// or one of the provider's lists changes.
class CustomerLocationSelection extends ChangeNotifier {
  CustomerLocationSelection({this.provider, this.accessToken}) {
    provider?.addListener(notifyListeners);
  }

  final LocationProvider? provider;
  final String? accessToken;

  String? stateId;
  String? districtId;
  String? pincodeId;
  bool loadingDistricts = false;
  bool loadingPincodes = false;
  bool _disposed = false;

  List<MapEntry<String, String>> get states => provider?.stateList ?? const [];
  List<MapEntry<String, String>> get districts =>
      provider?.districtList ?? const [];
  List<MapEntry<String, String>> get pincodes =>
      provider?.pincodeList ?? const [];

  /// The selected pincode's text (the API stores the pincode itself, not
  /// its id), or `''`.
  String get pincodeValue {
    if (pincodeId == null) return '';
    for (final entry in pincodes) {
      if (entry.key == pincodeId) return entry.value;
    }
    return '';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadStates() async {
    final token = accessToken;
    if (provider == null || token == null) return;
    try {
      await provider!.listAllStates(token);
    } catch (error) {
      debugPrint('[CustomerLocationSelection] states failed: $error');
    }
  }

  Future<void> _loadDistricts(String stateId) async {
    final token = accessToken;
    if (provider == null || token == null) return;
    try {
      await provider!.listAllDistricts(stateId: stateId, accessToken: token);
    } catch (error) {
      debugPrint('[CustomerLocationSelection] districts failed: $error');
    }
  }

  Future<void> _loadPincodes(String districtId) async {
    final token = accessToken;
    if (provider == null || token == null) return;
    try {
      await provider!.listAllPincodes(
        districtId: districtId,
        accessToken: token,
      );
    } catch (error) {
      debugPrint('[CustomerLocationSelection] pincodes failed: $error');
    }
  }

  /// Picks a state, clears district and pincode and loads the districts.
  Future<void> selectState(String? id) async {
    stateId = id;
    districtId = null;
    pincodeId = null;
    loadingDistricts = id != null;
    _notify();
    if (id == null) return;
    await _loadDistricts(id);
    loadingDistricts = false;
    _notify();
  }

  /// Picks a district, clears the pincode and loads the pincodes.
  Future<void> selectDistrict(String? id) async {
    districtId = id;
    pincodeId = null;
    loadingPincodes = id != null;
    _notify();
    if (id == null) return;
    await _loadPincodes(id);
    loadingPincodes = false;
    _notify();
  }

  void selectPincode(String? id) {
    pincodeId = id;
    _notify();
  }

  void clear() {
    stateId = null;
    districtId = null;
    pincodeId = null;
    loadingDistricts = false;
    loadingPincodes = false;
    _notify();
  }

  /// Loads the states and preselects the active store's state, district and
  /// pincode when they exist in the lists. Falls back to the first store
  /// when [activeStoreId] is not in [stores]; does nothing without one.
  Future<void> prefillFromStore({
    required List<GetStoreModelData> stores,
    required int? activeStoreId,
  }) async {
    await loadStates();
    if (activeStoreId == null || stores.isEmpty || _disposed) return;
    final store = stores.firstWhere(
      (candidate) => candidate.id == activeStoreId,
      orElse: () => stores.first,
    );

    final state = store.stateId?.toString();
    if (state == null || !states.any((entry) => entry.key == state)) return;
    stateId = state;
    loadingDistricts = true;
    _notify();
    await _loadDistricts(state);
    loadingDistricts = false;

    final district = store.districtId?.toString();
    if (district == null ||
        !districts.any((entry) => entry.key == district) ||
        _disposed) {
      _notify();
      return;
    }
    districtId = district;
    loadingPincodes = true;
    _notify();
    await _loadPincodes(district);
    loadingPincodes = false;

    final pincode = store.pincodeId?.toString();
    if (pincode != null && pincodes.any((entry) => entry.key == pincode)) {
      pincodeId = pincode;
    }
    _notify();
  }

  /// Matches the picked map location's state, city and pincode names onto
  /// the lists (each level only when the previous one matched).
  Future<void> applyPickedLocation(LocationResult result) async {
    clear();
    final state = LocationNameMatcher.find(states, result.state);
    if (state == null) return;
    await selectState(state.key);

    final district = LocationNameMatcher.find(districts, result.city);
    if (district == null || _disposed) return;
    await selectDistrict(district.key);

    final pincode = LocationNameMatcher.find(pincodes, result.pincode);
    if (pincode != null) selectPincode(pincode.key);
  }

  @override
  void dispose() {
    _disposed = true;
    provider?.removeListener(notifyListeners);
    super.dispose();
  }
}
