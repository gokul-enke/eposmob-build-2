import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class OpenShiftModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const OpenShiftModal({Key? key, required this.onSuccess}) : super(key: key);

  @override
  State<OpenShiftModal> createState() => _OpenShiftModalState();
}

class _OpenShiftModalState extends State<OpenShiftModal> {
  final TextEditingController _shiftNameController = TextEditingController(text: 'Shift');
  final TextEditingController _businessDateController = TextEditingController();
  final TextEditingController _openingTimeController = TextEditingController();
  final TextEditingController _openingCashInHandController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<TextEditingController> _denominationControllers = [];
  final List<TextEditingController> _countControllers = [];

  bool _isLoading = false;
  bool _isLoadingDenominations = true;
  String? _errorMessage;
  int? _selectedStoreId;
  String? _selectedStoreName;
  List<MasterDataValue> _cashDenominations = [];

  @override
  void initState() {
    super.initState();

    final storeSession = Provider.of<StoreSessionProvider>(context, listen: false);
    _selectedStoreId = storeSession.activeStore?.storeId;
    _selectedStoreName = storeSession.activeStore?.storeName;

    _businessDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _openingTimeController.text = DateFormat('HH:mm').format(DateTime.now()) + ':00';

    _fetchDenominations();
    _ensureBreakdownRows();
  }

