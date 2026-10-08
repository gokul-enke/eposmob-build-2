import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/sales/domain/models/day_close_pending_status.dart';
import 'package:pos_machine/models/master_data.dart';

import '../../data/closing_cash_breakdown.dart';
import 'closing_form_time_values.dart';
import 'day_close_form_ports.dart';

class DayCloseFormController extends ChangeNotifier {
  final timeValues = ClosingFormTimeValues();
  DateTime? parseDate(String v) => timeValues.parseDate(v);
  String? extractWorkingStartTime(String v) =>
      timeValues.extractWorkingStartTime(v);
  TimeOfDay? parseTimeOfDay(String v) => timeValues.parseTimeOfDay(v);
  bool isTimeBefore(TimeOfDay a, String b) => timeValues.isTimeBefore(a, b);
  DayCloseFormController(
      {required this.ports,
      required this.onCompleted,
      required this.onError,
      this.openDraft,
      this.pendingBusinessDate,
      this.pendingOpeningTransactionId,
      this.pendingClosingTransactionId});
  final DayCloseFormPorts ports;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String> onError;
  final OpenDraftModel? openDraft;
  final String? pendingBusinessDate;
  final int? pendingOpeningTransactionId;
  final int? pendingClosingTransactionId;
  bool disposed = false;
  void update(VoidCallback callback) {
    if (disposed) return;
    callback();
    notifyListeners();
  }

  void initialize() {
    fetchSummary();
    fetchDenominations();
    ensureBreakdownRows();
    if (openDraft != null) prefillFromOpenDraft(openDraft!);
  }

  bool isLoadingSummary = true;
  bool isSubmitting = false;
  DailySalesCloseSummary? summary;
  String? errorMessage;
  int currentStep = 0; // 0 = Cash Closing form, 1 = Confirm Close
  final TextEditingController businessDateController = TextEditingController();
  final TextEditingController shiftNameController = TextEditingController();
  final TextEditingController openingTimeController = TextEditingController();
  final TextEditingController closingTimeController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController cashRefundsController = TextEditingController();
  final TextEditingController cashDropAmountController =
      TextEditingController();
  final TextEditingController openingCashInHandController =
      TextEditingController();
  final TextEditingController closingCashInHandController =
      TextEditingController();
  final List<TextEditingController> openingDenominationControllers = [];
  final List<TextEditingController> openingCountControllers = [];
  final List<TextEditingController> closingDenominationControllers = [];
  final List<TextEditingController> closingCountControllers = [];
  final ScrollController scrollController = ScrollController();

  List<MasterDataValue> cashDenominations = [];
  bool isLoadingDenominations = true;
  bool openingPrefilled = false;

