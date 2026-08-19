import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class ChangePaymentStatusModal extends StatefulWidget {
  final String currentPaymentStatus;
  final String grandTotal; // shown as the Balance value
  final Function(String newStatus, double amount) onConfirm;

  const ChangePaymentStatusModal({
    super.key,
    required this.currentPaymentStatus,
    required this.grandTotal,
    required this.onConfirm,
  });

  @override
  State<ChangePaymentStatusModal> createState() =>
      _ChangePaymentStatusModalState();
}

class _ChangePaymentStatusModalState extends State<ChangePaymentStatusModal> {
  static const List<String> _paymentStatusOptions = [
    'pending',
    'paid',
    'failed',
  ];

  String? _selectedStatus;
  late final TextEditingController _amountController;

  double? get _balance =>
      double.tryParse(widget.grandTotal.replaceAll(',', '').trim());

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.grandTotal);

    // Pre-select current status
    if (_paymentStatusOptions.any(
        (s) => s.toLowerCase() == widget.currentPaymentStatus.toLowerCase())) {
      _selectedStatus = _paymentStatusOptions.firstWhere(
          (s) => s.toLowerCase() == widget.currentPaymentStatus.toLowerCase());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth < 600 ? screenWidth - 48 : 520,
        ),
        child: BuildBoxShadowContainer(
          padding: const EdgeInsets.all(24),
          circleRadius: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Update Payment Status",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status label
              RichText(
                text: TextSpan(
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.27,
                    ColorManager.textColor,
                  ),
                  children: const [
                    TextSpan(text: 'Status'),
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Status dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorManager.kPrimaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('change_payment_status.hint_status'.tr),
                    value: _selectedStatus,
                    items: _paymentStatusOptions.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(_capitalize(status)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStatus = newValue;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Amount label
              RichText(
                text: TextSpan(
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.27,
                    ColorManager.textColor,
                  ),
                  children: const [
                    TextSpan(text: 'Amount'),
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Amount text field
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,3}$'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: 'change_payment_status.hint_amount'.tr,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: ColorManager.kPrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Order Total: ${widget.grandTotal}",
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final amountRaw = _amountController.text.trim();
                      final amount =
                          double.tryParse(amountRaw.replaceAll(',', ''));

                      if (_selectedStatus == null) {
                        showScaffoldError(
                          context: context,
                          message: "Please select a payment status",
                        );
                        return;
                      }
                      if (amountRaw.isEmpty || amount == null || amount < 0) {
                        showScaffoldError(
                          context: context,
                          message: "Please enter a valid amount (minimum 0)",
                        );
                        return;
                      }
                      
                      Navigator.of(context).pop();
                      widget.onConfirm(_selectedStatus!, amount);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.kPrimaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Update Payment",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.27,
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.27,
                        Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