  @override
  void dispose() {
    _shiftNameController.dispose();
    _businessDateController.dispose();
    _openingTimeController.dispose();
    _openingCashInHandController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    for (final c in _denominationControllers) {
      c.dispose();
    }
    for (final c in _countControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchDenominations() async {
    try {
      final masterDataProvider = Provider.of<MasterDataProvider>(context, listen: false);
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
    if (_denominationControllers.isEmpty) {
      _addBreakdownRow();
    }
  }

  void _addBreakdownRow({String denomination = '', String count = ''}) {
    _denominationControllers.add(TextEditingController(text: denomination));
    _countControllers.add(TextEditingController(text: count));
  }

  void _recalculateOpeningCash() {
    double total = 0.0;
    for (var i = 0; i < _denominationControllers.length; i++) {
      final denomText = _denominationControllers[i].text.trim();
      final countText = _countControllers[i].text.trim();
      final denomVal = double.tryParse(denomText) ?? 0.0;
      final countVal = double.tryParse(countText) ?? 0.0;
      total += denomVal * countVal;
    }
    final totalStr = total == 0.0 ? '' : total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    if (_openingCashInHandController.text != totalStr) {
      _openingCashInHandController.text = totalStr;
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeValue) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timeValue);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveOpeningDraft() async {
    if (_openingTimeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Opening Time is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final breakdown = <Map<String, dynamic>>[];
      for (var i = 0; i < _denominationControllers.length; i++) {
        final denom = _denominationControllers[i].text.trim();
        final countTxt = _countControllers[i].text.trim();
        if (denom.isEmpty && countTxt.isEmpty) continue;
        breakdown.add({
          'denomination': denom,
          'count': int.tryParse(countTxt) ?? 0,
        });
      }

      debugPrint('=== OPEN SHIFT SUBMIT ===');
      debugPrint('storeId being sent: $_selectedStoreId');
      debugPrint('storeName: $_selectedStoreName');

      final success = await salesProvider.openShiftApi(
        accessToken: authModel.token ?? '',
        storeId: _selectedStoreId ?? 0,
        shiftName: _shiftNameController.text.trim(),
        businessDate: _businessDateController.text.trim(),
        openingDate: _businessDateController.text.trim(),
        openingTime: _openingTimeController.text.trim(),
        openingCashInHand: double.tryParse(_openingCashInHandController.text.trim()) ?? 0.0,
        openingCashBreakdown: breakdown,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift opened successfully')),
          );
          Navigator.of(context).pop();
          widget.onSuccess();
        } else {
          setState(() {
            _errorMessage = 'Failed to open shift. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
        .appSettings?.currency ?? 'SAR';

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
                mainAxisSize: MainAxisSize.min,
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
                              'Open Shift',
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.21,
                                ColorManager.kTitleTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Capture opening time and opening cash before starting sales.',
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
                      IconButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Form Area
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Name (disabled)
                          _buildDisabledStoreField(),
                          const SizedBox(height: 12),
                          // Shift Name & Business Date
                          _buildTwoColumnRow(
                            isNarrow: isNarrow,
                            left: _buildAmountField(
                              label: 'Shift Name',
                              controller: _shiftNameController,
                            ),
                            right: _buildDateField(
                              label: 'Business Date',
                              controller: _businessDateController,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Opening Time & Opening Cash
                          _buildTwoColumnRow(
                            isNarrow: isNarrow,
                            left: _buildTimePickerField(
                              label: 'Opening Time*',
                              controller: _openingTimeController,
                            ),
                            right: _buildAmountField(
                              label: 'Opening Cash Balance ($currency)',
                              controller: _openingCashInHandController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Breakdown Section
                          _buildBreakdownSection(
                            title: 'Opening Cash Breakdown',
                            denominationControllers: _denominationControllers,
                            countControllers: _countControllers,
                            isNarrow: isNarrow,
                            onAddRow: () {
                              setState(() {
                                _addBreakdownRow();
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
                          // Notes
                          _buildTextAreaField(
                            label: 'Notes',
                            controller: _notesController,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // Error message
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _errorMessage!,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s11,
                          0.18,
                          Colors.red,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Footer Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.grey.shade100,
                        ),
                        child: Text(
                          'Cancel',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s12,
                            0.18,
                            Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveOpeningDraft,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Opening Draft',
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDisabledStoreField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store',
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
            initialValue: _selectedStoreName ?? '-',
            enabled: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
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

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
            keyboardType: keyboardType,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
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

  Widget _buildTimePickerField({
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
          child: TimePickerTableCell(
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
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
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
            TextButton(
              onPressed: onAddRow,
              child: const Text('Add Row'),
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
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove row',
                            onPressed: denominationControllers.length == 1
                                ? null
                                : () {
                                    setState(() {
                                      denominationControllers[index].dispose();
                                      countControllers[index].dispose();
                                      denominationControllers.removeAt(index);
                                      countControllers.removeAt(index);
                                      _recalculateOpeningCash();
                                    });
                                  },
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDenominationRow(
                          denominationController: denominationControllers[index],
                          countController: countControllers[index],
                          isNarrow: false,
                          allDenominationControllers: denominationControllers,
                          index: index,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Remove row',
                          onPressed: denominationControllers.length == 1
                              ? null
                              : () {
                                  setState(() {
                                    denominationControllers[index].dispose();
                                    countControllers[index].dispose();
                                    denominationControllers.removeAt(index);
                                    countControllers.removeAt(index);
                                    _recalculateOpeningCash();
                                  });
                                },
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18, color: Colors.red),
                        ),
                      ),
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
                  ),
                  const SizedBox(height: 6),
                  _buildCompactField(
                    label: 'Count',
                    controller: countController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculateOpeningCash(),
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
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildCompactField(
                      label: 'Count',
                      controller: countController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalculateOpeningCash(),
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
  }) {
    final currentValue = controller.text.trim().isEmpty ? null : controller.text.trim();
    final hasMatch = _cashDenominations.any((d) => d.value == currentValue);
    final selectedValue = hasMatch ? currentValue : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Denomination',
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
                    hint: Text(
                      'Select',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s10,
                        0.20,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    items: _cashDenominations
                        .where((d) {
                          final selectedOthers = allDenominationControllers
                              .asMap()
                              .entries
                              .where((e) => e.key != index)
                              .map((e) => e.value.text.trim())
                              .toSet();
                          return !selectedOthers.contains(d.value ?? '');
                        })
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d.value,
                            child: Text(
                              d.description.isNotEmpty ? d.description : (d.value ?? ''),
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.20,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        controller.text = value ?? '';
                        _recalculateOpeningCash();
                      });
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
            onChanged: onChanged,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
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
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
