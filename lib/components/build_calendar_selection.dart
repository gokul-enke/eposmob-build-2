import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CalendarPickerTableCell extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? hintText;
  final bool showQuickActions;
  final bool isRequired;
  final bool isForExpiry;

  const CalendarPickerTableCell({
    Key? key, 
    required this.onDateSelected, 
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.hintText,
    this.showQuickActions = false,
    this.isRequired = false,
    this.isForExpiry = false,
  }) : super(key: key);

  @override
  _CalendarPickerTableCellState createState() =>
      _CalendarPickerTableCellState();
}

// Date input formatter that automatically adds hyphens
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 8 digits (YYYYMMDD)
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }
    
    String formatted = '';
    
    // Format as YYYY-MM-DD
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 4 || i == 6) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CalendarPickerTableCellState extends State<CalendarPickerTableCell> {
  DateTime? selectedDate;
  bool isTextInputMode = false;
  late TextEditingController textController;
  final FocusNode textFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    textController = TextEditingController();
    if (selectedDate != null) {
      textController.text = DateFormat('yyyy-MM-dd').format(selectedDate!);
    }
    
    // Add listener for real-time validation on focus loss
    textFocusNode.addListener(() {
      if (!textFocusNode.hasFocus && textController.text.isNotEmpty) {
        // Validate when user loses focus
        _handleTextInput(textController.text);
      }
    });
    
    // Add listener for text changes with debouncing
    textController.addListener(() {
      if (isTextInputMode && textController.text.isNotEmpty) {
        // Cancel previous timer
        _debounceTimer?.cancel();
        
        // Set new timer for delayed validation
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (textController.text.isNotEmpty && textController.text.length >= 8) {
            _handleTextInput(textController.text);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    textController.dispose();
    textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = widget.initialDate ?? selectedDate ?? DateTime.now();
    final DateTime firstDate = widget.firstDate ?? DateTime(2000);
    final DateTime lastDate = widget.lastDate ?? DateTime(2101);
    
    // Show quick actions dialog if enabled and for expiry dates
    if (widget.showQuickActions && widget.isForExpiry) {
      final result = await _showQuickDateSelector(context);
      if (result != null) {
        _updateSelectedDate(result);
        return;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate :
                  initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ColorManager.kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: ColorManager.textColor,
              surface: Colors.white,
              background: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            canvasColor: Colors.white,
            cardColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor,
                backgroundColor: Colors.white,
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              headerBackgroundColor: ColorManager.kPrimaryColor,
              headerForegroundColor: Colors.white,
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return ColorManager.kPrimaryColor;
                }
                return Colors.white;
              }),
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return ColorManager.textColor;
              }),
              dividerColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      _updateSelectedDate(picked);
    }
  }

  void _updateSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      textController.text = DateFormat('yyyy-MM-dd').format(date);
      isTextInputMode = false; // Switch back to display mode
    });
    widget.onDateSelected(date);
  }

  void _handleTextInput(String value) {
    if (value.isEmpty) return;
    
    try {
      DateTime? parsedDate;
      String cleanValue = value.replaceAll(RegExp(r'[^\d]'), ''); // Remove all non-digits
      
      // Handle different input lengths
      if (cleanValue.length == 8) {
        // Format: YYYYMMDD -> YYYY-MM-DD
        String year = cleanValue.substring(0, 4);
        String month = cleanValue.substring(4, 6);
        String day = cleanValue.substring(6, 8);
        parsedDate = DateTime(int.parse(year), int.parse(month), int.parse(day));
      }
      else if (cleanValue.length == 6) {
        // Format: DDMMYY -> DD-MM-20YY (assuming 20xx for 2-digit years)
        String day = cleanValue.substring(0, 2);
        String month = cleanValue.substring(2, 4);
        String year = '20${cleanValue.substring(4, 6)}';
        parsedDate = DateTime(int.parse(year), int.parse(month), int.parse(day));
      }
      else if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        // Format: yyyy-MM-dd (already formatted)
        parsedDate = DateTime.parse(value);
      }
      else if (RegExp(r'^\d{2}[-/]\d{2}[-/]\d{4}$').hasMatch(value)) {
        // Format: dd-MM-yyyy or dd/MM/yyyy
        final parts = value.split(RegExp(r'[-/]'));
        parsedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      else if (RegExp(r'^\d{1,2}[-/]\d{1,2}[-/]\d{4}$').hasMatch(value)) {
        // Format: d-M-yyyy or d/M/yyyy (single digits allowed)
        final parts = value.split(RegExp(r'[-/]'));
        parsedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      
      if (parsedDate != null) {
        // Validate against date restrictions
        final firstDate = widget.firstDate ?? DateTime(2000);
        final lastDate = widget.lastDate ?? DateTime(2101);
        
        if (parsedDate.isBefore(firstDate) || parsedDate.isAfter(lastDate)) {
          _showDateValidationError('Date must be between ${DateFormat('MMM dd, yyyy').format(firstDate)} and ${DateFormat('MMM dd, yyyy').format(lastDate)}');
          return;
        }
        
        setState(() {
          selectedDate = parsedDate;
          isTextInputMode = false;
        });
        widget.onDateSelected(parsedDate);
      } else {
        _showDateValidationError('Invalid date. Try: 20250205 or 2025-02-05 or 05-02-2025');
      }
    } catch (e) {
      _showDateValidationError('Invalid date. Try: 20250205 or 2025-02-05 or 05-02-2025');
    }
  }

  void _onTextChanged(String value) {
    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // Don't validate empty or very short inputs
    if (value.isEmpty || value.length < 4) return;
    
    // Set a timer for validation after user stops typing
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (value.isNotEmpty && value.length >= 8) {
        _handleTextInput(value);
      }
    });
  }

  void _showDateValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleInputMode() {
    setState(() {
      isTextInputMode = !isTextInputMode;
      if (isTextInputMode) {
        // Focus on text input when switching to text mode
        Future.delayed(const Duration(milliseconds: 100), () {
          textFocusNode.requestFocus();
          textController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: textController.text.length,
          );
        });
      }
    });
  }

  Future<DateTime?> _showQuickDateSelector(BuildContext context) async {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Quick Date Selection',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          content: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuickDateButton('1 Week', DateTime.now().add(const Duration(days: 7))),
                _buildQuickDateButton('1 Month', DateTime.now().add(const Duration(days: 30))),
                _buildQuickDateButton('3 Months', DateTime.now().add(const Duration(days: 90))),
                _buildQuickDateButton('6 Months', DateTime.now().add(const Duration(days: 180))),
                _buildQuickDateButton('1 Year', DateTime.now().add(const Duration(days: 365))),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.calendar_today,
                      color: ColorManager.textColor.withOpacity(.5),
                      size: 18,
                    ),
                    label: Text(
                      'Custom Date',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: ColorManager.textColor.withOpacity(.5),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickDateButton(String label, DateTime date) {
    final firstDate = widget.firstDate ?? DateTime(2000);
    final lastDate = widget.lastDate ?? DateTime(2101);
    final isEnabled = !date.isBefore(firstDate) && !date.isAfter(lastDate);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.withOpacity(0.3), // Consistent subtle border
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: isEnabled ? () => Navigator.of(context).pop(date) : null,
        style: TextButton.styleFrom(
          foregroundColor: isEnabled ? ColorManager.textColor.withOpacity(.5) : Colors.grey,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                isEnabled ? ColorManager.textColor.withOpacity(.5) : Colors.grey.shade400,
              ),
            ),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                isEnabled ? ColorManager.textColor.withOpacity(.5) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final date = selectedDate ?? widget.initialDate;
    if (date == null) {
      return widget.hintText ?? 'Select Date';
    }
    
    // Always use consistent format: MMM dd, yyyy
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null || widget.initialDate != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white, // Always white background like other fields
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Calendar icon - click to show calendar picker
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date display/text input area
          Expanded(
            child: isTextInputMode
              ? TextFormField(
                  controller: textController,
                  focusNode: textFocusNode,
                  inputFormatters: [DateInputFormatter()],
                  decoration: InputDecoration(
                    hintText: 'Type: 20250205',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
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
                  onFieldSubmitted: _handleTextInput,
                  onChanged: _onTextChanged,
                  keyboardType: TextInputType.number,
                )
              : GestureDetector(
                  onTap: _toggleInputMode,
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _getFormattedDate(),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ),
          // Mode toggle icon (edit icon for text input)
          if (!isTextInputMode)
            InkWell(
              onTap: _toggleInputMode,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          // Close icon when in text input mode
          if (isTextInputMode)
            InkWell(
              onTap: _toggleInputMode,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          // Required indicator
          if (widget.isRequired && !hasDate)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TimePickerTableCell extends StatefulWidget {
  final Function(TimeOfDay) onTimeSelected;
  final TimeOfDay? initialTime;

  const TimePickerTableCell({
    Key? key,
    required this.onTimeSelected,
    this.initialTime,
  }) : super(key: key);

  @override
  _TimePickerTableCellState createState() => _TimePickerTableCellState();
}

class _TimePickerTableCellState extends State<TimePickerTableCell> {
  TimeOfDay? selectedTime;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.initialTime ?? selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
      widget.onTimeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectTime(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          border: InputBorder.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              selectedTime != null
                  ? selectedTime!.format(context)
                  : widget.initialTime != null
                      ? widget.initialTime!.format(context)
                      : 'Select Time',
              style: TextStyle(
                fontWeight: FontWeightManager.medium,
                fontSize: FontSize.s12,
                color: ColorManager.textColor.withOpacity(.5),
              ),
            ),
            const Icon(Icons.access_time, size: 18),
          ],
        ),
      ),
    );
  }
}
