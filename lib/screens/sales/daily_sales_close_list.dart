
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

import '../../components/build_dialog_box.dart';
import '../../models/daily_sales_close.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/screens/sales/open_shift_modal.dart';

import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/day_closes/presentation/pages/day_close_list_page.dart';

class DailySalesCloseListScreen extends StatelessWidget {
  const DailySalesCloseListScreen({super.key, this.readSource});
  final Future<DayCloseListSource> Function()? readSource;

  @override
  Widget build(BuildContext context) => DayCloseListPage(
        readSource: readSource,
        onView: (context, row) {
          final provider = context.read<SalesProvider>();
          provider.setSelectedDailySalesCloseData(row);
          provider.setReturnIndex(78);
          Get.find<SideBarController>().index.value = 79;
        },
        onOpenShift: (context, onSuccess) => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => OpenShiftModal(onSuccess: onSuccess)),
        onDayClose: (context, onSuccess, draft) => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
                DayCloseModal(onSuccess: onSuccess, openDraft: draft)),
      );
}

// Day Close Modal Widget
class DayCloseModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final OpenDraftModel? openDraft;
  final String? pendingBusinessDate;
  final int? pendingOpeningTransactionId;
  final int? pendingClosingTransactionId;

  const DayCloseModal({
    super.key,
    required this.onSuccess,
    this.openDraft,
    this.pendingBusinessDate,
    this.pendingOpeningTransactionId,
    this.pendingClosingTransactionId,
  });

  @override
  State<DayCloseModal> createState() => _DayCloseModalState();
}

class _DayCloseModalState extends State<DayCloseModal> {
  bool isLoadingSummary = true;
  bool isSubmitting = false;
  DailySalesCloseSummary? summary;
  String? errorMessage;
  int _currentStep = 0; // 0 = Cash Closing form, 1 = Confirm Close
  final TextEditingController _businessDateController = TextEditingController();
  final TextEditingController _shiftNameController = TextEditingController();
  final TextEditingController _openingTimeController = TextEditingController();
  final TextEditingController _closingTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _cashRefundsController = TextEditingController();
  final TextEditingController _cashDropAmountController =
      TextEditingController();
  final TextEditingController _openingCashInHandController =
      TextEditingController();
  final TextEditingController _closingCashInHandController =
      TextEditingController();
  final List<TextEditingController> _openingDenominationControllers = [];
  final List<TextEditingController> _openingCountControllers = [];
  final List<TextEditingController> _closingDenominationControllers = [];
  final List<TextEditingController> _closingCountControllers = [];
  final ScrollController _scrollController = ScrollController();

  List<MasterDataValue> _cashDenominations = [];
  bool _isLoadingDenominations = true;
  bool _openingPrefilled = false;