  double expenseCash = 0.0;
  double expenseBank = 0.0;
  double expenseTotal = 0.0;

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
    if (openingDenominationControllers.isEmpty) {
      addOpeningBreakdownRow();
    }
    if (closingDenominationControllers.isEmpty) {
      addClosingBreakdownRow();
    }
  }

  void prefillFromOpenDraft(OpenDraftModel draft) {
    shiftNameController.text = draft.shiftName ?? '';
    if (draft.openingTime != null && draft.openingTime!.isNotEmpty) {
      openingTimeController.text = draft.openingTime!;
    }
    final cashSummary = draft.cashSummary;
    if (cashSummary == null) return;

    openingCashInHandController.text = cashSummary.openingCashInHand ?? '';

    if (cashSummary.openingCashBreakdown != null &&
        cashSummary.openingCashBreakdown!.isNotEmpty) {
      for (final controller in openingDenominationControllers) {
        controller.dispose();
      }
      openingDenominationControllers.clear();
      for (final controller in openingCountControllers) {
        controller.dispose();
      }
      openingCountControllers.clear();
      for (final item in cashSummary.openingCashBreakdown!) {
        addOpeningBreakdownRow(
          denomination: item['denomination']?.toString() ?? '',
          count: item['count']?.toString() ?? '',
        );
      }
    }
    update(() {
      openingPrefilled = true;
    });
  }

  void addOpeningBreakdownRow({String denomination = '', String count = ''}) {
    openingDenominationControllers.add(
      TextEditingController(text: denomination),
    );
    openingCountControllers.add(TextEditingController(text: count));
  }

  void addClosingBreakdownRow({String denomination = '', String count = ''}) {
    closingDenominationControllers.add(
      TextEditingController(text: denomination),
    );
    closingCountControllers.add(TextEditingController(text: count));
  }

  void recalculateClosingCash() {
    double total = 0.0;
    for (var i = 0; i < closingDenominationControllers.length; i++) {
      final denomText = closingDenominationControllers[i].text.trim();
      final countText = closingCountControllers[i].text.trim();
      final denomVal = double.tryParse(denomText) ?? 0.0;
      final countVal = double.tryParse(countText) ?? 0.0;
      total += denomVal * countVal;
    }
    final totalStr = total == 0.0
        ? ''
        : total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    if (closingCashInHandController.text != totalStr) {
      closingCashInHandController.text = totalStr;
    }
  }

  List<Map<String, dynamic>> buildBreakdownPayload(
          List<TextEditingController> denominations,
          List<TextEditingController> counts) =>
      closingCashBreakdown(denominations.map((c) => c.text).toList(),
          counts.map((c) => c.text).toList());

  // Mirrors the same controller-vs-summary fallback used in submitDayClose,
  // so the Confirm Close preview always matches what will actually be sent.
  num get liveOpeningCashInHand =>
      num.tryParse(openingCashInHandController.text.trim()) ??
      summary?.openingCashInHand ??
      0;

  num get liveCashRefunds =>
      num.tryParse(cashRefundsController.text.trim()) ??
      summary?.cashRefunds ??
      0;

  num get liveCashDropAmount =>
      num.tryParse(cashDropAmountController.text.trim()) ??
      summary?.cashDropAmount ??
      0;

  num get cashSales =>
      num.tryParse((summary?.cashSales ?? '0').replaceAll(',', '')) ?? 0;

  num get cashExpensesForFormula => summary?.cashExpenses ?? 0;

  // expected_closing_cash = opening_cash_in_hand + cash_sales
  //     - cash_refunds - cash_expenses - cash_drop_amount
  // (confirmed against the live daily-sales-close API response)
  num get expectedClosingCash =>
      liveOpeningCashInHand +
      cashSales -
      liveCashRefunds -
      cashExpensesForFormula -
      liveCashDropAmount;

  num get todayCashCollection => expectedClosingCash - liveOpeningCashInHand;

  @override
  void dispose() {
    businessDateController.dispose();
    shiftNameController.dispose();
    openingTimeController.dispose();
    closingTimeController.dispose();
    notesController.dispose();
    cashRefundsController.dispose();
    cashDropAmountController.dispose();
    openingCashInHandController.dispose();
    closingCashInHandController.dispose();
    scrollController.dispose();
    for (final controller in openingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in openingCountControllers) {
      controller.dispose();
    }
    for (final controller in closingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in closingCountControllers) {
      controller.dispose();
    }
    disposed = true;
    super.dispose();
  }

  Future<void> fetchSummary() async {
    if (disposed) return;
    update(() {
      isLoadingSummary = true;
      errorMessage = null;
    });

    try {
      final authModel = ports.auth;
      final storeSession = ports.store;
      final salesProvider = ports.sales;

      final storeId = storeSession.activeStore?.storeId ?? 0;

      final result = await salesProvider.fetchDailySalesCloseSummary(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        businessDate: pendingBusinessDate,
      );

      if (disposed) return;

      update(() {
        summary = result;
        businessDateController.text =
            pendingBusinessDate ?? result?.businessDate ?? '';
        expenseCash = (result?.cashExpenses ?? 0).toDouble();
        expenseBank = (result?.bankExpenses ?? 0).toDouble();
        expenseTotal = (result?.totalExpenses ?? 0).toDouble();
        if (!openingPrefilled) {
          shiftNameController.text = result?.shiftName ?? '';
        }

        // Opening Time: always fill from summary if still empty
        // (widget.openingTime from pending-status can be null)
        if (openingTimeController.text.isEmpty) {
          final storeOpenTime = storeSession.activeStore?.storeOpenTime;
          final fallbackTime = storeOpenTime ?? '08:00:00';
          final hasActiveShift = openDraft != null;
          openingTimeController.text = (hasActiveShift &&
                  result?.openingTime != null &&
                  result!.openingTime!.isNotEmpty)
              ? result.openingTime!
              : fallbackTime;
        }
        closingTimeController.text = '';
        notesController.text = result?.notes ?? '';
        cashRefundsController.text = result?.cashRefunds?.toString() ?? '';
        cashDropAmountController.text =
            result?.cashDropAmount?.toString() ?? '';
        if (!openingPrefilled) {
          openingCashInHandController.text =
              result?.openingCashInHand?.toString() ?? '';
          // Populate opening breakdown from summary if available
          if (result?.openingCashBreakdown != null &&
              result!.openingCashBreakdown!.isNotEmpty) {
            for (final controller in openingDenominationControllers) {
              controller.dispose();
            }
            openingDenominationControllers.clear();
            for (final controller in openingCountControllers) {
              controller.dispose();
            }
            openingCountControllers.clear();
            for (final item in result.openingCashBreakdown!) {
              addOpeningBreakdownRow(
                denomination: item['denomination']?.toString() ?? '',
                count: item['count']?.toString() ?? '',
              );
            }
          }
        }
        closingCashInHandController.text =
            result?.closingCashInHand?.toString() ?? '';
        isLoadingSummary = false;
      });
    } catch (e) {
      if (disposed) return;

      update(() {
        errorMessage = e.toString();
        isLoadingSummary = false;
      });
    }
  }

  Future<void> submitDayClose() async {
    if (disposed || isSubmitting) return;
    update(() {
      isSubmitting = true;
    });

    try {
      final authModel = ports.auth;
      final storeSession = ports.store;
      final salesProvider = ports.sales;

      final storeId = storeSession.activeStore?.storeId ?? 0;

      final result = await salesProvider.createDailySalesClose(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        shiftName: shiftNameController.text.trim().isEmpty
            ? summary?.shiftName
            : shiftNameController.text.trim(),
        businessDate: businessDateController.text.trim().isEmpty
            ? summary?.businessDate
            : businessDateController.text.trim(),
        openingDate: summary?.openingDate,
        openingTime: openingTimeController.text.trim().isEmpty
            ? summary?.openingTime
            : openingTimeController.text.trim(),
        closingDate: summary?.closingDate,
        closingTime: closingTimeController.text.trim().isEmpty
            ? summary?.closingTime
            : closingTimeController.text.trim(),
        cashRefunds: num.tryParse(cashRefundsController.text.trim()) ??
            summary?.cashRefunds,
        cashExpenses: summary?.cashExpenses,
        cashDropAmount: num.tryParse(cashDropAmountController.text.trim()) ??
            summary?.cashDropAmount,
        openingCashInHand:
            num.tryParse(openingCashInHandController.text.trim()) ??
                summary?.openingCashInHand,
        openingCashBreakdown: buildBreakdownPayload(
          openingDenominationControllers,
          openingCountControllers,
        ),
        closingCashInHand:
            num.tryParse(closingCashInHandController.text.trim()) ??
                summary?.closingCashInHand,
        closingCashBreakdown: buildBreakdownPayload(
          closingDenominationControllers,
          closingCountControllers,
        ),
        notes: notesController.text.trim().isEmpty
            ? summary?.notes
            : notesController.text.trim(),
        openingTransactionId: pendingOpeningTransactionId,
        closingTransactionId: pendingClosingTransactionId,
      );

      if (result['success'] == true) {
        if (!disposed) {
          onCompleted(result['message'] ??
              'daily_sales_close.msg_day_close_created'.tr);
        }
      } else {
        if (!disposed) {
          String errorMessage =
              result['message'] ?? 'Failed to create day close';
          final errors = result['errors'];
          if (errors != null && errors is Map) {
            final errorDetails =
                errors.values.expand((e) => e is List ? e : [e]).join('\n');
            if (errorDetails.isNotEmpty) {
              errorMessage = '$errorMessage:\n$errorDetails';
            }
          }

          onError(errorMessage);
        }
      }
    } catch (e) {
      if (!disposed) {
        onError(e.toString());
      }
    } finally {
      if (!disposed) {
        update(() {
          isSubmitting = false;
        });
      }
    }
  }
}
