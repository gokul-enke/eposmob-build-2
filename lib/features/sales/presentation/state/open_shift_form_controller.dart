import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/master_data.dart';

import 'open_shift_form_ports.dart';

class OpenShiftFormController extends ChangeNotifier {
  OpenShiftFormController({required this.ports, required this.onCompleted});
  final OpenShiftFormPorts ports;
  final VoidCallback onCompleted;
  bool disposed = false;
  void update(VoidCallback callback) {
    if (disposed) return;
    callback();
    notifyListeners();
  }

  void initialize() {
    selectedStoreId = ports.store.activeStore?.storeId;
    selectedStoreName = ports.store.activeStore?.storeName;
    businessDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    openingTimeController.text =
        ports.store.activeStore?.storeOpenTime ?? '08:00:00';
    fetchDenominations();
    ensureBreakdownRows();
  }

  final TextEditingController shiftNameController =
      TextEditingController(text: 'Shift');
  final TextEditingController businessDateController = TextEditingController();
  final TextEditingController openingTimeController = TextEditingController();
  final TextEditingController openingCashInHandController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<TextEditingController> denominationControllers = [];
  final List<TextEditingController> countControllers = [];

  bool isLoading = false;
  bool isLoadingDenominations = true;
  String? errorMessage;
  int? selectedStoreId;
  String? selectedStoreName;
  List<MasterDataValue> cashDenominations = [];

  @override
  void dispose() {
    shiftNameController.dispose();
    businessDateController.dispose();
    openingTimeController.dispose();
    openingCashInHandController.dispose();
    notesController.dispose();
    scrollController.dispose();
    for (final c in denominationControllers) {
      c.dispose();
    }
    for (final c in countControllers) {
      c.dispose();
    }
    disposed = true;
    super.dispose();
  }

  Future<void> fetchDenominations() async {
    try {
      final masterDataProvider = ports.master;
      final result = await masterDataProvider.fetchCashDenominations();
      if (!disposed) {
        update(() {
          cashDenominations = result ?? [];
          isLoadingDenominations = false;
        });
      }
    } catch (e) {
      if (!disposed) {
        update(() {
          isLoadingDenominations = false;
        });
      }
    }
  }

  void ensureBreakdownRows() {
    if (denominationControllers.isEmpty) {
      addBreakdownRow();
    }
  }

  void addBreakdownRow({String denomination = '', String count = ''}) {
    denominationControllers.add(TextEditingController(text: denomination));
    countControllers.add(TextEditingController(text: count));
  }

  void recalculateOpeningCash() {
    double total = 0.0;
    for (var i = 0; i < denominationControllers.length; i++) {
      final denomText = denominationControllers[i].text.trim();
      final countText = countControllers[i].text.trim();
      final denomVal = double.tryParse(denomText) ?? 0.0;
      final countVal = double.tryParse(countText) ?? 0.0;
      total += denomVal * countVal;
    }
    final totalStr = total == 0.0
        ? ''
        : total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    if (openingCashInHandController.text != totalStr) {
      openingCashInHandController.text = totalStr;
    }
  }

  TimeOfDay? parseTimeOfDay(String timeValue) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timeValue);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime? parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveOpeningDraft() async {
    if (disposed || isLoading) return;
    if (openingTimeController.text.trim().isEmpty) {
      update(() {
        errorMessage = 'daily_sales_close.err_opening_time_required'.tr;
      });
      return;
    }

    update(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authModel = ports.auth;
      final salesProvider = ports.sales;

      final breakdown = <Map<String, dynamic>>[];
      for (var i = 0; i < denominationControllers.length; i++) {
        final denom = denominationControllers[i].text.trim();
        final countTxt = countControllers[i].text.trim();
        if (denom.isEmpty && countTxt.isEmpty) continue;
        breakdown.add({
          'denomination': denom,
          'count': int.tryParse(countTxt) ?? 0,
        });
      }

      final success = await salesProvider.openShiftApi(
        accessToken: authModel.token ?? '',
        storeId: selectedStoreId ?? 0,
        shiftName: shiftNameController.text.trim(),
        businessDate: businessDateController.text.trim(),
        openingDate: businessDateController.text.trim(),
        openingTime: openingTimeController.text.trim(),
        openingCashInHand:
            double.tryParse(openingCashInHandController.text.trim()) ?? 0.0,
        openingCashBreakdown: breakdown,
        notes: notesController.text.trim(),
      );

      if (!disposed) {
        if (success) {
          onCompleted();
        } else {
          update(() {
            errorMessage = 'daily_sales_close.err_open_shift_failed'.tr;
          });
        }
      }
    } catch (e) {
      if (!disposed) {
        update(() {
          errorMessage = e.toString();
        });
      }
    } finally {
      if (!disposed) {
        update(() {
          isLoading = false;
        });
      }
    }
  }
}