  double _expenseCash = 0.0;
  double _expenseBank = 0.0;
  double _expenseTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
    _fetchDenominations();
    _ensureBreakdownRows();
    if (widget.openDraft != null) {
      _prefillFromOpenDraft(widget.openDraft!);
    }
  }

  Future<void> _fetchDenominations() async {
    try {
      final masterDataProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );
      final result = await masterDataProvider.fetchCashDenominations();
      if (mounted) {
        setState(() {
          _cashDenominations = result ?? [];
          _isLoadingDenominations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDenominations = false;
        });
      }
    }
  }

  void _ensureBreakdownRows() {
    if (_openingDenominationControllers.isEmpty) {
      _addOpeningBreakdownRow();
    }
    if (_closingDenominationControllers.isEmpty) {
      _addClosingBreakdownRow();
    }
  }

  void _prefillFromOpenDraft(OpenDraftModel draft) {
    _shiftNameController.text = draft.shiftName ?? '';
    if (draft.openingTime != null && draft.openingTime!.isNotEmpty) {
      _openingTimeController.text = draft.openingTime!;
    }
    final cashSummary = draft.cashSummary;
    if (cashSummary == null) return;

    _openingCashInHandController.text = cashSummary.openingCashInHand ?? '';

    if (cashSummary.openingCashBreakdown != null &&
        cashSummary.openingCashBreakdown!.isNotEmpty) {
      _openingDenominationControllers.clear();
      _openingCountControllers.clear();
      for (final item in cashSummary.openingCashBreakdown!) {
        _addOpeningBreakdownRow(
          denomination: item['denomination']?.toString() ?? '',
          count: item['count']?.toString() ?? '',
        );
      }
    }
    setState(() {
      _openingPrefilled = true;
    });
  }

  void _addOpeningBreakdownRow({String denomination = '', String count = ''}) {
    _openingDenominationControllers.add(
      TextEditingController(text: denomination),
    );
    _openingCountControllers.add(TextEditingController(text: count));
  }

  void _addClosingBreakdownRow({String denomination = '', String count = ''}) {
    _closingDenominationControllers.add(
      TextEditingController(text: denomination),
    );
    _closingCountControllers.add(TextEditingController(text: count));
  }

  void _recalculateClosingCash() {
    double total = 0.0;
    for (var i = 0; i < _closingDenominationControllers.length; i++) {
      final denomText = _closingDenominationControllers[i].text.trim();
      final countText = _closingCountControllers[i].text.trim();
      final denomVal = double.tryParse(denomText) ?? 0.0;
      final countVal = double.tryParse(countText) ?? 0.0;
      total += denomVal * countVal;
    }
    final totalStr = total == 0.0
        ? ''
        : total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    if (_closingCashInHandController.text != totalStr) {
      _closingCashInHandController.text = totalStr;
    }
  }

  List<Map<String, dynamic>> _buildBreakdownPayload(
    List<TextEditingController> denominationControllers,
    List<TextEditingController> countControllers,
  ) {
    final breakdown = <Map<String, dynamic>>[];
    for (var index = 0; index < denominationControllers.length; index++) {
      final denomination = denominationControllers[index].text.trim();
      final countText = countControllers[index].text.trim();
      if (denomination.isEmpty && countText.isEmpty) {
        continue;
      }
      breakdown.add({
        'denomination': denomination,
        'count': int.tryParse(countText) ?? 0,
      });
    }
    return breakdown;
  }

  // Mirrors the same controller-vs-summary fallback used in _submitDayClose,
  // so the Confirm Close preview always matches what will actually be sent.
  num get _liveOpeningCashInHand =>
      num.tryParse(_openingCashInHandController.text.trim()) ??
      summary?.openingCashInHand ??
      0;

  num get _liveCashRefunds =>
      num.tryParse(_cashRefundsController.text.trim()) ??
      summary?.cashRefunds ??
      0;

  num get _liveCashDropAmount =>
      num.tryParse(_cashDropAmountController.text.trim()) ??
      summary?.cashDropAmount ??
      0;

  num get _cashSales =>
      num.tryParse((summary?.cashSales ?? '0').replaceAll(',', '')) ?? 0;

  num get _cashExpensesForFormula => summary?.cashExpenses ?? 0;

  // expected_closing_cash = opening_cash_in_hand + cash_sales
  //     - cash_refunds - cash_expenses - cash_drop_amount
  // (confirmed against the live daily-sales-close API response)
  num get _expectedClosingCash =>
      _liveOpeningCashInHand +
      _cashSales -
      _liveCashRefunds -
      _cashExpensesForFormula -
      _liveCashDropAmount;

  num get _todayCashCollection => _expectedClosingCash - _liveOpeningCashInHand;

  @override
  void dispose() {
    _businessDateController.dispose();
    _shiftNameController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _notesController.dispose();
    _cashRefundsController.dispose();
    _cashDropAmountController.dispose();
    _openingCashInHandController.dispose();
    _closingCashInHandController.dispose();
    _scrollController.dispose();
    for (final controller in _openingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in _openingCountControllers) {
      controller.dispose();
    }
    for (final controller in _closingDenominationControllers) {
      controller.dispose();
    }
    for (final controller in _closingCountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      isLoadingSummary = true;
      errorMessage = null;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession = Provider.of<StoreSessionProvider>(
        context,
        listen: false,
      );
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;

      final result = await salesProvider.fetchDailySalesCloseSummary(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        businessDate: widget.pendingBusinessDate,
      );

      if (!mounted) return;

      setState(() {
        summary = result;
        _businessDateController.text =
            widget.pendingBusinessDate ?? result?.businessDate ?? '';
        _expenseCash = (result?.cashExpenses ?? 0).toDouble();
        _expenseBank = (result?.bankExpenses ?? 0).toDouble();
        _expenseTotal = (result?.totalExpenses ?? 0).toDouble();
        if (!_openingPrefilled) {
          _shiftNameController.text = result?.shiftName ?? '';
        }

        // Opening Time: always fill from summary if still empty
        // (widget.openingTime from pending-status can be null)
        if (_openingTimeController.text.isEmpty) {
          final storeOpenTime = storeSession.activeStore?.storeOpenTime;
          final fallbackTime = storeOpenTime ?? '08:00:00';
          final hasActiveShift = widget.openDraft != null;
          _openingTimeController.text =
              (hasActiveShift &&
                  result?.openingTime != null &&
                  result!.openingTime!.isNotEmpty)
              ? result.openingTime!
              : fallbackTime;
        }
        _closingTimeController.text = '';
        _notesController.text = result?.notes ?? '';
        _cashRefundsController.text = result?.cashRefunds?.toString() ?? '';
        _cashDropAmountController.text =
            result?.cashDropAmount?.toString() ?? '';
        if (!_openingPrefilled) {
          _openingCashInHandController.text =
              result?.openingCashInHand?.toString() ?? '';
          // Populate opening breakdown from summary if available
          if (result?.openingCashBreakdown != null &&
              result!.openingCashBreakdown!.isNotEmpty) {
            _openingDenominationControllers.clear();
            _openingCountControllers.clear();
            for (final item in result.openingCashBreakdown!) {
              _addOpeningBreakdownRow(
                denomination: item['denomination']?.toString() ?? '',
                count: item['count']?.toString() ?? '',
              );
            }
          }
        }
        _closingCashInHandController.text =
            result?.closingCashInHand?.toString() ?? '';
        isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoadingSummary = false;
      });
    }
  }

  Future<void> _fetchExpenses() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final storeSession = Provider.of<StoreSessionProvider>(
        context,
        listen: false,
      );
      final expenseProvider = Provider.of<ExpenseProvider>(
        context,
        listen: false,
      );

      final storeId = storeSession.activeStore?.storeId ?? 0;
      final businessDate =
          widget.pendingBusinessDate ?? _businessDateController.text;

      final result = await expenseProvider.getExpenseBreakdownForDate(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        businessDate: businessDate,
      );

      if (!mounted) return;

      setState(() {
        _expenseCash = result['cash'] ?? 0.0;
        _expenseBank = result['bank'] ?? 0.0;
        _expenseTotal = result['total'] ?? 0.0;
      });
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
    }
  }

  Future<void> _submitDayClose() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final appSettings = Provider.of<AppSettingsProvider>(
        context,
        listen: false,
      ).appSettings;
      final storeSession = Provider.of<StoreSessionProvider>(
        context,
        listen: false,
      );
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final storeId = storeSession.activeStore?.storeId ?? 0;
      debugPrint('=== DAY CLOSE OPENING CHECK DEBUG START ===');
      debugPrint('storeId: $storeId');
      debugPrint('raw summary.openingTime: ${summary?.openingTime}');
      debugPrint('raw summary.closingTime: ${summary?.closingTime}');
      debugPrint(
        'controller openingTime text: "${_openingTimeController.text}"',
      );
      debugPrint(
        'controller closingTime text: "${_closingTimeController.text}"',
      );
      debugPrint(
        'controller businessDate text: "${_businessDateController.text}"',
      );
      debugPrint('controller shiftName text: "${_shiftNameController.text}"');
      debugPrint('controller notes text: "${_notesController.text}"');
      debugPrint('appSettings is null: ${appSettings == null}');
      debugPrint('appSettings.workingTime: "${appSettings?.workingTime}"');

      final workingTimeText = appSettings?.workingTime ?? '';
      debugPrint('workingTimeText length: ${workingTimeText.length}');
      final workingStartTime = _extractWorkingStartTime(workingTimeText);
      debugPrint('parsed workingStartTime: "$workingStartTime"');

      final openingTimeText = _openingTimeController.text.trim().isEmpty
          ? summary?.openingTime
          : _openingTimeController.text.trim();
      debugPrint('final openingTimeText for validation: "$openingTimeText"');

      debugPrint('=== DEBUG: createDailySalesClose CALLER CONTEXT ===');
      debugPrint('store_id: $storeId');
      debugPrint('Summary opening_time: ${summary?.openingTime}');
      debugPrint('Summary closing_time: ${summary?.closingTime}');
      debugPrint('Summary opening_date: ${summary?.openingDate}');
      debugPrint('Summary closing_date: ${summary?.closingDate}');
      debugPrint('selected shift_name: ${_shiftNameController.text.trim()}');
      debugPrint(
        'selected business_date: ${_businessDateController.text.trim()}',
      );
      debugPrint(
        'selected opening_time: ${_openingTimeController.text.trim()}',
      );
      debugPrint(
        'selected closing_time: ${_closingTimeController.text.trim()}',
      );
      debugPrint(
        'selected cash_refunds: ${_cashRefundsController.text.trim()}',
      );
      debugPrint(
        'selected cash_drop_amount: ${_cashDropAmountController.text.trim()}',
      );
      debugPrint(
        'selected opening_cash_in_hand: ${_openingCashInHandController.text.trim()}',
      );
      debugPrint(
        'selected closing_cash_in_hand: ${_closingCashInHandController.text.trim()}',
      );
      debugPrint(
        'opening breakdown rows: ${_openingDenominationControllers.length}',
      );
      for (var i = 0; i < _openingDenominationControllers.length; i++) {
        debugPrint(
          'opening row $i => denom="${_openingDenominationControllers[i].text}" count="${_openingCountControllers[i].text}"',
        );
      }
      debugPrint(
        'closing breakdown rows: ${_closingDenominationControllers.length}',
      );
      for (var i = 0; i < _closingDenominationControllers.length; i++) {
        debugPrint(
          'closing row $i => denom="${_closingDenominationControllers[i].text}" count="${_closingCountControllers[i].text}"',
        );
      }

      final result = await salesProvider.createDailySalesClose(
        accessToken: authModel.token ?? '',
        storeId: storeId,
        shiftName: _shiftNameController.text.trim().isEmpty
            ? summary?.shiftName
            : _shiftNameController.text.trim(),
        businessDate: _businessDateController.text.trim().isEmpty
            ? summary?.businessDate
            : _businessDateController.text.trim(),
        openingDate: summary?.openingDate,
        openingTime: _openingTimeController.text.trim().isEmpty
            ? summary?.openingTime
            : _openingTimeController.text.trim(),
        closingDate: summary?.closingDate,
        closingTime: _closingTimeController.text.trim().isEmpty
            ? summary?.closingTime
            : _closingTimeController.text.trim(),
        cashRefunds:
            num.tryParse(_cashRefundsController.text.trim()) ??
            summary?.cashRefunds,
        cashExpenses: summary?.cashExpenses,
        cashDropAmount:
            num.tryParse(_cashDropAmountController.text.trim()) ??
            summary?.cashDropAmount,
        openingCashInHand:
            num.tryParse(_openingCashInHandController.text.trim()) ??
            summary?.openingCashInHand,
        openingCashBreakdown: _buildBreakdownPayload(
          _openingDenominationControllers,
          _openingCountControllers,
        ),
        closingCashInHand:
            num.tryParse(_closingCashInHandController.text.trim()) ??
            summary?.closingCashInHand,
        closingCashBreakdown: _buildBreakdownPayload(
          _closingDenominationControllers,
          _closingCountControllers,
        ),
        notes: _notesController.text.trim().isEmpty
            ? summary?.notes
            : _notesController.text.trim(),
        openingTransactionId: widget.pendingOpeningTransactionId,
        closingTransactionId: widget.pendingClosingTransactionId,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          showScaffold(
            context: context,
            message:
                result['message'] ??
                'daily_sales_close.msg_day_close_created'.tr,
          );
          widget.onSuccess();
        }
      } else {
        debugPrint('DAY CLOSE RESULT FAILURE: ${result['message']}');
        if (mounted) {
          String errorMessage =
              result['message'] ?? 'Failed to create day close';
          final errors = result['errors'];
          if (errors != null && errors is Map) {
            final errorDetails = errors.values
                .expand((e) => e is List ? e : [e])
                .join('\n');
            if (errorDetails.isNotEmpty) {
              errorMessage = '$errorMessage:\n$errorDetails';
            }
          }

          showScaffoldError(context: context, message: errorMessage);
        }
      }
    } catch (e) {
      debugPrint('=== DAY CLOSE SUBMIT EXCEPTION ===');
      debugPrint('error: $e');
      if (mounted) {
        showScaffoldError(context: context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
      debugPrint('=== DAY CLOSE OPENING CHECK DEBUG END ===');
    }
  }

  Widget _buildSummaryCard(
    String label,
    String value, {
    Color? color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.18,
                  Colors.grey.shade500,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s16,
              0.18,
              color ?? ColorManager.kTitleTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryRow(
    String label1,
    String value1,
    String label2,
    String value2, {
    Color? color1,
    Color? color2,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            children: [
              _buildSmallSummaryItem(label1, value1, color: color1),
              const SizedBox(height: 10),
              _buildSmallSummaryItem(label2, value2, color: color2),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSmallSummaryItem(label1, value1, color: color1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallSummaryItem(label2, value2, color: color2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallSummaryItem(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.18,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              color ?? ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.18,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.18,
              ColorManager.kTitleTextColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              enabled
                  ? ColorManager.textColor
                  : ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: CalendarPickerTableCell(
            initialDate: _parseDate(controller.text) ?? DateTime.now(),
            onDateSelected: (picked) {
              setState(() {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnRow({
    required bool isNarrow,
    required Widget left,
    required Widget right,
  }) {
    if (isNarrow) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String? _extractWorkingStartTime(String workingTime) {
    final match = RegExp(
      r'(\d{2}:\d{2})(?::\d{2})?\s*-\s*\d{2}:\d{2}',
    ).firstMatch(workingTime);
    return match?.group(1);
  }

  TimeOfDay? _parseTimeOfDay(String timeValue) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timeValue);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeBefore(TimeOfDay a, String b) {
    final parsedB = _parseTimeOfDay(b);
    if (parsedB == null) return false;
    return a.hour < parsedB.hour ||
        (a.hour == parsedB.hour && a.minute < parsedB.minute);
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          height: 42,
          width: double.infinity,
          child: readOnly
              ? TextFormField(
                  controller: controller,
                  enabled: false,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                )
              : TimePickerTableCell(
                  initialTime: _parseTimeOfDay(controller.text),
                  onTimeSelected: (picked) {
                    setState(() {
                      controller.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                    });
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required TextEditingController controller,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12, top: 6, right: 10),
          height: maxLines > 1 ? 92 : 42,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required List<TextEditingController> denominationControllers,
    required List<TextEditingController> countControllers,
    required bool isNarrow,
    required VoidCallback onAddRow,
    bool isReadOnly = false,
    ValueChanged<String?>? onDenominationChanged,
    ValueChanged<String>? onCountChanged,
    VoidCallback? onRowRemoved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                Colors.grey.shade800,
              ),
            ),
            if (!isReadOnly)
              TextButton(
                onPressed: onAddRow,
                child: Text('daily_sales_close.add_row'.tr),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(denominationControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDenominationRow(
                        denominationController: denominationControllers[index],
                        countController: countControllers[index],
                        isNarrow: true,
                        allDenominationControllers: denominationControllers,
                        index: index,
                        isReadOnly: isReadOnly,
                        onDenominationChanged: onDenominationChanged,
                        onCountChanged: onCountChanged,
                      ),
                      const SizedBox(height: 4),
                      if (!isReadOnly)
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'daily_sales_close.remove_row'.tr,
                              onPressed: denominationControllers.length == 1
                                  ? null
                                  : () {
                                      setState(() {
                                        denominationControllers[index]
                                            .dispose();
                                        countControllers[index].dispose();
                                        denominationControllers.removeAt(index);
                                        countControllers.removeAt(index);
                                      });
                                      if (onRowRemoved != null) {
                                        onRowRemoved();
                                      }
                                    },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDenominationRow(
                          denominationController:
                              denominationControllers[index],
                          countController: countControllers[index],
                          isNarrow: false,
                          allDenominationControllers: denominationControllers,
                          index: index,
                          isReadOnly: isReadOnly,
                          onDenominationChanged: onDenominationChanged,
                          onCountChanged: onCountChanged,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isReadOnly)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'daily_sales_close.remove_row'.tr,
                            onPressed: denominationControllers.length == 1
                                ? null
                                : () {
                                    setState(() {
                                      denominationControllers[index].dispose();
                                      countControllers[index].dispose();
                                      denominationControllers.removeAt(index);
                                      countControllers.removeAt(index);
                                    });
                                    if (onRowRemoved != null) {
                                      onRowRemoved();
                                    }
                                  },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildDenominationRow({
    required TextEditingController denominationController,
    required TextEditingController countController,
    required bool isNarrow,
    required List<TextEditingController> allDenominationControllers,
    required int index,
    bool isReadOnly = false,
    ValueChanged<String?>? onDenominationChanged,
    ValueChanged<String>? onCountChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNarrow
            ? Column(
                children: [
                  _buildDenominationDropdown(
                    controller: denominationController,
                    allDenominationControllers: allDenominationControllers,
                    index: index,
                    isReadOnly: isReadOnly,
                    onChanged: onDenominationChanged,
                  ),
                  const SizedBox(height: 6),
                  _buildCompactField(
                    label: 'daily_sales_close.count'.tr,
                    controller: countController,
                    keyboardType: TextInputType.number,
                    enabled: !isReadOnly,
                    onChanged: onCountChanged,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildDenominationDropdown(
                      controller: denominationController,
                      allDenominationControllers: allDenominationControllers,
                      index: index,
                      isReadOnly: isReadOnly,
                      onChanged: onDenominationChanged,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildCompactField(
                      label: 'daily_sales_close.count'.tr,
                      controller: countController,
                      keyboardType: TextInputType.number,
                      enabled: !isReadOnly,
                      onChanged: onCountChanged,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildDenominationDropdown({
    required TextEditingController controller,
    required List<TextEditingController> allDenominationControllers,
    required int index,
    bool isReadOnly = false,
    ValueChanged<String?>? onChanged,
  }) {
    final currentValue = controller.text.trim().isEmpty
        ? null
        : controller.text.trim();
    final hasMatch = _cashDenominations.any((d) => d.value == currentValue);
    final selectedValue = hasMatch ? currentValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'daily_sales_close.denomination'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          width: double.infinity,
          child: _isLoadingDenominations
              ? const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: selectedValue,
                    disabledHint: selectedValue != null
                        ? Text(
                            _cashDenominations
                                .firstWhere(
                                  (d) => d.value == selectedValue,
                                  orElse: () => MasterDataValue(
                                    id: 0,
                                    value: selectedValue,
                                    description: selectedValue,
                                  ),
                                )
                                .description,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s10,
                              0.20,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          )
                        : null,
                    hint: Text(
                      'daily_sales_close.select'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.20,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    items: _cashDenominations
                        .where((d) {
                          // Get all currently selected denominations
                          // except the current row's own selection
                          final selectedOthers = allDenominationControllers
                              .asMap()
                              .entries
                              .where((e) => e.key != index)
                              .map((e) => e.value.text.trim())
                              .toSet();
                          // Allow this denomination if not selected
                          // in any other row, or if it's empty
                          return !selectedOthers.contains(d.value ?? '');
                        })
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d.value,
                            child: Text(
                              d.description.isNotEmpty
                                  ? d.description
                                  : d.value,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.20,
                                isReadOnly
                                    ? ColorManager.textColor.withOpacity(.5)
                                    : ColorManager.textColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (value) {
                            setState(() {
                              controller.text = value ?? '';
                            });
                            if (onChanged != null) {
                              onChanged(value);
                            }
                          },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 36,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                  color: ColorManager.kPrimaryColor,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              hintText: '',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.20,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s10,
              0.20,
              enabled
                  ? ColorManager.textColor
                  : ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BuildBoxShadowContainer(
        circleRadius: 20,
        color: Colors.white,
        width: isMobile ? size.width * 0.98 : 760,
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            final maxHeight = size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentStep == 0
                                  ? 'daily_sales_close.btn_day_close'.tr
                                  : 'daily_sales_close.confirm_close'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.21,
                                ColorManager.kTitleTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentStep == 0
                                  ? 'daily_sales_close.day_close_subtitle'.tr
                                  : 'daily_sales_close.confirm_close_subtitle'
                                        .tr,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.18,
                                Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isLoadingSummary)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade400,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _fetchSummary,
                                      child: Text('restaurant.retry'.tr),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Consumer<AppSettingsProvider>(
                              builder: (context, appSettingsProvider, child) {
                                final currency =
                                    appSettingsProvider.appSettings?.currency ??
                                    'INR';
                                return _currentStep == 0
                                    ? _buildCashClosingStepContent(
                                        currency,
                                        isNarrow,
                                        constraints,
                                      )
                                    : _buildConfirmCloseStepContent(currency);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer buttons
                  _buildFooter(isNarrow),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCashClosingStepContent(
    String currency,
    bool isNarrow,
    BoxConstraints constraints,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Name & Store Info Section
        Text(
          'daily_sales_close.session_info'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.person_outline,
                'daily_sales_close.user'.tr,
                summary?.userName ?? '-',
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'daily_sales_close.opening'.tr,
                '${summary?.openingDate ?? '-'} ${'daily_sales_close.at'.tr} ${summary?.openingTime ?? '-'}',
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.event_available_outlined,
                'daily_sales_close.closing'.tr,
                '${summary?.closingDate ?? '-'} ${'daily_sales_close.at'.tr} ${summary?.closingTime ?? '-'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTwoColumnRow(
          isNarrow: isNarrow,
          left: _buildDateField(
            label: 'daily_sales_close.business_date'.tr,
            controller: _businessDateController,
          ),
          right: _buildAmountField(
            label: 'daily_sales_close.shift_name'.tr,
            controller: _shiftNameController,
            enabled: true,
          ),
        ),
        const SizedBox(height: 12),
        _buildTwoColumnRow(
          isNarrow: isNarrow,
          left: _buildTimePickerField(
            label: 'daily_sales_close.opening_time'.tr,
            controller: _openingTimeController,
          ),
          right: _buildTimePickerField(
            label: 'daily_sales_close.closing_time'.tr,
            controller: _closingTimeController,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'daily_sales_close.tx_overview'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Total Orders and Total Sales
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 12) / 2,
              child: _buildSummaryCard(
                'daily_sales_close.total_orders_cap'.tr,
                summary?.totalOrders?.toString() ?? '0',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            SizedBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 12) / 2,
              child: _buildSummaryCard(
                'daily_sales_close.total_sales_cap'.tr,
                '$currency ${summary?.totalSales ?? '0.00'}',
                color: ColorManager.kPrimaryColor,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Payment Received and Collected On Sale
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 12) / 2,
              child: _buildSummaryCard(
                'daily_sales_close.payment_received_cap'.tr,
                '$currency ${summary?.paymentReceived ?? '0.00'}',
                icon: Icons.check_circle_outline,
              ),
            ),
            SizedBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 12) / 2,
              child: _buildSummaryCard(
                'daily_sales_close.collected_on_sale_cap'.tr,
                '$currency ${summary?.collectedOnSale ?? '0.00'}',
                icon: Icons.monetization_on_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Small summary rows
        _buildSmallSummaryRow(
          'daily_sales_close.cash_sales_cap'.tr,
          '$currency ${summary?.cashSales ?? '0.00'}',
          'daily_sales_close.online_sales_cap'.tr,
          '$currency ${summary?.onlineSales ?? '0.00'}',
        ),
        const SizedBox(height: 10),
        _buildSmallSummaryRow(
          'daily_sales_close.credit_amount_cap'.tr,
          '$currency ${summary?.creditAmount ?? '0.00'}',
          'daily_sales_close.credit_collected_cap'.tr,
          '$currency ${summary?.creditCollected ?? '0.00'}',
        ),
        const SizedBox(height: 10),
        _buildSmallSummaryRow(
          'daily_sales_close.cash_expenses_cap'.tr,
          '$currency ${_expenseCash.toStringAsFixed(2)}',
          'daily_sales_close.bank_expenses_cap'.tr,
          '$currency ${_expenseBank.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 10),
        _buildSmallSummaryItem(
          'daily_sales_close.total_expense_cap'.tr,
          '$currency ${_expenseTotal.toStringAsFixed(2)}',
          color: Colors.red.shade700,
        ),
        const SizedBox(height: 16),

        Text(
          'daily_sales_close.cash_in_hand'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildAmountField(
          label: 'daily_sales_close.opening_cash_in_hand'.tr,
          controller: _openingCashInHandController,
          enabled: !_openingPrefilled,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildAmountField(
          label: 'daily_sales_close.closing_cash_in_hand'.tr,
          controller: _closingCashInHandController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Returns & Refunds Section
        Text(
          'daily_sales_close.returns_refunds'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildSmallSummaryRow(
          'daily_sales_close.total_returns_cap'.tr,
          '$currency ${summary?.totalReturns ?? '0.00'}',
          'daily_sales_close.total_refunds_cap'.tr,
          '$currency ${summary?.totalRefunds ?? '0.00'}',
          color1: Colors.red.shade600,
          color2: Colors.red.shade600,
        ),
        const SizedBox(height: 20),
        _buildBreakdownSection(
          title: 'daily_sales_close.opening_cash_breakdown'.tr,
          denominationControllers: _openingDenominationControllers,
          countControllers: _openingCountControllers,
          isNarrow: isNarrow,
          isReadOnly: _openingPrefilled,
          onAddRow: () {
            setState(() {
              _addOpeningBreakdownRow();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
        const SizedBox(height: 20),
        _buildBreakdownSection(
          title: 'daily_sales_close.closing_cash_breakdown'.tr,
          onDenominationChanged: (_) => _recalculateClosingCash(),
          onCountChanged: (_) => _recalculateClosingCash(),
          onRowRemoved: () => _recalculateClosingCash(),
          denominationControllers: _closingDenominationControllers,
          countControllers: _closingCountControllers,
          isNarrow: isNarrow,
          onAddRow: () {
            setState(() {
              _addClosingBreakdownRow();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
        const SizedBox(height: 12),
        _buildAmountField(
          label: 'daily_sales_close.cash_refunds'.tr,
          controller: _cashRefundsController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildAmountField(
          label: 'daily_sales_close.cash_drop_amount'.tr,
          controller: _cashDropAmountController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildTextAreaField(
          label: 'daily_sales_close.notes'.tr,
          controller: _notesController,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildConfirmCloseStepContent(String currency) {
    final expected = _expectedClosingCash;
    final todayCollection = _todayCashCollection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'daily_sales_close.cash_summary'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildConfirmSummaryRow(
                'daily_sales_close.expected_closing_cash'.tr,
                '$currency ${expected.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
              _buildConfirmSummaryRow(
                'daily_sales_close.today_cash_collection'.tr,
                '$currency ${todayCollection.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.18,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s13,
            0.18,
            ColorManager.kTitleTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isNarrow) {
    final bool onConfirmStep = _currentStep == 1;
    final String leftLabel = onConfirmStep
        ? 'daily_sales_close.back'.tr
        : 'daily_sales_close.cancel'.tr;
    final VoidCallback? leftOnPressed = isSubmitting
        ? null
        : onConfirmStep
        ? () => setState(() => _currentStep = 0)
        : () => Navigator.of(context).pop();

    final String rightLabel = onConfirmStep
        ? 'daily_sales_close.confirm_close_day'.tr
        : 'daily_sales_close.next'.tr;
    final bool rightDisabled =
        isSubmitting || isLoadingSummary || errorMessage != null;
    final VoidCallback? rightOnPressed = rightDisabled
        ? null
        : onConfirmStep
        ? _submitDayClose
        : () => setState(() => _currentStep = 1);

    final leftButton = TextButton(
      onPressed: leftOnPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.grey.shade100,
      ),
      child: Text(
        leftLabel,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s13,
          0.18,
          Colors.grey.shade700,
        ),
      ),
    );

    final rightButton = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ColorManager.kSuccessColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: rightOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.kSuccessColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSubmitting && onConfirmStep
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                rightLabel,
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s13,
                  0.18,
                  Colors.white,
                ),
              ),
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: leftButton),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: rightButton),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: leftButton),
        const SizedBox(width: 16),
        Expanded(child: rightButton),
      ],
    );
  }
}
